# warehouse fixture

`school_index.pb` 是 `shiguang_warehouse` 索引的固定快照，用于验证
`WarehouseCatalog.fromPbBytes` 的解析结果。

- 来源：`https://github.com/XingHeYuZhuan/shiguang_warehouse` 的
  `index-pb-release` 分支
- 数据版本：`TIME_20261030072110_920`
- 抓取时间：2026-10-31
- 规模：271 个学校/工具条目，300 个适配器

测试会断言确切的条目数量、类别分布和关键学校字段，所以**不要**在仓库升级时
顺手替换这个文件。需要更新快照时，请在同一次提交里同步修改
`test/warehouse/catalog_test.dart` 与 `test/warehouse/registry_test.dart` 中的
数量断言，并在提交信息里写清新的 `version_id`。
