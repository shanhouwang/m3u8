# HarmonyOS M3U8 下载器 M3U8Downloader

一个功能强大的HarmonyOS应用，专门用于下载和处理M3U8视频流。支持加密视频解密、并发下载、断点续传等高级功能。

## 功能特性

### 核心功能
- **M3U8解析**: 自动解析M3U8播放列表文件
- **并发下载**: 支持多线程并发下载，提升下载速度
- **加密支持**: 支持AES加密的视频流解密
- **进度监控**: 实时显示下载进度和速度
- **错误重试**: 智能重试机制，提高下载成功率
- **文件合并**: 自动将下载的TS片段合并为完整视频

### 技术特性
- **模块化设计**: 采用模块化架构，易于维护和扩展
- **性能优化**: 内存管理优化，支持大文件下载
- **并发控制**: 可配置的并发下载数量
- **超时处理**: 可配置的网络超时时间
- **临时文件管理**: 自动清理临时文件

## 📱 系统要求

- **操作系统**: HarmonyOS 4.1.0 (API Level 11) 及以上
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
│   │   │   ├── entryability/   # 应用入口
│   │   │   └── pages/
│   │   │       ├── Index.ets   # 主页面
│   │   │       └── m3u8/       # M3U8下载核心模块
│   │   │           ├── M3U8Downloader.ets  # 主下载器
│   │   │           ├── crypto.ets          # 加密解密模块
│   │   │           ├── downloader.ets      # 网络下载模块
│   │   │           ├── fileManager.ets     # 文件管理模块
│   │   │           ├── concurrency.ets     # 并发控制模块
│   │   │           ├── utils.ets           # 工具函数
│   │   │           └── types.ets           # 类型定义
│   │   └── resources/          # 模块资源
│   └── build-profile.json5     # 模块构建配置
├── build-profile.json5         # 项目构建配置
└── oh-package.json5            # 依赖管理
```

## 依赖库

- `@ohos/crypto-js`: 用于AES加密解密功能

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

### 基本使用

```typescript
import { M3U8Downloader, DownloadCallbacks } from './m3u8/M3U8Downloader';

// 创建下载器实例
const downloader = new M3U8Downloader(getContext(this));

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

downloader.setCallback(callbacks);

// 开始下载
downloader.startDownload('https://example.com/video.m3u8', '视频文件名');
```

### 高级配置

```typescript
// 配置性能参数
downloader.configurePerformance({
  maxConcurrentDownloads: 8,  // 最大并发下载数 (1-20)
  retryCount: 5,              // 重试次数 (1-5)
  timeoutMs: 45000           // 超时时间 (5000-60000ms)
});
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

### CryptoManager
加密解密管理器，处理AES加密的视频流。

**功能:**
- AES-128-CBC解密
- 支持自定义IV向量
- 高效的流式解密

### NetworkDownloader
网络下载模块，提供HTTP下载功能。

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

## 📊 性能特性

- **并发下载**: 默认6个并发连接，可配置1-20个
- **智能重试**: 默认3次重试，可配置1-5次
- **超时控制**: 默认30秒超时，可配置5-60秒
- **内存优化**: 流式处理，支持大文件下载
- **进度追踪**: 实时进度更新和速度计算

## 🔒 安全特性

- **权限最小化**: 仅申请必要的网络权限
- **数据加密**: 支持AES加密视频流解密
- **临时文件清理**: 自动清理下载过程中的临时文件
- **错误处理**: 完善的错误处理和日志记录

## 🐛 故障排除

### 常见问题

1. **安装失败: "compatibleSdkVersion and releaseType of the app do not match"**
   - 解决方案: 项目已配置为API 4.1.0(11)，兼容大多数设备

2. **网络权限被拒绝**
   - 确保在设备设置中授予应用网络权限

3. **下载速度慢**
   - 尝试增加并发下载数: `configurePerformance({maxConcurrentDownloads: 10})`

4. **下载失败**
   - 检查网络连接
   - 验证M3U8 URL是否有效
   - 增加重试次数和超时时间

### 调试模式

项目包含详细的日志输出，可通过HiLog查看：

```bash
hdc hilog | grep M3U8Downloader
```

## 📝 更新日志

### v1.0.0 (2025-09-30)
- 初始版本发布
- 支持M3U8下载和AES解密
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
