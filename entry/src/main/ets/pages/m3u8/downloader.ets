/**
 * 网络下载模块（后台下载）
 * 使用 request.agent.Mode.BACKGROUND 将下载任务交由系统后台执行。
 */
import { request } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';

export class NetworkDownloader {
  /**
   * 下载文本内容（后台下载到临时文件后读取）
   */
  static async downloadText(url: string): Promise<string> {
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(url);
      return response.result as string;
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * 下载二进制内容（带超时，后台下载）
   */
  static async downloadBinaryWithTimeout(url: string, timeoutMs: number): Promise<Uint8Array> {
    const buffer = await NetworkDownloader.downloadToBuffer(url, timeoutMs);
    return new Uint8Array(buffer);
  }

  /**
   * 下载二进制内容（后台下载）
   */
  static async downloadBinary(url: string): Promise<Uint8Array> {
    const buffer = await NetworkDownloader.downloadToBuffer(url, 30000);
    return new Uint8Array(buffer);
  }

  /**
   * 后台下载到本地临时文件并返回文件内容为 ArrayBuffer
   */
  private static async downloadToBuffer(url: string, timeoutMs: number): Promise<ArrayBuffer> {
    const context = NetworkDownloader.getContext();
    const saveDir = `${context.filesDir}/m3u8_ts_tmp`;
    NetworkDownloader.ensureDir(saveDir);

    const name = NetworkDownloader.filenameFromUrl(url);
    const savePath = `${saveDir}/${Date.now()}_${name}`;

    const config: request.agent.Config = {
      action: request.agent.Action.DOWNLOAD,
      url,
      mode: request.agent.Mode.BACKGROUND,
      retry: true,
      metered: false,
      roaming: true,
      redirect: true,
      network: request.agent.Network.ANY,
      saveas: savePath,
      overwrite: true,
      begins: 0,
      gauge: false
    };

    const task = await request.agent.create(context, config);

    return new Promise<ArrayBuffer>(async (resolve, reject) => {
      let timeoutHandle: number | undefined;

      const cleanup = async () => {
        try {
          task.off('progress');
          task.off('completed');
          task.off('failed');
          task.off('pause');
          task.off('resume');
        } catch (_) {
        }
      };

      const onCompleted = async () => {
        try {
          const fd = fileIo.openSync(savePath, fileIo.OpenMode.READ_ONLY);
          const stat = fileIo.statSync(fd.fd);
          const buf = new ArrayBuffer(stat.size);
          fileIo.readSync(fd.fd, buf);
          fileIo.closeSync(fd);
          resolve(buf);
        } catch (e) {
          reject(e);
        } finally {
          if (timeoutHandle) {
            clearTimeout(timeoutHandle);
          }
          // 成功读取后删除临时文件
          NetworkDownloader.safeDelete(savePath);
          await cleanup();
        }
      };

      const onFailed = async () => {
        try {
          reject(new Error('下载失败'));
        } finally {
          if (timeoutHandle) {
            clearTimeout(timeoutHandle);
          }
          // 失败时删除临时文件
          NetworkDownloader.safeDelete(savePath);
          await cleanup();
        }
      };

      task.on('completed', onCompleted);
      task.on('failed', onFailed);

      try {
        await task.start();
      } catch (e) {
        await cleanup();
        reject(e);
        return;
      }

      // 超时控制：到时尝试移除任务并拒绝
      if (timeoutMs && timeoutMs > 0) {
        timeoutHandle = setTimeout(async () => {
          try {
            await request.agent.remove(task.tid);
          } catch (_) {
          }
          // 超时时删除临时文件
          NetworkDownloader.safeDelete(savePath);
          await cleanup();
          reject(new Error('下载超时'));
        }, timeoutMs);
      }
    });
  }

  private static getContext(): common.UIAbilityContext {
    const uiContext: UIContext = AppStorage.get<UIContext>('uiContext') as UIContext;
    return uiContext.getHostContext() as common.UIAbilityContext;
  }

  private static ensureDir(dir: string) {
    try {
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir);
      }
    } catch (_) {
    }
  }

  private static filenameFromUrl(url: string): string {
    const idx = url.lastIndexOf('/');
    const name = idx >= 0 ? url.substring(idx + 1) : 'download.tmp';
    return name || 'download.tmp';
  }

  /**
   * 安全删除文件（忽略不存在或权限错误）
   */
  private static safeDelete(path: string) {
    try {
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path);
      }
    } catch (_) {}
  }

  /**
   * 睡眠函数
   */
  static sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}