/**
 * 工具函数模块
 */

export class M3U8Utils {
  private static readonly TAG = 'M3U8Utils';

  /**
   * 格式化时间长度（毫秒转换为可读格式）
   */
  static formatDuration(milliseconds: number): string {
    const seconds = Math.floor(milliseconds / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);

    if (hours > 0) {
      return `${hours}小时${minutes % 60}分钟${seconds % 60}秒`;
    } else if (minutes > 0) {
      return `${minutes}分钟${seconds % 60}秒`;
    } else {
      return `${seconds}秒`;
    }
  }

  /**
   * 计算平均下载速度
   */
  static calculateAverageSpeed(totalBytes: number, totalTimeMs: number): string {
    if (totalTimeMs === 0) {
      return '0 B/s';
    }

    const bytesPerSecond = (totalBytes * 1000) / totalTimeMs;

    if (bytesPerSecond >= 1024 * 1024) {
      return `${(bytesPerSecond / (1024 * 1024)).toFixed(2)} MB/s`;
    } else if (bytesPerSecond >= 1024) {
      return `${(bytesPerSecond / 1024).toFixed(2)} KB/s`;
    } else {
      return `${bytesPerSecond.toFixed(2)} B/s`;
    }
  }

  /**
   * 获取当前线程信息
   */
  static getThreadInfo(): string {
    return ''
  }
}