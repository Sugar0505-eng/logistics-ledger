# 物流账目管理 App（logistics_ledger）

Flutter 移动端物流账单记录工具。Android 为首要交付平台，数据与 OCR 均在设备本地处理，无后端、无账号。

## 功能

- 车牌库管理与唯一性校验
- 账目记录、账单、额外费用三层结构
- 账目名称编辑与“编辑中/已完成”状态管理
- Google ML Kit 端上 OCR + ISO 6346 柜号格式和校验码验证
- 额外费用预设，录入时可选择或手动输入
- 多条公司账户预设，每个账目选择一条用于导出
- 金额以整数分存储，显示和导出时格式化为两位小数
- 单个账目记录导出 Excel，支持自定义文件名、动态费用列、合计与账户预设

## 环境要求

- Flutter stable 3.44 或更高
- Dart 3.12 或更高
- Android SDK 24 或更高
- iOS 15.5 或更高（仅可在 macOS + Xcode 上构建）

项目已提交 Android/iOS 平台工程和 `pubspec.lock`，构建不再临时生成平台脚手架。

## 本地验证

```bash
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

连接 Android 真机或启动模拟器后：

```bash
flutter run
flutter build apk --release
```

未配置 `android/key.properties` 时，Release APK 使用调试密钥，适合内部验证但不可用于正式发布。正式发布前创建上传密钥，并以 `android/key.properties.example` 为模板配置本机 `android/key.properties`；密钥和密码文件均不得提交到 Git。

## 代码结构

```text
lib/
  main.dart                 应用入口（初始化数据库 + Riverpod）
  models/models.dart        领域模型（金额=分，日期=yyyy-MM-dd）
  data/
    database.dart           SQLite 建表、外键与级联删除
    repositories.dart       车牌、费用预设、账目和账单仓储
  services/
    money.dart              分/元转换与格式化
    container_number.dart   ISO 6346 提取与校验
    excel_exporter.dart     Excel 导出与样式生成
    ocr_service.dart        ML Kit 拍照/选图识别
  state/providers.dart      Riverpod providers
  ui/                       账目、车牌、费用与 OCR 页面
test/                       单元、仓储与组件测试
android/                    Android 工程与发布配置
ios/                        iOS 工程、权限说明与 SwiftPM 配置
```

## CI 与发布

`codemagic.yaml` 提供 Android APK、iOS 无签名编译和 TestFlight 三条工作流。所有工作流都会校验锁文件、格式、静态分析和测试，再进入构建。

TestFlight 工作流需要在 Codemagic 中配置 App Store Connect 集成 `APP_STORE_CONNECT_KEY` 和 `com.sugar0505.logisticsledger` 的签名资料。Android 正式上架还需配置独立上传密钥；Google Play 推荐发布 AAB，而不是将内部测试 APK 直接上架。

## 数据边界

SQLite 数据仅保存在当前设备。Excel 可用于报表导出，但不是完整数据库备份，也不能恢复应用数据。正式承载业务数据前，应完成真机 OCR、Excel 导出、升级迁移和备份恢复验收。
