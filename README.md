# 🎵 Flutter AI Speech

一个基于 Flutter Web 的音频波形显示与语音练习应用，支持 OPFS (Origin Private File System) 本地存储。

## ✨ 功能特性

### 🎶 音频波形显示
- **交互式波形渲染**: 支持三种显示样式（线条、条形、填充）
- **音频播放控制**: 点击波形跳转播放位置
- **WAV 文件支持**: 自动解析音频数据并生成波形
- **实时标注显示**: 在波形上叠加显示词汇和音素标注

### 🗣️ 语音练习管理
- **练习组管理**: 创建和管理语音练习项目
- **原生/用户录音**: 区分原生示例和用户练习录音
- **音频标注**: 支持词汇级别的时间标注和音素标记
- **数据持久化**: 使用 OPFS 在浏览器本地存储数据

### 💾 OPFS 存储服务
- **原生浏览器存储**: 利用现代浏览器的 Origin Private File System
- **文件操作**: 支持文本和二进制文件的保存、读取、删除
- **存储管理**: 查看存储使用情况、列出文件、批量清理
- **离线可用**: 无需网络连接即可访问存储的数据

## 🛠️ 技术栈

- **框架**: Flutter 3.x
- **平台**: Web (Chrome 86+, Edge 86+)
- **存储**: OPFS (Origin Private File System)
- **音频**: WAV 文件处理
- **渲染**: CustomPainter 自定义绘制

## 🚀 快速开始

### 环境要求
- Flutter SDK 3.0+
- 支持 OPFS 的现代浏览器 (Chrome 86+, Edge 86+)

### 安装和运行
```bash
# 克隆项目
git clone https://github.com/YOUR_USERNAME/flutter-ai-speech.git
cd flutter-ai-speech

# 安装依赖
flutter pub get

# 运行 Web 应用
flutter run -d web-server --web-port 8080
```

然后在浏览器中访问 `http://localhost:8080`

## 📁 项目结构

```
lib/
├── main.dart                    # 应用入口和主界面
├── audio_waveform_viewer.dart   # 音频波形查看器组件
├── waveform_widget.dart         # 波形绘制组件
├── audio_data_processor.dart    # 音频数据处理
├── annotation_data.dart         # 标注数据模型（原版）
├── practice_data_models.dart    # 语音练习数据模型
├── opfs_storage_service.dart    # OPFS 存储服务
├── opfs_test_widget.dart        # OPFS 功能测试界面
└── opfs_storage_example.dart    # OPFS 使用示例
```

## 🎯 核心组件

### AudioWaveformViewer
主要的音频波形显示组件，支持：
- 文件选择和音频加载
- 波形样式切换
- 播放控制和进度显示
- 标注数据叠加显示

### OPFSStorageService
浏览器存储抽象层，提供：
- 文件 CRUD 操作
- JSON 数据序列化
- 存储使用情况统计
- 跨会话数据持久化

### PracticeDataModels
语音练习数据结构：
- `PracticeGroup`: 练习组管理
- `PracticeItem`: 单次练习记录
- `AudioAnnotations`: 音频标注数据
- `WordAnnotation`: 词汇时间标注

## 🧪 测试功能

应用内置了完整的 OPFS 测试套件：
1. 访问应用并点击 "OPFS Test" 标签
2. 点击 "运行所有测试" 验证功能
3. 查看存储信息和文件管理

## 🌟 特色功能

- **🎨 多样化波形显示**: 三种渲染样式适应不同需求
- **📱 响应式设计**: 适配不同屏幕尺寸
- **🔒 本地存储**: 数据保存在浏览器本地，保护隐私
- **⚡ 高性能**: 自定义渲染引擎，流畅的交互体验
- **🧩 模块化设计**: 清晰的代码结构，易于扩展

## 📝 开发说明

### 数据模型
- 使用不可变数据结构
- 支持 JSON 序列化
- 提供 copyWith 方法用于状态更新

### 存储策略
- 元数据使用 JSON 格式存储
- 音频文件使用二进制格式存储
- 采用结构化文件命名规范

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目采用 MIT 许可证。
