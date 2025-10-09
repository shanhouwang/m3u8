/**
 * M3U8Downloader 工厂
 * 统一获取 UIAbilityContext，简化创建与使用
 */
import common from '@ohos.app.ability.common';
import { M3U8Downloader } from './M3U8Downloader';
import { PerformanceConfig, DownloadCallbacks } from './types';

export class M3U8DownloaderFactory {
  /**
   * 获取 UIAbility 上下文
   * 依赖 AppStorage 中保存的 'uiContext'
   */
  private static getContext(): common.Context {
    const uiContext: UIContext = AppStorage.get<UIContext>('uiContext') as UIContext;
    // UIAbilityContext 兼容传入 common.Context 的需求
    return uiContext.getHostContext() as common.Context;
  }

  /**
   * 创建下载器实例（可选设置回调与性能参数）
   */
  static create(callbacks?: DownloadCallbacks, performance?: PerformanceConfig): M3U8Downloader {
    const downloader = new M3U8Downloader(M3U8DownloaderFactory.getContext());
    if (callbacks) {
      downloader.setCallbacks(callbacks);
    }
    if (performance) {
      downloader.configurePerformance(performance);
    }
    return downloader;
  }

  /**
   * 一键创建并启动下载
   */
  static async start(m3u8Url: string, outputFileName: string, callbacks?: DownloadCallbacks, performance?: PerformanceConfig): Promise<void> {
    const downloader = M3U8DownloaderFactory.create(callbacks, performance);
    await downloader.startDownload(m3u8Url, outputFileName);
  }
}

export default M3U8DownloaderFactory;