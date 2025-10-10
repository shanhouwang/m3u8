# HarmonyOS M3U8 下载器 M3U8Downloader

一个功能强大的 HarmonyOS 应用，专门用于下载和处理 M3U8 视频流。支持加密视频解密、并发下载、断点续传、后台下载等高级功能。

## 功能特性

### 核心功能
- **M3U8 解析**: 自动解析 M3U8 播放列表文件
- **并发下载**: 支持多线程并发下载，提升下载速度
- **加密支持**: 支持 AES 加密的视频流解密
- **进度监控**: 实时显示下载进度和速度
- **错误重试**: 智能重试机制，提高下载成功率
- **文件合并**: 自动将下载的 TS 片段合并为完整视频
- **后台下载**: 通过任务管理与并发控制支持后台继续下载

### 技术特性
- **模块化设计**: 采用模块化架构，易于维护和扩展
- **性能优化**: 内存管理优化，支持大文件下载
- **并发控制**: 可配置的并发下载数量
- **超时处理**: 可配置的网络超时时间
- **临时文件管理**: 自动清理临时文件
- **工厂模式**: 提供统一的工厂类简化上下文获取与使用

## 📱 系统要求

- **操作系统**: HarmonyOS 5.0.0(12) 及以上（目标 SDK 5.0.5(17)，编译 SDK 5.1.1(19)）
- **设备类型**: 手机
- **网络权限**: 需要互联网访问权限

## 🛠️ 项目结构

```
HarmonyM3U8Downloader/
├── AppScope/                    # 应用级配置
│   ├── app.json5               # 应用配置文件
│   └── resources/              # 应用级资源
├── entry/                      # 主模块
│   ├── src/main/
│   │   ├── ets/
│   │   │   ├── entryability/         # 应用入口
│   │   │   ├── entrybackupability/   # 备份能力（如需）
│   │   │   └── pages/
│   │   │       ├── Index.ets         # 主页面
│   │   │       └── m3u8/             # M3U8 下载核心模块
│   │   │           ├── M3U8Downloader.ets         # 主下载器（并提供导出工厂）
│   │   │           ├── M3U8DownloaderFactory.ets  # 工厂类（统一上下文与启动）
│   │   │           ├── crypto.ets                  # 加密解密模块
│   │   │           ├── downloader.ets              # 网络下载模块
│   │   │           ├── fileManager.ets             # 文件管理模块
│   │   │           ├── concurrency.ets             # 并发控制模块
│   │   │           ├── utils.ets                   # 工具函数
│   │   │           └── types.ets                   # 类型定义
│   │   └── resources/          # 模块资源
│   └── build-profile.json5     # 模块构建配置
├── build-profile.json5         # 项目构建配置（compile/target/compatible SDK）
└── oh-package.json5            # 依赖管理
```

## 依赖库

- `@ohos/crypto-js@^2.0.5`: 用于 AES 加密解密功能

## 🔧 安装与配置

### 1. 克隆项目
```bash
git clone <repository-url>
cd HarmonyM3U8Downloader
```

### 2. 安装依赖
```bash
ohpm install
```

### 3. 配置权限
项目已预配置以下权限：
- `ohos.permission.INTERNET`: 网络访问权限
- `ohos.permission.GET_NETWORK_INFO`: 网络状态获取权限

### 4. 构建项目
```bash
hvigor assembleHap
```

### 5. 安装到设备
```bash
hdc install entry-default-signed.hap
```

## 💻 使用方法

### 基本使用（推荐工厂模式）

```typescript
import { M3U8DownloaderFactory, DownloadCallbacks } from './m3u8/M3U8Downloader';

// 设置回调函数
const callbacks: DownloadCallbacks = {
  onProgress: (progress: number, downloaded: number, total: number) => {
    console.log(`下载进度: ${progress.toFixed(1)}%`);
  },
  onComplete: (outputPath: string) => {
    console.log(`下载完成: ${outputPath}`);
  },
  onError: (error: Error) => {
    console.error(`下载失败: ${error.message}`);
  }
};

// 一行代码启动下载（自动获取上下文）
await M3U8DownloaderFactory.start('https://example.com/video.m3u8', '视频文件名', callbacks);
```

### 自定义创建与高级配置

```typescript
import { M3U8DownloaderFactory } from './m3u8/M3U8Downloader';

const downloader = M3U8DownloaderFactory.create(undefined, {
  maxConcurrentDownloads: 8,  // 最大并发下载数 (1-20)
  retryCount: 5,              // 重试次数 (1-5)
  timeoutMs: 45000,           // 超时时间 (5000-60000ms)
  skipIfIncomplete: true      // 检测到未完成进度时跳过本次下载
});

await downloader.startDownload('https://example.com/video.m3u8', '视频文件名');
```

### 取消下载

```typescript
// 取消正在进行的下载
downloader.cancelDownload();
```

## 🏗️ 核心模块说明

### M3U8Downloader
主下载器类，负责整个下载流程的协调和管理。

**主要方法:**
- `startDownload(url, filename)`: 开始下载
- `cancelDownload()`: 取消下载
- `setCallback(callbacks)`: 设置回调函数
- `configurePerformance(options)`: 配置性能参数

### M3U8DownloaderFactory
工厂类，统一获取 UIAbilityContext，提供快速启动与实例创建。

**主要方法:**
- `create(callbacks?, performance?)`: 创建并配置下载器实例
- `start(m3u8Url, outputFileName, callbacks?, performance?)`: 直接启动下载（推荐）

### CryptoManager
加密解密管理器，处理 AES 加密的视频流。

**功能:**
- AES-128-CBC 解密
- 支持自定义 IV 向量
- 高效的流式解密

### NetworkDownloader
网络下载模块，提供 HTTP 下载功能。

**功能:**
- 支持文本和二进制下载
- 超时控制
- 错误处理

### FileManager
文件管理模块，处理本地文件操作。

**功能:**
- 文件读写
- 目录创建
- 文件合并
- 临时文件清理

### ConcurrencyManager
并发控制模块，管理多线程下载。

**功能:**
- 并发数量控制
- 任务队列管理
- 取消机制
- 后台下载任务管理

## 📊 性能特性

- **并发下载**: 默认 6 个并发连接，可配置 1-20 个
- **智能重试**: 默认 3 次重试，可配置 1-5 次
- **超时控制**: 默认 30 秒超时，可配置 5-60 秒
- **内存优化**: 流式处理，支持大文件下载
- **进度追踪**: 实时进度更新和速度计算
- **跳过未完成策略**: 可启用 `skipIfIncomplete` 跳过当前未完成的会话
- **断点续传**: 自动检测并跳过已完成片段，继续未完成下载

## 🔒 安全特性

- **权限最小化**: 仅申请必要的网络权限
- **数据加密**: 支持 AES 加密视频流解密
- **临时文件清理**: 自动清理下载过程中的临时文件
- **错误处理**: 完善的错误处理和日志记录

## 🐛 故障排除

### 常见问题

1. **SDK/兼容性错误: "UseNormalizedOHMUrl can be true only when Compatible SDK Version is 5.0.0 (12) or later"**
   - 解决方案: 确保 `compatibleSdkVersion >= 5.0.0(12)`；或者在 `build-profile.json5` 中将 `useNormalizedOHMUrl` 设为 `false`。

2. **安装失败: 兼容或发布类型不匹配**
   - 解决方案: 项目已配置为 `targetSdkVersion=5.0.5(17)`、`compatibleSdkVersion=5.0.0(12)`。请使用 HarmonyOS 5.x 设备或调整设备兼容设置。

3. **网络权限被拒绝**
   - 确保在设备设置中授予应用网络权限。

4. **下载速度慢**
   - 尝试增加并发下载数: `configurePerformance({ maxConcurrentDownloads: 10 })`。

5. **下载失败**
   - 检查网络连接。
   - 验证 M3U8 URL 是否有效。
   - 增加重试次数和超时时间。

6. **依赖问题：无法找到 '@ohos/crypto-js'**
   - 执行 `ohpm install` 并确保 DevEco Studio/Harmony SDK 正确配置；如仍报错，请清理构建缓存后重试。

### 调试模式

项目包含详细的日志输出，可通过 HiLog 查看：

```bash
hdc hilog | grep M3U8Downloader
```

## 📝 更新日志

### v1.1.0 (2025-10-10)
- 新增 M3U8DownloaderFactory 工厂类，简化上下文获取与使用
- 支持后台下载与 `skipIfIncomplete` 跳过策略
- 更新系统要求到 HarmonyOS 5.x（compatible 12+，target 17，compile 19）
- 优化示例代码，避免使用已弃用的 `getContext(this)`

### v1.0.0 (2025-09-30)
- 初始版本发布
- 支持 M3U8 下载和 AES 解密
- 实现并发下载和进度监控
- 添加完整的错误处理机制

## 贡献指南

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 致谢

- HarmonyOS 开发团队
- @ohos/crypto-js 库的贡献者
- 所有测试和反馈的用户

**注意**: 请确保您有权下载相关视频内容，并遵守相关法律法规和版权要求。