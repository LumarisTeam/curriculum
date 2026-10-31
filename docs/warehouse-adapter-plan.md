# curriculum × shiguang_warehouse 多学校适配接入计划

> 目标：让 `ios_club_app` 的「课表导入」覆盖 `shiguang_warehouse` 当前收录的 266 所学校（271 个条目、300 个适配器），并把主要领域逻辑沉淀到 `curriculum`。
>
> 非目标：成绩、考试、电费、饭卡等校园服务；这些不在适配仓库的能力范围内。

## 实施进度

- [x] **P0 契约与夹具**：Bridge protocol、shim、回调脚本；真实索引 fixture。
- [x] **P1 索引与模型**：`WarehouseCatalog` / `WarehouseRegistry`、无依赖 PB 解码、JSON 入口。
- [x] **P2 导入会话**：`WarehouseImportHost`、`WarehouseImportSession`、课程/作息/配置解码器、诊断。
- [x] **P3 App 接入**：仓库同步/缓存、学校选择页、WebView 导入页、Host 实现、课程落库、按学期配置计算周次。
- [ ] **P4 作息与周次**：已持久化适配器下发的作息与组合作息，尚未安装到 `TimeService`；自定义时间课程仍会跳过。
- [ ] **P5 加固与发布**：镜像、离线兜底、灰度、文档。

当前测试：`dart test test/warehouse`（45 个）、`flutter test test/unit/warehouse_course_mapper_test.dart`（3 个）。

---

## 1. 现状与判断

| 项目 | 现状 |
|---|---|
| `curriculum` | 纯 Dart HTML 解析库；3 个内置 Dart 适配器（标准表格 / 正方 / 西建大）+ 启发式兜底 |
| `ios_club_app` | 已依赖 `curriculum`，但导入页只抓 `document.documentElement.outerHTML` |
| 学校列表 | 来自 App 自家 `/api/v1/schools`，`School` 模型绑定 API 功能，不适合承载 266 所仅支持课表导入的学校 |
| 作息/周次 | `TimeService` 硬编码西建大的草堂/雁塔作息；周次来自西建大 API |
| `shiguang_warehouse` | 本地已 clone；271 个资源目录、289 个 JS 文件、索引 300 个适配器；MIT 协议 |

结论：**不要**把 300 个 JS 适配器逐个翻译成 Dart，也**不要**继续靠静态 HTML 解析。多数适配器需要复用 WebView 里的登录态、Cookie 和同源 `fetch`，因此正确做法是复用拾光的 JS 适配器，在 WebView 内执行。

但 JS 的**执行**必须由宿主完成；`curriculum` 保持纯 Dart，负责除执行外的全部领域逻辑。这是本计划的核心边界。

---

## 2. 设计决定

### 2.1 采用 JS 适配器 + WebView 运行时

- 与拾光同构：`window.shiguangBridge` / `window.shiguangBridgePromise`。
- 适配器不用改一行，仓库更新即可获得新学校。
- `curriculum` 不引入 Flutter / WebView 依赖，仍可用于 CLI、服务端和纯 Dart 测试。

### 2.2 职责划分

| 层 | 负责 | 不负责 |
|---|---|---|
| `curriculum` | 索引解析、学校/适配器模型、搜索与选择、Bridge 协议与 JS shim、导入会话状态机、结果解码、诊断、测试夹具 | 网络、文件、WebView、Cookie、持久化 |
| `ios_club_app` | 下载/缓存仓库、WebView、JavaScriptChannel、弹窗 UI、结果落库、作息/周次消费、导入入口 UI | 协议细节、结果拼装、课程校验 |

这样约 70% 的新代码在 `curriculum`，App 侧是薄宿主。

### 2.3 为什么不让 WebView 进 curriculum

- `curriculum` 的定位是纯 Dart 库，加入 `webview_flutter` 会强制 Flutter SDK，失去 CLI / 服务端 / 单元测试可用性。
- 如果以后需要，可另建 `curriculum_webview` 包，包装本计划中的 `WarehouseImportSession`；核心包保持纯净。

---

## 3. 总体架构

```
┌──────────────────────────── ios_club_app ────────────────────────────┐
│  WarehouseRepoService        WarehouseImportWebViewPage               │
│  - 下载/缓存 school_index.pb  - WebView + JavaScriptChannel           │
│  - 读取适配器 JS              - 实现 WarehouseImportHost              │
│  - 版本检查                   - 注入 bootstrap / adapter script       │
│                                                                      │
│  ImportedScheduleStore        CourseStore / TimeService / ScheduleStore│
│  - courses/timeSlots/config   - 落库、渲染、提醒、周次计算              │
└───────────────────────────────┬──────────────────────────────────────┘
                                │ bytes / js / messages
┌───────────────────────────────▼──────────────────────────────────────┐
│                         curriculum (pure Dart)                       │
│  WarehouseCatalog.fromPbBytes()   WarehouseAdapterRegistry            │
│  WarehouseImportSession           WarehouseBridgeProtocol / JS shim   │
│  WarehouseImportDecoder           ImportDiagnostics                   │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 4. curriculum 侧设计

### 4.1 新增独立入口

新增 `lib/warehouse.dart`，与现有 `lib/curriculum.dart` 并列：

```dart
// package:curriculum/warehouse.dart
export 'src/warehouse/model/warehouse_catalog.dart';
export 'src/warehouse/model/warehouse_school.dart';
export 'src/warehouse/model/warehouse_adapter.dart';
export 'src/warehouse/model/adapter_script.dart';
export 'src/warehouse/registry/warehouse_registry.dart';
export 'src/warehouse/bridge/bridge_protocol.dart';
export 'src/warehouse/bridge/bridge_shim.dart';
export 'src/warehouse/import/import_host.dart';
export 'src/warehouse/import/import_session.dart';
export 'src/warehouse/import/import_decoder.dart';
export 'src/warehouse/import/import_diagnostics.dart';
```

HTML 解析用户不必加载这部分；新增依赖只出现在这个入口。

### 4.2 文件结构

```text
curriculum/
├── lib/
│   ├── warehouse.dart                         # 新入口
│   └── src/warehouse/
│       ├── model/
│       │   ├── warehouse_catalog.dart         # 顶层索引
│       │   ├── warehouse_school.dart
│       │   ├── warehouse_adapter.dart
│       │   └── adapter_script.dart            # 适配器 JS + 元信息
│       ├── catalog/
│       │   ├── pb_decoder.dart                # 无依赖 protobuf wire 解码
│       │   └── catalog_json.dart              # 镜像/后端 JSON 备用入口
│       ├── registry/
│       │   └── warehouse_registry.dart        # 搜索、筛选、按学校/适配器查找
│       ├── bridge/
│       │   ├── bridge_protocol.dart           # action 常量、消息编解码
│       │   └── bridge_shim.dart               # window.shiguangBridge shim
│       ├── import/
│       │   ├── import_host.dart               # 宿主接口（WebView/UI）
│       │   ├── import_session.dart            # 状态机
│       │   ├── import_decoder.dart            # payload -> CourseImportResult
│       │   └── import_diagnostics.dart
│       └── ...
├── test/warehouse/
│   ├── catalog_test.dart
│   ├── registry_test.dart
│   ├── bridge_test.dart
│   ├── import_session_test.dart
│   ├── import_decoder_test.dart
│   └── fixtures/                              # 记录的真实 payload 序列
└── tool/warehouse/
    ├── validate.dart                          # 校验本地仓库 YAML/JS 完整性
    └── dump_catalog.dart                      # CLI：打印学校数、搜索、导出 JSON
```

### 4.3 数据模型

```dart
enum WarehouseCategory { generalTool, bachelorAndAssociate, postgraduate, unknown }

class WarehouseAdapter {
  final String adapterId;        // CQU、XAUAT_01
  final String schoolId;         // 所属学校 id
  final String adapterName;
  final WarehouseCategory category;
  final String assetJsPath;      // cqu.js
  final String? importUrl;
  final String? description;
  final String? maintainer;
}

class WarehouseSchool {
  final String id;
  final String name;
  final String initial;
  final String resourceFolder;
  final List<WarehouseAdapter> adapters;
}

class WarehouseCatalog {
  final int protocolVersion;
  final String versionId;
  final List<WarehouseSchool> schools;

  factory WarehouseCatalog.fromPbBytes(Uint8List bytes);
  factory WarehouseCatalog.fromJson(Map<String, dynamic> json);

  List<WarehouseSchool> get visibleSchools; // 含通用工具，对齐 App 列表
  WarehouseSchool? schoolById(String id);
  WarehouseAdapter? adapterById(String adapterId);
}
```

实现要点：

- **不引入 protobuf 依赖**。`school_index.proto` 字段很少，写一个约 100 行的 wire 解码器即可；与现有库里「不依赖 collection」的风格一致。
- 类别未知时归入 `unknown` 并记诊断，不抛异常。
- 重复 `id` 保留第一条并记诊断。
- `protocolVersion` 高于支持版本时仍尽量解析，同时暴露 `protocolMismatch` 诊断；宿主可据此提示用户更新 App。
- 计划支持协议版本 2（当前仓库版本）。

### 4.4 适配器注册表与选择

```dart
class WarehouseRegistry {
  WarehouseRegistry(this.catalog);

  List<WarehouseSchool> get schools;              // 271
  List<WarehouseSchool> search(String query);     // 名称 / 首字母 / adapterName
  List<WarehouseSchool> byCategory(WarehouseCategory c);
  List<WarehouseAdapter> adaptersForSchool(String schoolId);
  WarehouseAdapter? preferredAdapter(String schoolId); // 单适配器直接返回；多适配器返回第一个
}
```

排序与 App 保持一致：`initial.toUpperCase() + name`。多适配器学校（24 个）由 UI 让用户选择。

### 4.5 Bridge 协议

完全对齐拾光现有协议，适配器无需改动。

消息外壳：

```json
{ "action": "saveImportedCourses", "callbackId": "cb_1_...", "payload": "{\"coursesJsonString\":\"...\"}" }
```

支持的 action：

| action | payload | 回调结果 |
|---|---|---|
| `showToast` | `{message}` | 无 |
| `notifyTaskCompletion` | 无 | 无 |
| `showAlert` | `{titleText, contentText, confirmText}` | `null` |
| `showPrompt` | `{titleText, tipText, defaultText, validatorJsFunction}` | 输入字符串 |
| `showSingleSelection` | `{titleText, itemsJsonString, defaultSelectedIndex}` | 选中下标 |
| `saveImportedCourses` | `{coursesJsonString}` | `true` |
| `saveCourseConfig` | `{configJsonString}` | `true` |
| `savePresetTimeSlots` | `{timeSlotsJsonString}` | `true` |
| `saveComboSchedule` | `{comboScheduleJsonString}` | `true` |

实现要点：

- `payload` 在协议里是 **JSON 字符串**，需要二次解码。
- `showSingleSelection.itemsJsonString` 本身也是 JSON 字符串。
- 回调用 `window._shiguangNativeCallback(callbackId, success, resultLiteral)`；字符串结果必须 JSON 编码，`null` 直接写 `null`。
- `showPrompt` 的 `validatorJsFunction` 需要由会话调用宿主 `evaluateJavascript` 执行，返回非空字符串即校验失败。
- shim 默认使用 `window.shiguangBridgeNative.postMessage`；`webview_flutter` 的 `JavaScriptChannel` 正好提供这个入口。保留 `webkit.messageHandlers` / `cefQuery` 分支便于未来桌面端。

### 4.6 导入会话状态机

```dart
class WarehouseImportSession {
  WarehouseImportSession({
    required WarehouseAdapter adapter,
    required String script,
    required WarehouseImportHost host,
  });

  /// 页面开始加载时注入：定义 window.shiguangBridge。
  String get bootstrapScript;

  /// 用户点击「开始导入」时注入：执行适配器脚本。
  String get startScript;

  /// JavaScriptChannel 收到消息后调用。串行处理，避免回调乱序。
  Future<void> handleMessage(String raw);

  /// notifyTaskCompletion 时完成；失败时 completeError。
  Future<CourseImportResult> get completed;

  ImportDiagnostics get diagnostics;
}
```

宿主接口：

```dart
abstract interface class WarehouseImportHost {
  Future<String?> evaluateJavascript(String script);
  Future<void> showToast(String message);
  Future<void> showAlert({
    required String title,
    required String content,
    String? confirmText,
  });
  Future<String?> showPrompt({
    required String title,
    required String tip,
    String defaultText = '',
    String? validatorJsFunction,
  });
  Future<int?> showSingleSelection({
    required String title,
    required List<String> items,
    int defaultIndex = -1,
  });
}
```

状态机行为：

1. `handleMessage` 解码 action。
2. 弹窗类 action 调用 `host`，拿到结果后通过 `host.evaluateJavascript` 回传。
3. 保存类 action 解码并暂存到会话：
   - `saveImportedCourses`：课程数组，**追加**；
   - `saveCourseConfig`：最后一次生效；
   - `savePresetTimeSlots`：最后一次生效；
   - `saveComboSchedule`：最后一次生效。
4. `notifyTaskCompletion`：拼装 `CourseImportResult`，完成 `completed`。
5. 任何解码失败：回传 `false` + 错误信息，让适配器走自己的错误提示；同时记诊断，不崩溃。

### 4.7 结果解码

复用现有 `CourseImportResult`，它是拾光 `CourseTableImportModel` 的线格式，正好承载：

```dart
CourseImportResult(
  courses: [...],
  timeSlots: [...],
  config: CourseConfig(...),
  comboSchedule: ComboSchedule(...),
  warnings: [...],
  adapterId: 'CQU',
)
```

校验规则：

- `day` 不在 1..7 → 丢弃并记 `dayOutOfRange`。
- `weeks` 为空 → 保留，由宿主决定是否视为全周（适配器通常已展开）。
- `startSection` / `endSection` 缺失且 `isCustomTime == true` → 合法，保留自定义时间。
- `startSection` 为 null 且 `isCustomTime == false` → 记 `sectionParseFailed` 并丢弃（否则 App 无法渲染）。
- 相同课程是否合并：默认不合并，交由宿主；如需对齐 HTML 解析，可提供选项。

新增 `ParseWarningKind`：

- `adapterScriptMissing`
- `adapterProtocolMismatch`
- `invalidCoursePayload`
- `invalidTimeSlotPayload`
- `invalidConfigPayload`
- `bridgeActionFailed`

### 4.8 公开用法示例

```dart
import 'package:curriculum/warehouse.dart';

final catalog = WarehouseCatalog.fromPbBytes(pbBytes);
final adapter = catalog.adapterById('CQU')!;

final session = WarehouseImportSession(
  adapter: adapter,
  script: await repo.readScript(adapter),
  host: myHost,
);

// WebView onPageStarted / onPageFinished 后
await myHost.evaluateJavascript(session.bootstrapScript);

// 用户点击「开始导入」
await myHost.evaluateJavascript(session.startScript);

// JavaScriptChannel
await session.handleMessage(rawMessage);

final result = await session.completed;
// result.toJsonString() 即为拾光 saveImportedCourses 兼容格式
```

---

## 5. ios_club_app 侧改造

### 5.1 仓库同步与缓存

新增 `lib/features/education/services/warehouse_repo_service.dart`：

- 索引：`https://raw.githubusercontent.com/XingHeYuZhuan/shiguang_warehouse/index-pb-release/school_index.pb`
- 资源：`https://github.com/XingHeYuZhuan/shiguang_warehouse/archive/refs/heads/main.zip`（约 3 MB）
- 备用镜像：Gitee / 自建后端；建议后端代理并提供 JSON 版本，规避 GitHub 访问问题。
- 缓存目录：`ApplicationSupport/warehouse/{versionId}/`；保留上一版用于回滚。
- 启动时版本检查；失败时使用缓存；首次安装可内置一份快照或至少 4 个通用适配器。

### 5.2 WebView 导入页

新增 `warehouse_import_webview_page.dart`（保留现有 HTML 导入页作为兜底）：

- 打开 `adapter.importUrl`；`importUrl` 为空的通用工具允许用户手填网址。
- `addJavaScriptChannel('shiguangBridgeNative', onMessageReceived: session.handleMessage)`。
- `onPageStarted` 注入 `session.bootstrapScript`。
- 页面提供「开始导入」按钮，用户登录并进入课表页后点击，注入 `session.startScript`。
- 实现 `WarehouseImportHost`：SnackBar、AlertDialog、输入框、单选列表。
- 完成后把 `CourseImportResult` 交给落库层。

### 5.3 落库与消费

- 新增 `ImportedTimetable`：`schoolId / adapterId / importedAt / courses / timeSlots / config / comboSchedule`，存 Hive 或 prefs。
- `Course` → `CourseModel` 映射：
  - 现有字段直接映射；
  - `CourseModel` 新增 `isCustomTime` / `customStartTime` / `customEndTime`，修改 Hive adapter 与 `build_runner` 生成文件；
  - 网格渲染、提醒、小组件都要识别自定义时间。
- `TimeService`：
  - 新增 `installImportedSlots(List<TimeSlot>, schoolId)`；
  - 导入学校使用适配器下发的 `timeSlots`；没有时回退默认表；
  - 注意 `TimeSlot.number` 是 1-based，而现有 `ScheduleTable` 数组下标 0 是早自习，需要显式映射。
- 周次：
  - 存 `CourseConfig.semesterStartDate` / `semesterTotalWeeks`；
  - `ScheduleStore` 在导入学校下用本地日期计算当前周，不再调用西建大 `/Week`；
  - 无开学日期时，按「第 1 周」或用户手动选择，不能让课程消失。
- 存储隔离：已有 `GUEST_COURSE_DATA` 是全局的；按 `schoolId` 隔离，或在切换导入学校时明确提示覆盖。

### 5.4 UI

- 导入入口分两类：
  - 「本校服务」：现有后端 API 学校；
  - 「课表导入」：271 个仓库条目。
- 学校列表支持名称 / 拼音首字母 / 适配器名搜索，按本科/专科、研究生、通用工具筛选。
- 多适配器学校（24 个）进入二级选择，展示 `adapterName`、`description`、`maintainer`。
- 导入成功后展示诊断摘要：适配器 id、课程数、作息条数、warning 数。

### 5.5 平台配置

- Android：很多教务系统是 `http://`，需要在 `AndroidManifest.xml` 配置 network security config，仅对 WebView 放行明文流量。
- iOS：`Info.plist` 已开 `NSAllowsArbitraryLoads`，无需改动。
- 桌面端：`webview_flutter` 不支持 Windows/Linux；桌面端暂时保留「手填网址 + HTML 解析」，或后续接 `webview_windows` / `desktop_webview_window`。

---

## 6. 分阶段实施计划

| 阶段 | 工作内容 | 产出 | 验收 | 估算 |
|---|---|---|---|---|
| **P0 契约与夹具** | 从拾光提取 shim/协议；录制 3 类适配器的消息序列（XAUAT 树维、CQU、正方通用）；确定公开 API | `test/fixtures/warehouse/*`；协议文档 | 用夹具可重放完整导入 | 2 天 |
| **P1 索引与模型** | PB 解码、Catalog/Registry、搜索/筛选、诊断 | `warehouse.dart` 可解析 271 校 / 300 适配器 | 单测覆盖计数、类别、搜索、重复 id、未知枚举 | 3 天 |
| **P2 导入会话** | Bridge 编解码、shim、ImportSession、Host、Decoder | 纯 Dart 下可模拟完整导入 | 夹具重放产出 `CourseImportResult`，与拾光线格式一致 | 4 天 |
| **P3 App 接入** | 仓库同步、WebView、Host 实现、导入页 | iOS/Android 真机可导入 | XAUAT + CQU + 正方通用 3 校通过 | 3 天 |
| **P4 作息与周次** | `TimeSlot` 落库、`TimeService` 动态表、`CourseConfig`、自定义时间、存储隔离 | 外校课表时间/周次正确 | 节次时间、当前周、提醒均正确 | 4 天 |
| **P5 加固与发布** | 版本/协议校验、镜像、离线兜底、诊断上报、文档、许可证声明 | 可灰度发布 | 断网、旧缓存、坏适配器均不崩 | 3 天 |

合计约 **19 人日（3–4 周）**。P0–P2 可以完全在 `curriculum` 内完成，不依赖 App。

---

## 7. 测试计划

### 7.1 curriculum 单元测试

- **Catalog**：用仓库真实 `school_index.pb` 断言 271 校、300 适配器、类别分布；协议版本；重复 id；未知类别。
- **Registry**：搜索（中文、首字母、adapterName）、类别筛选、多适配器学校。
- **Bridge**：消息编解码、payload 二次解码、回调脚本转义（含引号/换行/中文）、非法 JSON。
- **ImportSession**：用 FakeHost 重放：
  - toast → selection → saveConfig → saveTimeSlots → saveCourses → notify；
  - 弹窗取消/拒绝；
  - prompt 校验函数；
  - 保存中途收到多批课程；
  - 适配器抛错/消息格式错误。
- **Decoder**：缺字段、day 越界、自定义时间、1-based time slots、空课程、重复课程。

### 7.2 App 集成测试

- 仓库同步：在线、离线、缓存损坏、版本回退。
- WebView：登录后导入、登录过期、页面跳转、HTTP 明文。
- 落库：课程/作息/配置写入后，重开 App 仍正确。
- 回归：现有 HTML 导入和 3 个 Dart 适配器不受影响。

### 7.3 适配器抽样

按教务系统类型抽样，优先：

- 树维（XAUAT）
- 正方（zhengfang_jiaowu 通用 + 1 所具体学校）
- 超星（chaoxing_jiaowu 通用）
- 青果 / URP（通用）
- 一个多适配器学校（如中山大学、中国科学技术大学）

不追求 266 校全覆盖；用线上诊断 + 用户反馈逐步收敛。

---

## 8. 风险与对策

| 风险 | 影响 | 对策 |
|---|---|---|
| 拾光协议/字段变更 | 导入失败 | 支持 `protocolVersion`；解析防御式；契约测试针对仓库脚本做静态检查 |
| 适配器脚本质量参差 | 部分学校失败 | Adapter allowlist/denylist；线上诊断；保留 HTML 兜底 |
| WebView 登录态/Cookie/SSO | 无法进入课表页 | 真机验证；不拦截第三方 Cookie；保留手动浏览器登录后手填 URL 的路径 |
| Android 明文 HTTP | 页面打不开 | network security config 仅放行 WebView |
| 桌面端无 WebView | 功能不可用 | 桌面端保留 HTML 导入；后续单独适配 |
| 自定义时间课程 | 渲染/提醒错误 | `CourseModel` 增加字段并覆盖网格、提醒、小组件 |
| 学校索引更新滞后 | 新学校不可见 | 启动时版本检查 + 手动刷新；镜像源 |
| 安全：执行仓库脚本 | 页面可访问登录态 | 只执行官方仓库、按版本/提交固定；不执行用户输入 JS |
| 许可证 | 合规 | 仓库 MIT；在 README/NOTICE 保留「星河欲转 / shiguang_warehouse」版权声明 |

---

## 9. 工作区与依赖

- 本地开发：`../shiguang_warehouse` 已存在，`tool/warehouse/validate.dart` 通过 `--warehouse /path/to/shiguang_warehouse` 读取。
- CI：checkout `XingHeYuZhuan/shiguang_warehouse` 固定 commit，用于夹具与校验；不要把整仓 JS 提交进 `curriculum`。
- `curriculum` 运行时依赖保持只有 `html`；`yaml` 仅作为 `dev_dependency` 供 `tool/` 使用。

---

## 10. 待确认

1. 学校资源分发：App 运行时从 GitHub/Gitee 同步，还是由自家后端代理？
2. 桌面端是否在本期范围内？如果必须支持，需要额外的 WebView 方案。
3. 导入学校与「本校服务学校」的关系：导入是否允许切换当前学校，还是只覆盖课表数据？
4. 是否需要把 JS 适配器快照打进 App 安装包，作为首次启动/离线兜底？

---

## 附：当前仓库数据快照

- 索引条目：271
- 真实学校：266
- 通用工具条目：5（通用工具与服务、正方通用、超星通用、青果通用、URP 通用）
- 适配器总数：300（本科/专科 276、研究生 16、通用工具 8）
- 本地 JS 文件：289
- 使用 `saveImportedCourses` / `notifyTaskCompletion` 的适配器：289 / 289
- 使用 `savePresetTimeSlots`：274
- 使用 `saveCourseConfig`：233
- 使用 `showSingleSelection`：225
- 使用 `showAlert`：240
- 使用 `showPrompt`：83
- 使用 `saveComboSchedule`：8
