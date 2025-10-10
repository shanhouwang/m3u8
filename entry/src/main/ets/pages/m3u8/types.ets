/**
 * M3U8下载器相关类型定义
 */

export interface TSInfo {
  duration: number,
  url: string
}

export interface KeyInfo {
  uri: string,
  iv: string
}

/**
 * 性能配置接口
 */
export interface PerformanceConfig {
  /** 最大并发下载数*/
  maxConcurrentDownloads?: number;

  /** 重试次数 (1-5，默认3) */
  retryCount?: number;

  /** 超时时间毫秒 (5000-60000，默认30000) */
  timeoutMs?: number;

  /** 检测到未完成进度时本次是否直接跳过下载（默认false） */
  skipIfIncomplete?: boolean;
}

/**
 * 下载回调接口
 */
export interface DownloadCallbacks {
  // 下载进度回调
  onProgress?: (outputFileName: string, progress: number, downloaded: number, total: number) => void;
  // 完成回调
  onComplete?: (outputFileName: string, outputPath: string) => void;
  // 错误回调
  onError?: (outputFileName: string, error: Error) => void;
}

/**
 * 进度记录（用于持久化）
 */
export interface ProgressRecord {
  total: number;
  completed: number[];
}

/**
 * 片段文件状态（索引与大小）
 */
export interface SegmentStat {
  index: number;
  size: number;
}