# HarmonyOS M3U8Downloader · M3U8 下载器

面向 HarmonyOS 的高性能 M3U8 视频下载与处理工具，支持加密解密、并发下载、断点续传、后台任务与进度追踪。

## 亮点特性

- 解析与下载
  - 自动解析 M3U8 播放列表
  - 多线程并发下载（可配置 1–20）
  - 断点续传与已完成片段跳过
- 加密与合并
  - AES-128-CBC 解密（支持自定义 IV）
  - 自动合并 TS 片段为完整视频
- 稳定与易用
  - 实时进度与速度显示
  - 智能重试与超时控制
  - 后台下载与任务取消
  - 工厂模式一行启动

## 系统要求

- HarmonyOS 5.0.0(12) 及以上
  - targetSdkVersion: 5.0.5(17)
  - compileSdkVersion: 5.1.1(19)
- 设备类型：手机
- 权限：`ohos.permission.INTERNET`, `ohos.permission.GET_NETWORK_INFO`

## 项目结构

```
HarmonyM3U8Downloader/
├── AppScope/
│   ├── app.json5
│   └── resources/
├── entry/
│   ├── src/main/ets/
│   │   ├── entryability/
│   │   ├── pages/
│   │   │   └── m3u8/
│   │   │       ├── M3U8Downloader.ets
│   │   │       ├── M3U8DownloaderFactory.ets
│   │   │       ├── crypto.ets
│   │   │       ├── downloader.ets
│   │   │       ├── fileManager.ets
│   │   │       ├── concurrency.ets
│   │   │       ├── utils.ets
│   │   │       └── types.ets
│   └── resources/
├── build-profile.json5
└── oh-package.json5
```

## 依赖

- `@ohos/crypto-js@^2.0.5`：AES 加密解密

## 快速开始

1) 克隆与进入项目
```bash
git clone <repository-url>
cd HarmonyM3U8Downloader
```

2) 安装依赖
```bash
ohpm install
```

3) 构建 HAP
```bash
hvigor assembleHap
```

4) 安装到设备
```bash
hdc install entry-default-signed.hap
```

## 使用示例

- 工厂模式（推荐）
```typescript
import { M3U8DownloaderFactory, DownloadCallbacks } from './m3u8/M3U8Downloader';

const callbacks: DownloadCallbacks = {
  onProgress: (outputFileName: string, progress: number, downloaded: number, total: number) => {
    console.log(`[${outputFileName}] 下载进度: ${progress.toFixed(1)}% (${downloaded}/${total} bytes)`);
  },
  onComplete: (outputFileName: string, outputPath: string) => {
    console.log(`[${outputFileName}] 下载完成: ${outputPath}`);
  },
  onError: (outputFileName: string, error: Error) => {
    console.error(`[${outputFileName}] 下载失败: ${error.message}`);
  }
};

await M3U8DownloaderFactory.start('https://example.com/video.m3u8', '视频文件名', callbacks);
```

- 高级配置与自定义创建
```typescript
import { M3U8DownloaderFactory } from './m3u8/M3U8Downloader';

const downloader = M3U8DownloaderFactory.create(undefined, {
  maxConcurrentDownloads: 8,  // 1-20
  retryCount: 5,              // 1-5
  timeoutMs: 45000,           // 5000-60000
  skipIfIncomplete: true
});

await downloader.startDownload('https://example.com/video.m3u8', '视频文件名');
```

- 取消下载
```typescript
downloader.cancelDownload();
```

## 配置选项

- 并发：`maxConcurrentDownloads`（默认 6，范围 1–20）
- 重试：`retryCount`（默认 3，范围 1–5）
- 超时：`timeoutMs`（默认 30000ms，范围 5000–60000ms）
- 跳过策略：`skipIfIncomplete`（默认 false；开启后跳过当前未完成会话）
- 回调：
  - `onProgress(outputFileName, progress, downloaded, total)`
  - `onComplete(outputFileName, outputPath)`
  - `onError(outputFileName, error)`

## 模块简介

- M3U8Downloader：协调完整下载流程（开始、取消、回调、性能配置）
- M3U8DownloaderFactory：统一获取 UIAbilityContext，一键启动与实例化
- CryptoManager：AES 解密（支持自定义 IV，流式处理）
- NetworkDownloader：HTTP 下载（文本/二进制、超时与错误处理）
- FileManager：文件读写、目录创建、合并与临时文件清理
- ConcurrencyManager：并发控制、队列与取消、后台任务

## 性能与稳定性

- 并发下载与流式合并，兼顾速度与内存占用
- 实时进度与速度计算
- 智能重试与超时控制
- 自动检测已完成片段，实现断点续传

## 故障排除

- 兼容性错误：
  - 报错 “UseNormalizedOHMUrl can be true only when Compatible SDK Version is 5.0.0 (12) or later”
  - 处理：确保 `compatibleSdkVersion >= 5.0.0(12)`，或在 `build-profile.json5` 将 `useNormalizedOHMUrl=false`
- 安装失败（SDK/发布类型不匹配）：
  - 使用 HarmonyOS 5.x 设备或调整兼容配置（target=17，compatible=12）
- 依赖无法解析：
  - 执行 `ohpm install`，检查 DevEco/Harmony SDK；必要时清理构建缓存重试
- 速度慢或失败：
  - 检查网络与 URL；提升并发、重试与超时配置

日志查看：
```bash
hdc hilog | grep M3U8Downloader
```

## 更新日志

### v1.1.0 (2025-10-10)
- 新增工厂类，简化上下文获取与一键启动
- 支持后台下载与 `skipIfIncomplete` 跳过策略
- 更新系统要求至 HarmonyOS 5.x（compatible 12+，target 17，compile 19）
- 优化示例，避免使用已弃用的 `getContext(this)`

### v1.0.0 (2025-09-30)
- 首次发布：M3U8 下载与 AES 解密
- 并发下载与进度监控
- 完整错误处理

## 贡献指南

1. Fork 仓库
2. 创建分支：`git checkout -b feature/AmazingFeature`
3. 提交变更：`git commit -m 'Add some AmazingFeature'`
4. 推送分支：`git push origin feature/AmazingFeature`
5. 创建 Pull Request

## 许可证

MIT License（详见 [LICENSE](LICENSE)）

## 法律与版权

请确保拥有下载与处理相关视频内容的合法授权，遵守所在地区的法律法规与版权要求。