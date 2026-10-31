# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-10-31

### Added

- `Course.credit`：对齐拾光课程表 2026-09-27 新增的学分字段。解析器不产出该
  字段；`fromJson` 接受整数、浮点与数字字符串。
- `ComboSchedule` / `PublicScheduleTemplate` 与
  `CourseImportResult.comboSchedule`：对齐拾光课程表 2026-09-26 的组合作息
  导入/导出扩展，`fromJson` / `toJson` 往返不再丢失该字段。
- `JsonMapReader.asDoubleOrNull` / `asDouble` 与 `coerceDouble`。

## [0.1.0] - 2026-09-15

### Added

- `Course` / `CourseConfig` / `TimeSlot` / `CourseImportResult`，手写 JSON
  编解码，字段与拾光课程表的 `CourseImportExport` 一一对应。
- `TableGrid`：完整的 `rowspan` / `colspan` 归一化，含跨行宿主追踪、参差行补齐、
  `rowspan="0"`、跨度钳制、转置。
- `extractCellLines`：基于 DOM 走查的分行与清洗（`<br>`、块级嵌套、`&nbsp;`、
  宽间隔字段分隔）。
- `parseWeeks`：区间、列表、单双周、全周、全角数字、六种破折号、排除与间隔子句；
  逐子句独立处理单双周。
- `parseSections`：含紧凑写法 `0102`、星期标签剥离、行索引兜底。
- `parseTimeSlots`：从表头抽取作息时间。
- `CourseCellLayout` 家族（定序 / 标签 / 分隔符 / 组合），带字段纠偏与启发式补漏。
- `SchoolAdapter` + `SchoolAdapterRegistry`：标记探测、置信度排序、`parseAuto`
  （无候选时返回带诊断的空结果而非抛异常）。
- `MatrixTableAdapter`（矩阵基类，含 `CellPositionResolver` 三种位置来源）、
  `BlockListAdapter`（div 块）、`EmbeddedJsonAdapter`（内嵌 JSON，含括号配对扫描）。
- 内置适配器 `STANDARD_GRID_01`、`ZHENGFANG_GRID_01`、`GENERIC_MATRIX_01`。
- 结构化诊断 `ParseWarning` / `ParseStats` / `diagnosticReport`；
  `parse` 永不因内容问题抛异常。
- `extractCellLines` 的 `keepSourceNewlines`：把 HTML 源码换行当作换行，
  用于服务端渲染、靠源码换行分隔字段的页面。
- `parseSections` 支持外层括号（`(1,2节)`），与周次解析的处理对称。
- `ParenthesizedClauseLayout`：抽取 `(1~16周)`、`(1,2节)` 这类括号子句，
  支持一层嵌套（`(1~16周(单))`）。
- `DaySectionResolver.fromAncestorIndex`：星期由祖先元素的列序号决定，
  用于「一列一天」的 div 课表。
- `BlockListAdapter` 的 `contentSelector` 与 `keepSourceNewlines`。
- 位置启发式新增中文楼栋房号（`教一101`、`北101`）。
- 内置适配器 `XAUAT_01`（西安建筑科技大学），含两个端到端样本。
- fixture 自动发现工具 `registerFixtureSuites()`。

[Unreleased]: https://github.com/lijiajunply/curriculum/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/lijiajunply/curriculum/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/lijiajunply/curriculum/releases/tag/v0.1.0
