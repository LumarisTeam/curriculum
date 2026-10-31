# curriculum

纯 Dart 的中国高校教务系统**课表 HTML 解析库**。

输入教务系统课表页面的 HTML，输出结构化的课程数据。线格式对齐
[拾光课程表](https://github.com/XingHeYuZhuan/shiguangschedule) 的
`CourseImportExport`，因此解析结果可以被它的 `saveImportedCourses` 直接消费，
也就等于免费继承了那套已有的适配生态。

## 这个库做什么、不做什么

**做**：把一段 HTML 变成 `List<Course>`。纯函数，输入输出都在内存里。

**不做**：不联网、不登录、不持 cookie、不读写文件。HTML 由调用方自己拿——
HTTP 客户端、WebView、本地文件、剪贴板都行。

这条边界是刻意的。拾光课程表的做法是把每所学校的适配逻辑写成 JavaScript，
注入到已登录的 WebView 里执行；那样能做很多事（复用页面里的 jQuery、同源
`fetch`），但代价是解析必须跑在一个真实的浏览器上下文里。本库反过来：把那些
适配脚本里**真正通用的部分**（表格几何、周次/节次文本解析、字段抽取、合并去重）
用 Dart 原生实现，让不需要 WebView 的场景也能拿到结构化课表。

## 快速开始

```dart
import 'package:curriculum/curriculum.dart';

final html = await myHttpClient.fetchTimetablePage();
final result = SchoolAdapterRegistry.standard.parseAuto(html);

for (final course in result.courses) {
  print('${course.name} 周${course.day} '
      '第${course.startSection}-${course.endSection}节 '
      '${weekListToString(course.weeks)}');
}

// 直接产出拾光课程表能吃的 JSON
print(result.toJsonString());   // {"courses":[...],"timeSlots":[...],"config":null}
```

命令行试一下：

```bash
dart run example/main.dart 你的课表.html
dart run example/main.dart 你的课表.html --json
```

## 数据模型

六个类，字段与拾光课程的 `CourseImportExport` 一一对应。

| Dart | 对应 Kotlin | 说明 |
|---|---|---|
| `Course` | `ImportCourseJsonModel` | 一门课 |
| `CourseConfig` | `CourseConfigJsonModel` | 学期配置 |
| `TimeSlot` | `TimeSlotJsonModel` | 一个节次的作息时间 |
| `CourseImportResult` | `CourseTableImportModel` | 一次解析的完整产出 |
| `ComboSchedule` | `ComboScheduleJsonModel` | 组合作息方案（可选扩展） |
| `PublicScheduleTemplate` | `PublicScheduleTemplateJsonModel` | 组合作息下的公共作息模板 |

`Course.credit`（学分）与 `CourseImportResult.comboSchedule`（组合作息）是
**直通字段**：解析器不会产出它们——HTML 课表通常既不写学分，也不携带作息方案——
但 `fromJson` / `toJson` 会原样保留，保证线格式往返不丢数据。

### 三条会咬人的不变量

1. **`day` 是 ISO 编号**：周一 = 1 … 周日 = 7。
2. **`weeks` 永远是展开后的整数列表**，已升序排序、去重、不可变。单双周只是
   解析期的临时概念，`[1,3,5]` 而不是 `"1-8周(单)"`。
3. **`config` 默认是 `null`**，而且这个默认值很重要。拾光课程表的导入逻辑是
   `configJson?.defaultClassDuration ?: existing ?: 45`——**非空 config 会覆盖
   用户本地的上下课时长**。解析器无从得知某校一节课多长，所以除非页面确实写明，
   否则不该产出它。要用就显式开 `ParseOptions(emitConfig: true)`。

## 已内置的适配器

| 适配器 id | 覆盖的形态 | 位置来源 | 字段顺序 |
|---|---|---|---|
| `STANDARD_GRID_01` | 星期 × 节次矩阵表 | 表格几何 + `rowspan` | 课程名/教师/周次/教室 |
| `ZHENGFANG_GRID_01` | 正方教务时间网格视图 | `td` 的 `id="星期-节次"` | 课程名/周次/地点/教师 |
| `XAUAT_01` | 西建大 · 一列一天的 div 课表 | 所在**列**的序号 | 课程名/教室（括号子句写周次与节次） |
| `GENERIC_MATRIX_01` | 启发式兜底 | 表格几何 | 按上面的顺序猜 |

内置清单由 `buildBuiltinAdapters()` 给出，注册表 `SchoolAdapterRegistry.standard`
在首次访问时装配。`GENERIC_MATRIX_01` 的置信度被压到 0.1，只在没有别的候选时生效；
它的结果**不保证正确**，一旦某校有了真实样本就该写专用适配器把它盖过去。

## 新增一所学校

多数情况下**不需要写解析代码**，只是改配置。以矩阵式课表为例：

```dart
class MySchoolAdapter extends MatrixTableAdapter {
  const MySchoolAdapter();

  @override
  SchoolAdapterInfo get info => const SchoolAdapterInfo(
        adapterId: 'MYSCHOOL_01',
        schoolId: 'MYSCHOOL',
        adapterName: '某某大学 · 教务系统',
      );

  // 选结构标记，不要选校名——一所学校的页面结构比它的品牌文案稳定得多。
  @override
  List<String> get requiredMarkers => const <String>['myKbTable'];

  @override
  MatrixTableConfig get config => const MatrixTableConfig(
        headerRowCount: 2,          // 表头占几行
        headerColumnCount: 1,       // 左侧「节次」标签占几列
        tableLocator: TableLocator.css('#myKbTable'),
        dayColumns: DayColumns.headerLabels(),      // 从表头认「星期一」
        sectionMapping: SectionMapping.labelColumn(column: 0),
        positionResolver: CellPositionResolver.geometry(),
        cellLayout: OrderedLineLayout(order: <CourseField>[
          CourseField.name, CourseField.teacher,
          CourseField.weeks, CourseField.position,
        ]),
      );
}
```

四步：**挑结构标记** → **选表格** → **定表头与星期/节次来源** → **定字段顺序**。

常见差异对应的改动：

| 学校的差异 | 改哪里 |
|---|---|
| 字段顺序是 教师/课程名/周次/教室 | 调换 `OrderedLineLayout.order` |
| 单元格是 `课程：X` / `教师：Y` 标签式 | 换成 `LabeledLineLayout()` |
| 单元格是单行 `X@Y@Z` | 换成 `DelimitedLineLayout(...)` |
| 位置写在 `td` 的 `id` 里 | `CellPositionResolver.byId()` |
| 一列一天，星期靠列序号 | `DaySectionResolver.fromAncestorIndex(...)` |
| 周次/节次写成 `(1~16周)` `(1,2节)` 子句 | `ParenthesizedClauseLayout()` |
| 位置按行列索引直算 | `CellPositionResolver.byIndex(...)` |
| 行为星期、列为节次 | `orientation: MatrixOrientation.daysAreRows` |
| 多一个「课程代码」字段打头 | `order` 里加 `CourseField.ignore` |
| 周次用 `/` 分隔 | `WeekParser(extraRangeSeparators: ['/'])` |
| 字段靠源码换行分隔 | `BlockListAdapter.keepSourceNewlines => true` |

**结构**不同才需要新代码，而这时通常只要换一个基类：

- 绝对定位的 `<div>` 课程块 → 继承 `BlockListAdapter`，给出 `blockSelector` 与
  `DaySectionResolver`。
- 数据留在页面 `<script>` 里 → 继承 `EmbeddedJsonAdapter`，给出
  `JsonPayloadLocator` 与 `mapPayload`。

三所内置适配器之间的差别正好演示了这套配置面：`STANDARD_GRID_01` 用表格几何 +
`rowspan` 定位置，`ZHENGFANG_GRID_01` 改从 `td` 的 `id` 读位置并调换字段顺序，
`XAUAT_01` 换成 div 布局、按列序号定星期、用括号子句抽周次与节次——**都没有新写
解析算法**，只是换了配置与基类。

## 周次与节次的写法支持

`parseWeeks` 处理（返回的永远是展开后的整数列表）：

| 输入 | 结果 |
|---|---|
| `1-16周`、`第1-16周`、`1-16` | 1…16 |
| `1-16周(单)`、`1-8周（单）`、`1-8周 单`、`单1-8周` | 1,3,5,… |
| `2-16双周`、`1-16周(双)` | 2,4,6,… |
| `单周`、`双周`、`全周`、`每周` | 按上界展开 |
| `3-5,7,9周`、`1,3,5-9周`、`1-4,6-8,10-16周` | 并集 |
| `1~16周`、`1—16周`、`1－16周`、`1至16周`、`1到16周` | 1…16 |
| `１-１６周`（全角数字） | 1…16 |
| `1-8周(单),9-16周(双)` | 逐子句独立处理，得 1,3,5,7,10,12,14,16 |
| `1-16周(除3,5)`、`1-16周(每2周)` | 排除 / 间隔 |
| `详询教务处` | `null` + 一条诊断 |

`parseSections` 处理 `第1-2节`、`3-4`、`第1,2节`、`上午1-2节`、`星期三第3-4节`，
以及强智等系统的紧凑写法 `0102`（= 第 1、2 节）。

## 容错与诊断

**`parse()` 永不因内容问题抛异常。** 60 门课的表里有一个坏单元格，不该让用户丢掉
整次导入。部分解析策略：

| 情况 | 处理 |
|---|---|
| 单元格畸形 | 跳过该格 + `warning`，继续 |
| 周次解析不出来 | 回退「全周」+ `warning`，**保留课程** |
| 课程名为空 | 丢弃该条 + `warning`（无名课程不可用） |
| 教师/地点缺失 | 填空串 + `info` |
| 星期越界 | 丢弃该门课 + `error` |

只有 `parseOrThrow()` 和 `parseAs()`（传了未知 id）会抛异常。

诊断都收在 `result.warnings` 里，`result.diagnosticReport` 能渲染成一段可直接粘进
issue 的报告：

```
curriculum — adapter YNUFE_01
courses: 7   timeSlots: 0   config: none
stats: cells: 26 seen, 12 parsed, 4 skipped; courses: 7; warnings: 3
warnings: 3 (0 error, 2 warning, 1 info)
  WARN  r6.c4 单元格文本无法理解 <- "调课通知 详见教务处"
  WARN  table 周次无法解析，回退为全部 20 周 <- "待定"
  INFO  #kbTable colspan 跨了 2 天，逐天各产出一条
```

## 已知边界

- **只做解析**。抓取、登录、验证码、会话保持都不在范围内。
- **纯 Dart 没有排版引擎**，所以不能像浏览器里的适配脚本那样用
  `getBoundingClientRect()` 判列位置。位置一律来自表格几何或元素的 `id`/`data-*`。
- `MatrixOrientation.daysAreRows` 只适用于**真正的矩阵**（行为星期、列为节次）。
  「正方列表视图」那种两列文字列表不是矩阵，需要走块列表适配器。

## 工具链

需要 Dart >= 3.11。仓库里的 `.fvmrc` 目前固定 Flutter 3.41.9（带 Dart 3.11.5），
这是过渡措施——本包本身不依赖 Flutter，等能装上更新的 SDK 后可以删掉。

```bash
dart pub get --offline   # 依赖都已在本机 pub cache 里
dart test
dart analyze
dart run example/main.dart 你的课表.html
```

## 贡献样本

最有价值的贡献是一个真实教务系统的课表页样本。投放方式是**两个文件**，
`registerFixtureSuites()` 会自动把它变成一个测试，零代码。步骤见
[test/fixtures/README.md](test/fixtures/README.md)。

样本入库前请脱敏，不要包含真实师生姓名与学号。

## 许可

MIT，见 [LICENSE](LICENSE)。
