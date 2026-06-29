> 说明：本机未安装 Flutter，故采用"先写全部源码、后构建验证"策略。
> 已写好的源码标记为完成；需要 Flutter 工具链才能完成的构建/验证项保持未勾选。
> 实现偏差：数据层改用 `sqflite`（纯 SQL）替代 `drift`，原因见 design.md 决策 2。

## 1. 项目脚手架与基础设施

- [ ] 1.1 创建 Flutter 工程，配置 Android 构建，确认本机可出 debug apk（待装 Flutter 后 `flutter create --platforms=android .`，见 README）
- [x] 1.2 添加依赖：sqflite/path/path_provider、`google_mlkit_text_recognition`、`image_picker`、`csv`、`share_plus`、`flutter_riverpod`（pubspec.yaml）
- [x] 1.3 搭建分层目录结构（models / data / services / state / ui）与应用入口、主题、底部导航
- [x] 1.4 实现金额工具：元↔分（整数）转换与显示格式化（lib/services/money.dart）

## 2. 数据层（本地 SQLite / sqflite）

- [x] 2.1 定义表：`plates`（车牌）、`fee_presets`（费用预设）
- [x] 2.2 定义表：`ledgers`（账目记录：名称、创建日期、状态）
- [x] 2.3 定义表：`bills`（账单：柜号、日期、运费(分)、车牌号、外键 ledger）
- [x] 2.4 定义表：`extra_fees`（额外费用：名称快照、金额(分)、外键 bill）
- [x] 2.5 配置外键与级联删除（PRAGMA foreign_keys + ON DELETE CASCADE）
- [x] 2.6 编写各表仓储（增删改查）及聚合查询（账单小计、账单计数）

## 3. 车牌库（plate-registry）

- [x] 3.1 车牌列表页：展示、删除
- [x] 3.2 车牌新增/编辑：含唯一性校验（重复拒绝并提示）
- [x] 3.3 车牌选择器组件（供账单录入复用，支持现场新建车牌入库，受唯一性校验约束）

## 4. 费用预设（fee-presets）

- [x] 4.1 费用预设列表页：新增、编辑、删除
- [x] 4.2 费用预设选择器组件（选择预设或手动输入新名称）

## 5. 账目记录与账单（ledger-management）

- [x] 5.1 账目记录列表页：创建、查看（含账单数量/状态）、删除
- [x] 5.2 账目记录详情页：展示其下账单列表与汇总，提供导出入口
- [x] 5.3 账单录入/编辑页：柜号、日期（yyyy-MM-dd，仅到天）、运费、车牌号（接入支持现场新建的车牌选择器）
- [x] 5.4 额外费用编辑：在账单下增删多条（接入费用预设选择器，金额小数）
- [x] 5.5 账单小计计算与显示（运费 + 额外费用之和）

## 6. 柜号 OCR（container-ocr）

- [x] 6.1 封装 OCR service：`image_picker` 拍照/选图 + ML Kit 端上文字识别
- [x] 6.2 实现 ISO 6346 提取（正则 `[A-Z]{4}\d{7}`）与校验码验算
- [x] 6.3 识别确认框 UI：展示候选柜号与校验通过状态，支持确认/修改
- [x] 6.4 无合法柜号时回退手动输入；接入账单录入页柜号字段

## 7. CSV 导出（csv-export）

- [x] 7.1 封装 CSV exporter：扫描账目记录内额外费用名称并集 → 动态列集合
- [x] 7.2 逐行生成（固定字段 + 各费用列缺失留空 + 小计），输出 UTF-8（含 BOM）
- [x] 7.3 空账目记录的导出提示
- [x] 7.4 经 `share_plus` 调起系统分享/保存 CSV 文件

## 8. 联调与验收（需安装 Flutter 工具链后进行）

- [ ] 8.1 端到端走查：建账目记录 → 拍照识别柜号 → 录账单+额外费用 → 导出 CSV
- [ ] 8.2 用 Excel 打开导出 CSV 核对动态列、中文显示与金额小数正确
- [ ] 8.3 校验各 spec 场景（唯一性、级联删除、校验失败提醒、空导出等）+ `flutter test`
- [ ] 8.4 出 release apk 在真机安装验证
