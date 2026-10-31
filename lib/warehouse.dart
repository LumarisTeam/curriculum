/// 拾光适配仓库（`shiguang_warehouse`）的纯 Dart 接入层。
///
/// 它把仓库索引解析成学校/适配器模型，并提供 JS Bridge 协议、shim 与导入
/// 会话所需的全部领域逻辑。**它不执行 JavaScript**：WebView、Cookie、网络
/// 和文件仍由宿主负责。这样 `curriculum` 可以继续保持纯 Dart，也能在 CLI
/// 和单元测试里模拟完整的导入流程。
///
/// 典型用法：
///
/// ```dart
/// import 'package:curriculum/warehouse.dart';
///
/// final catalog = WarehouseCatalog.fromPbBytes(indexBytes);
/// final registry = WarehouseRegistry(catalog);
/// final cqu = registry.schoolById('CQU');
/// ```
library;

export 'src/model/combo_schedule.dart';
export 'src/model/course.dart';
export 'src/model/course_config.dart';
export 'src/model/course_import_result.dart';
export 'src/model/parse_warning.dart';
export 'src/model/time_slot.dart';
export 'src/warehouse/bridge/bridge_protocol.dart';
export 'src/warehouse/bridge/bridge_shim.dart';
export 'src/warehouse/model/adapter_script.dart';
export 'src/warehouse/model/warehouse_adapter.dart';
export 'src/warehouse/model/warehouse_catalog.dart';
export 'src/warehouse/model/warehouse_school.dart';
export 'src/warehouse/import/import_decoder.dart';
export 'src/warehouse/import/import_diagnostics.dart';
export 'src/warehouse/import/import_host.dart';
export 'src/warehouse/import/import_session.dart';
export 'src/warehouse/registry/warehouse_registry.dart';
