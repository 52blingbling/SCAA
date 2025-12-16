# 润农扫码激活辅助软件

## 项目简介

这是一款基于Flutter开发的Android应用，主要用于管理和扫描二维码，并提供便捷的文本记录和跨应用粘贴功能。

## 功能特性

1. **单元管理系统**
   - 新建、删除、重命名单元
   - 直观的单元列表展示

2. **扫码功能**
   - 实时摄像头扫描二维码
   - 扫描成功后播放音效提示

3. **文本记录管理**
   - 按扫描顺序记录文本内容
   - 支持长按删除记录项
   - 支持复制扫描内容到剪贴板

4. **跨应用粘贴**
   - 在其他应用中粘贴扫描内容
   - 支持序号切换

## 项目结构

```
lib/
├── main.dart                 # 应用入口点
├── models/
│   ├── unit.dart            # 单元数据模型
│   └── scan_record.dart     # 扫描记录数据模型
├── screens/
│   ├── home_screen.dart     # 主界面
│   ├── unit_screen.dart     # 单元详情界面
│   └── scanner_screen.dart  # 扫码界面
├── services/
│   ├── unit_service.dart    # 单元管理服务
│   ├── audio_service.dart   # 音效服务
│   └── permission_service.dart # 权限服务
└── utils/
```

## 自动编译APK (GitHub Actions)

本项目已配置GitHub Actions工作流，可以自动编译APK文件。

### 工作流说明
- 当您向`main`或`master`分支推送代码时，会自动触发编译
- 工作流会使用Ubuntu环境进行构建
- 编译完成后，APK文件会作为artifact可供下载
- 使用最新的`actions/upload-artifact@v4`版本，避免兼容性问题

### 如何下载编译好的APK
1. 在GitHub仓库页面，点击"Actions"选项卡
2. 选择最近的workflow运行记录
3. 在"Artifacts"部分下载"release-apk"
4. 解压下载的文件即可获得APK

## 无需本地环境的在线编译平台推荐

### 1. Codemagic
- 网址: https://codemagic.io/
- 特点:
  - 专为Flutter应用设计
  - 提供免费构建额度
  - 支持Android APK和iOS IPA构建
  - 集成GitHub/GitLab等代码仓库

### 2. Bitrise
- 网址: https://www.bitrise.io/
- 特点:
  - 强大的自动化构建能力
  - 支持多种移动开发框架
  - 提供免费计划（有限构建分钟数）

### 3. GitHub Actions
- 网址: https://github.com/features/actions
- 特点:
  - 如果你的代码托管在GitHub上，这是最佳选择
  - 完全免费（对于公共仓库）
  - 高度可定制的工作流

### 4. GitLab CI/CD
- 网址: https://about.gitlab.com/stages-devops-lifecycle/continuous-integration/
- 特点:
  - 如果你的代码托管在GitLab上
  - 免费的构建管道
  - 易于配置的CI/CD流程

## 如何使用在线平台编译APK

### 使用Codemagic (推荐新手):
1. 将代码推送到GitHub仓库
2. 访问Codemagic并使用GitHub账号登录
3. 添加你的代码仓库
4. 配置构建设置（通常会自动检测Flutter项目）
5. 触发构建，等待完成
6. 下载生成的APK文件

### 注意事项:
- 需要为Android应用生成签名密钥以发布正式版本
- 免费计划通常有构建时间和次数限制
- 建议先使用调试版本进行测试

## 本地开发环境搭建（可选）

如果你以后想在本地开发，可以安装以下工具:

1. Flutter SDK (https://flutter.dev/docs/get-started/install)
2. Android Studio (https://developer.android.com/studio)
3. VS Code + Flutter插件（替代方案）

## 项目依赖说明

在`pubspec.yaml`中已经配置了所需的依赖包:
- `qr_code_scanner`: 二维码扫描功能
- `audioplayers`: 音频播放功能
- `permission_handler`: 权限处理
- `shared_preferences`: 本地数据存储
- `provider`: 状态管理

## 使用说明

1. 安装应用后，首先创建一个单元
2. 进入单元后点击"扫码"按钮进行二维码扫描
3. 扫描结果会自动保存到当前单元中
4. 点击"快捷助手"按钮打开悬浮窗
5. 在其他应用中需要粘贴时，点击悬浮窗的"粘贴"按钮

## 权限说明

应用需要以下权限:
- 相机权限：用于二维码扫描
- 悬浮窗权限：用于显示快捷助手
- 存储权限：用于保存数据

## 技术支持

如需技术支持或功能定制，请联系开发者。