# 开发前环境准备（可执行版）

## 目标
确保本机满足以下能力：
- 可进行 macOS 桌面应用开发与调试
- 可进行性能分析（Instruments / xctrace）
- 可执行本项目离线开发与本地数据策略验证

## 必做步骤

### 1. 安装完整 Xcode
- 打开 App Store，搜索并安装 Xcode（建议最新版稳定版）。
- 安装完成后，执行以下命令切换开发者目录：
  - sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

### 2. 首次初始化
- xcodebuild -runFirstLaunch
- sudo xcodebuild -license accept

### 3. 校验工具链
- xcodebuild -version
- swift --version
- xctrace version

### 4. 运行项目预检脚本
- 在项目根目录执行：
  - bash scripts/dev_preflight.sh

脚本通过标准：
- xcodebuild 可用
- xctrace 可用
- Swift / Git / SQLite 可用

## 可选增强
- 安装 Homebrew（用于未来工具管理）
- 准备 Intel Mac 进行兼容性验证
- 提前加入 Apple Developer Program 以便签名与公证

## 与当前项目约束的对应
- 完全离线：不需要配置任何云服务
- 删除即清空：仅使用本地私有目录与本地 SQLite
- 随机行为：无需外部策略服务
