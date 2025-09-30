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
}

/**
 * 下载回调接口
 */
export interface DownloadCallbacks {
  // 下载进度回调
  onProgress?: (progress: number, downloaded: number, total: number) => void;
  // 完成回调
  onComplete?: (outputPath: string) => void;
  // 错误回调
  onError?: (error: Error) => void;
}