# DeskMeow

DeskMeow 是一个桌面宠物应用，基于 Swift 开发，支持 macOS 平台。

## 功能简介
- 桌面宠物模拟与互动
- 覆盖窗口与传感器检测
- 活动模型与宠物行为引擎
- 简洁的 UI 交互体验

## 目录结构
```
Package.swift                // Swift 包管理配置
prd.md                      // 产品需求文档
technical-architecture.md   // 技术架构说明
docs/                       // 项目文档
  environment-setup.md      // 环境搭建说明
  environment-status.md     // 环境状态说明
  mvp-development-plan.md   // MVP 开发计划
  run-demo.md               // 运行演示说明
scripts/                    // 脚本文件
  dev_preflight.sh          // 开发前置脚本
Sources/                    // 源码目录
  PetAIDesktop/             // 主模块
    main.swift              // 程序入口
    App/                    // 应用相关
      AppDelegate.swift
      OverlayWindowController.swift
    Engine/                 // 引擎相关
      ActivityModels.swift
      OverlayViewModel.swift
      PetSimulationEngine.swift
      Desktop/              // 桌面相关
        DesktopWindowSensor.swift
        Platform.swift
    UI/                     // UI 相关
      OverlayRootView.swift
```

## 环境要求
- macOS 12 及以上
- Xcode 14 及以上
- Swift 5.7 及以上

## 快速开始
1. 克隆仓库：
   ```bash
   git clone https://github.com/yijunweng/DeskMeow.git
   cd DeskMeow
   ```
2. 打开 `Package.swift` 或使用 Xcode 打开项目。
3. 参考 `docs/environment-setup.md` 配置开发环境。
4. 编译并运行。

## 贡献指南
欢迎提交 issue 和 PR，详细流程见 `docs/` 目录。

## License
MIT
