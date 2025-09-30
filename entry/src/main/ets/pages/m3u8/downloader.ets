/**
 * 网络下载模块
 */
import http from '@ohos.net.http';

export class NetworkDownloader {
  /**
   * 下载文本内容
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
   * 下载二进制内容（带超时）
   */
  static async downloadBinaryWithTimeout(url: string, timeoutMs: number): Promise<Uint8Array> {
    const httpRequest = http.createHttp();
    try {
      const response = await Promise.race([
        httpRequest.request(url, {
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          connectTimeout: timeoutMs,
          readTimeout: timeoutMs
        }),
        NetworkDownloader.createTimeoutPromise(timeoutMs)
      ]);
      
      if (!response || typeof response === 'string') {
        throw new Error('下载超时');
      }

      return new Uint8Array(response.result as ArrayBuffer);
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * 下载二进制内容
   */
  static async downloadBinary(url: string): Promise<Uint8Array> {
    return NetworkDownloader.downloadBinaryWithTimeout(url, 30000);
  }

  /**
   * 创建超时Promise
   */
  private static createTimeoutPromise(timeoutMs: number): Promise<string> {
    return new Promise((_, reject) => {
      setTimeout(() => reject(new Error('请求超时')), timeoutMs);
    });
  }

  /**
   * 睡眠函数
   */
  static sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}