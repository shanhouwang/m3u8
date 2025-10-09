/**
 * M3U8下载器主类
 */
import common from '@ohos.app.ability.common';
import { TSInfo, KeyInfo, PerformanceConfig, DownloadCallbacks } from './types';
import { CryptoManager } from './crypto';
import { NetworkDownloader } from './downloader';
import { FileManager } from './fileManager';
import { ConcurrencyManager } from './concurrency';
import { M3U8Utils } from './utils';

export class M3U8Downloader {
  private static readonly TAG = 'M3U8Downloader';
  
  private context: common.Context;
  private baseUrl: string = '';
  private tsList: Array<TSInfo> = [];
  private keyInfo: KeyInfo | null = null;
  private totalSize: number = 0;
  private downloadedSize: number = 0;
  private isCanceled: boolean = false;
  
  // 性能优化配置
  private maxConcurrentDownloads: number = 8; // 最大并发下载数
  private retryCount: number = 3; // 重试次数
  private timeoutMs: number = 30000; // 超时时间30秒

  // 回调函数
  private callbacks: DownloadCallbacks = {};

  constructor(context: common.Context) {
    this.context = context;
    console.log(M3U8Downloader.TAG, `[${M3U8Utils.getThreadInfo()}] 初始化M3U8下载器`);
  }

  /**
   * 设置回调函数
   */
  setCallbacks(callbacks: DownloadCallbacks): void {
    this.callbacks = callbacks;
  }

  /**
   * 配置下载性能参数
   */
  configurePerformance(options: PerformanceConfig): void {
    if (options.maxConcurrentDownloads !== undefined) {
      this.maxConcurrentDownloads = Math.max(1, Math.min(20, options.maxConcurrentDownloads));
      console.log(M3U8Downloader.TAG,
        `[${M3U8Utils.getThreadInfo()}] 设置最大并发下载数: ${this.maxConcurrentDownloads}`);
    }

    if (options.retryCount !== undefined) {
      this.retryCount = Math.max(1, Math.min(5, options.retryCount));
      console.log(M3U8Downloader.TAG, `[${M3U8Utils.getThreadInfo()}] 设置重试次数: ${this.retryCount}`);
    }

    if (options.timeoutMs !== undefined) {
      this.timeoutMs = Math.max(5000, Math.min(60000, options.timeoutMs));
      console.log(M3U8Downloader.TAG, `[${M3U8Utils.getThreadInfo()}] 设置超时时间: ${this.timeoutMs}毫秒`);
    }
  }

  /**
   * 解析M3U8内容
   */
  private parseM3U8(content: string): void {
    console.log(M3U8Downloader.TAG, `[${M3U8Utils.getThreadInfo()}] 解析M3U8内容: ${content}`);
    const lines = content.split('\n');
    let currentDuration = 0;

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (line.startsWith('#EXT-X-KEY:')) {
        this.parseKeyInfo(line);
      } else if (line.startsWith('#EXTINF:')) {
        currentDuration = parseFloat(line.substring(8).replace(',', ''));
      } else if (line.startsWith('http')) {
        this.tsList.push({
          duration: currentDuration,
          url: line
        });
      } else if (line.startsWith('#EXT-X-MAP:') || line.startsWith('#EXT-X-BYTERANGE:')) {
        console.warn(M3U8Downloader.TAG, `[${M3U8Utils.getThreadInfo()}] 不支持的M3U8标签: ${line}`);
      }
    }
  }

  /**
   * 解析密钥信息
   */
  private parseKeyInfo(line: string): void {
    const regex = /([A-Z]+)=("[^"]*"|[^,]*)/g;
    let match: RegExpExecArray | null;
    let uri = '';
    let iv = '';

    while ((match = regex.exec(line.substring(11))) !== null) {
      const key = match[1];
      let value = match[2];

      if (value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }

      if (key === 'URI') {
        uri = value;
      } else if (key === 'IV') {
        iv = value;
      }
    }

    if (uri) {
      this.keyInfo = { uri, iv };
    }
    console.log(M3U8Downloader.TAG, `[${M3U8Utils.getThreadInfo()}] 解析密钥信息: ${JSON.stringify(this.keyInfo)}`);
  }

  /**
   * 开始下载
   */
  async startDownload(m3u8Url: string, outputFileName: string): Promise<void> {
    this.tsList = []
    const startTime = Date.now();
    const startTimeStr = new Date(startTime).toLocaleString('zh-CN');
    console.log(M3U8Downloader.TAG, `[${M3U8Utils.getThreadInfo()}] 开始下载 - 开始时间: ${startTimeStr}`);

    try {
      this.isCanceled = false;
      this.downloadedSize = 0;

      // 获取M3U8文件内容
      const m3u8Content = await NetworkDownloader.downloadText(m3u8Url);
      this.baseUrl = m3u8Url.substring(0, m3u8Url.lastIndexOf('/') + 1);

      // 解析M3U8
      this.parseM3U8(m3u8Content);

      if (this.tsList.length === 0) {
        throw new Error('M3U8文件中未找到TS片段');
      }

      // 下载密钥（如果有）
      let keyData: Uint8Array | null = null;
      if (this.keyInfo) {
        keyData = await this.downloadKey(this.keyInfo.uri);
      }

      // 创建临时目录
      const tempDir = this.context.cacheDir + '/ts_segments/' + outputFileName + '/';
      await FileManager.ensureDir(tempDir);

      // 并发下载所有TS分片
      console.log(M3U8Downloader.TAG,
        `[${M3U8Utils.getThreadInfo()}] 开始并发下载 ${this.tsList.length} 个TS片段，并发数: ${this.maxConcurrentDownloads}`);
      const downloadedFiles: string[] = await this.downloadAllSegmentsConcurrently(tempDir, keyData);

      if (this.isCanceled) {
        await FileManager.cleanupTempFiles(downloadedFiles);
        return;
      }

      // 合并文件
      const outputPath = this.context.cacheDir + `/${outputFileName}.ts`;
      console.log(M3U8Downloader.TAG, `[${M3U8Utils.getThreadInfo()}] 开始合并TS片段为视频文件: ${outputPath}`);
      await FileManager.mergeFiles(downloadedFiles, outputPath);

      // 清理临时文件
      await FileManager.cleanupTempFiles(downloadedFiles);

      // 记录结束时间和计算总耗时
      const endTime = Date.now();
      const endTimeStr = new Date(endTime).toLocaleString('zh-CN');
      const totalTime = endTime - startTime;
      const totalTimeStr = M3U8Utils.formatDuration(totalTime);

      console.log(M3U8Downloader.TAG, `[${M3U8Utils.getThreadInfo()}] M3U8视频下载完成: ${outputPath}`);
      console.log(M3U8Downloader.TAG, `[${M3U8Utils.getThreadInfo()}] 下载完成 - 结束时间: ${endTimeStr}`);
      console.log(M3U8Downloader.TAG, `[${M3U8Utils.getThreadInfo()}] 总耗时: ${totalTimeStr} (${totalTime}ms)`);
      console.log(M3U8Downloader.TAG,
        `[${M3U8Utils.getThreadInfo()}] 平均速度: ${M3U8Utils.calculateAverageSpeed(this.downloadedSize, totalTime)}`);
      
      this.callbacks.onComplete?.(outputPath);

    } catch (error) {
      const errorTime = Date.now();
      const errorTimeStr = new Date(errorTime).toLocaleString('zh-CN');
      const failedTime = errorTime - startTime;
      const failedTimeStr = M3U8Utils.formatDuration(failedTime);

      console.error(M3U8Downloader.TAG, `[${M3U8Utils.getThreadInfo()}] 下载失败 - 失败时间: ${errorTimeStr}`);
      console.error(M3U8Downloader.TAG, `[${M3U8Utils.getThreadInfo()}] 失败前耗时: ${failedTimeStr} (${failedTime}ms)`);
      this.callbacks.onError?.(error);
    }
  }

  /**
   * 取消下载
   */
  cancelDownload(): void {
    this.isCanceled = true;
  }

  /**
   * 并发下载所有片段
   */
  private async downloadAllSegmentsConcurrently(tempDir: string, keyData: Uint8Array | null): Promise<string[]> {
    const downloadedFiles: string[] = new Array(this.tsList.length);
    let completedCount = 0;

    console.log(M3U8Downloader.TAG,
      `开始并发下载 ${this.tsList.length} 个片段，最大并发数: ${this.maxConcurrentDownloads}`);

    // 创建所有下载任务
    const downloadTasks = this.tsList.map((tsUrl, index) => {
      return async (): Promise<void> => {
        try {
          await this.downloadSingleSegmentWithRetry(index, tempDir, keyData, downloadedFiles);
          completedCount++;
          this.updateProgressWithCount(completedCount);
          console.log(M3U8Downloader.TAG, `片段 ${index + 1}/${this.tsList.length} 下载完成`);
        } catch (error) {
          console.error(M3U8Downloader.TAG, `片段 ${index + 1} 下载失败:`, error);
          throw new Error(error);
        }
      };
    });

    // 使用并发控制器
    await ConcurrencyManager.executeTasksWithConcurrencyLimit(
      downloadTasks, 
      this.maxConcurrentDownloads,
      () => this.isCanceled
    );

    console.log(M3U8Downloader.TAG, `所有片段下载完成，共 ${this.tsList.length} 个`);
    return downloadedFiles;
  }

  /**
   * 单个片段下载（带重试机制）
   */
  private async downloadSingleSegmentWithRetry(
    index: number,
    tempDir: string,
    keyData: Uint8Array | null,
    downloadedFiles: string[]
  ): Promise<void> {
    const tsUrl = this.tsList[index].url;
    const tempFile = `${tempDir}segment_${index}.ts`;

    for (let attempt = 1; attempt <= this.retryCount; attempt++) {
      if (this.isCanceled) {
        return;
      }

      try {
        console.log(M3U8Downloader.TAG, 
          `下载片段 ${index + 1}/${this.tsList.length} (尝试 ${attempt}/${this.retryCount}): ${tsUrl}`);

        const tsData = await NetworkDownloader.downloadBinaryWithTimeout(tsUrl, this.timeoutMs);

        // 解密（如果有密钥）
        const finalData = keyData ? await CryptoManager.decryptTs(tsData, keyData, this.keyInfo!.iv) : tsData;

        await FileManager.writeFile(tempFile, finalData);
        downloadedFiles[index] = tempFile;

        this.downloadedSize += finalData.length;

        console.log(M3U8Downloader.TAG, 
          `片段 ${index + 1} 下载成功: ${finalData.length} 字节`);
        return; // 成功，退出重试循环

      } catch (error) {
        console.error(M3U8Downloader.TAG,
          `片段 ${index + 1} 下载失败 (尝试 ${attempt}/${this.retryCount}):`, error);

        if (attempt === this.retryCount) {
          const errorMsg = `片段 ${index + 1} 下载失败，已重试 ${this.retryCount} 次: ${error.message}`;
          throw new Error(errorMsg);
        }

        // 等待一段时间后重试
        await NetworkDownloader.sleep(1000 * attempt);
      }
    }
  }

  /**
   * 下载密钥
   */
  private async downloadKey(keyUrl: string): Promise<Uint8Array> {
    console.log(M3U8Downloader.TAG, `下载密钥: ${keyUrl}`);
    const fullUrl = keyUrl.startsWith('http') ? keyUrl : this.baseUrl + keyUrl;
    return await NetworkDownloader.downloadBinary(fullUrl);
  }

  /**
   * 基于完成数量更新进度
   */
  private updateProgressWithCount(completedCount: number): void {
    const progress = this.tsList.length > 0 ? (completedCount / this.tsList.length) * 100 : 0;

    // 估算总大小
    if (this.totalSize === 0 && this.downloadedSize > 0 && completedCount > 0) {
      const avgSize = this.downloadedSize / completedCount;
      this.totalSize = avgSize * this.tsList.length;
    }
    console.log(M3U8Downloader.TAG,
      `下载进度: ${progress.toFixed(1)}% (${completedCount}/${this.tsList.length})`);
    this.callbacks.onProgress?.(progress, this.downloadedSize, this.totalSize);
  }
}

// 导出所有相关类型和类
export { TSInfo, KeyInfo, PerformanceConfig, DownloadCallbacks } from './types';
export { CryptoManager } from './crypto';
export { NetworkDownloader } from './downloader';
export { FileManager } from './fileManager';
export { ConcurrencyManager } from './concurrency';
export { M3U8Utils } from './utils';
export { M3U8DownloaderFactory } from './M3U8DownloaderFactory';