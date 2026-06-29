# 物流账目管理 App（logistics_ledger）

跨平台（Flutter）移动端账目记录工具，**首期仅 Android**、纯本地、无后端、无账号。

## 功能

- 车牌库管理（仅存车牌号，唯一性校验）
- 账目记录 ▷ 账单（单柜号）▷ 额外费用 三层结构
- 物流柜号端上 OCR 识别（Google ML Kit，离线）+ ISO 6346 校验 + 确认框
- 额外费用预设，录入时可选或手输
- 金额支持小数（内部以"分"整数存储）
- 按单个账目记录导出 CSV（额外费用动态成列，UTF-8 含 BOM）

## 这个仓库现在缺什么

源码已写好，但**平台脚手架（android/ 目录等）尚未生成**，因为本机未安装 Flutter。
按下面步骤一次性补齐即可运行。

## 首次构建步骤

> 前置：安装 [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) 与
> Android Studio（含 Android SDK + JDK）。安装后 `flutter doctor` 应全绿（iOS 部分可忽略）。

1. 生成 Android 平台脚手架（不会覆盖已有的 `lib/`、`pubspec.yaml`）：
   ```bash
   flutter create --platforms=android --project-name logistics_ledger .
   ```

2. 拉取依赖：
   ```bash
   flutter pub get
   ```

3. 设置 ML Kit 所需的最低 SDK：编辑 `android/app/build.gradle`，
   将 `minSdkVersion` 改为 **21** 或更高：
   ```gradle
   defaultConfig {
       minSdkVersion 21
   }
   ```

4. （相机识别需要）在 `android/app/src/main/AndroidManifest.xml` 的
   `<manifest>` 内补充相机权限：
   ```xml
   <uses-permission android:name="android.permission.CAMERA"/>
   ```

5. 运行 / 出包：
   ```bash
   flutter run                # 连真机或模拟器调试
   flutter build apk --release  # 产出 build/app/outputs/flutter-apk/app-release.apk
   ```

## 跑测试（无需设备，可立即验证核心逻辑）

```bash
flutter test
```

覆盖：ISO 6346 校验码、金额分/元转换、CSV 动态列与合计。

## 代码结构

```
lib/
  main.dart                 应用入口（初始化 DB + Riverpod）
  models/models.dart        领域模型（金额=分，日期=yyyy-MM-dd）
  data/
    database.dart           SQLite 建表、外键、级联删除
    repositories.dart       车牌/费用预设/账目记录 仓储
  services/
    money.dart              分↔元 转换与格式化
    container_number.dart   ISO 6346 提取与校验（纯逻辑）
    csv_exporter.dart       CSV 动态列生成（含 BOM）
    ocr_service.dart        ML Kit 拍照/选图识别
  state/providers.dart      Riverpod providers
  ui/                       页面与组件（账目/车牌/费用/OCR 确认）
test/                       纯逻辑单元测试
```

## 关于 iOS

代码保持可移植，但 iOS 出包需要 macOS + Xcode（且分发 iPhone 需苹果开发者账号），
首期不交付。将来可用 Codemagic 等云端 CI 构建 iOS 包，业务代码无需改动。
