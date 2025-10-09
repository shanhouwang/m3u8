import { M3U8DownloaderFactory, DownloadCallbacks } from './m3u8/M3U8Downloader';

@Entry
@Component
struct Index {
  // 定义回调函数
  callbacks: DownloadCallbacks = {
    // 进度回调
    onProgress: (progress: number, downloaded: number, total: number) => {
      console.log(`下载进度: ${progress.toFixed(1)}%`);
      console.log(`已下载: ${downloaded} 字节, 总大小: ${total} 字节`);
    },

    // 完成回调
    onComplete: (outputPath: string) => {
      console.log(`下载完成，文件路径: ${outputPath}`);
    },

    // 错误回调
    onError: (error: Error) => {
      console.error(`下载失败: ${error.message}`);
    }
  };

  aboutToAppear(): void {
  }

  build() {
    Stack() {
      Button('点击下载').width(100).height(100)
        .onClick(() => {
          M3U8DownloaderFactory.start('https://m.igetget.com/ddmedia/public/v1/m3u8/3688047505834020/271/m.m3u8',
            '名字', this.callbacks)
        })
    }
    .height('100%')
    .width('100%')
  }
}