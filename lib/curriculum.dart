/// 纯 Dart 的中国高校教务系统课表（课程表）HTML 解析库。
///
/// 输入教务系统课表页面的 HTML，输出结构化的课程数据；线格式对齐
/// [拾光课程表](https://github.com/XingHeYuZhuan/shiguangschedule) 的
/// `CourseImportExport`，因此解析结果可被其 `saveImportedCourses` 直接消费。
///
/// 本库**只做解析**：不联网、不登录、不持有 cookie、不读写文件。HTML 由调用方
/// 自行获取（HTTP 客户端、WebView、本地文件皆可）。
///
/// 典型用法：
///
/// ```dart
/// import 'package:curriculum/curriculum.dart';
///
/// final result = SchoolAdapterRegistry.standard.parseAuto(html);
/// for (final course in result.courses) {
///   print('${course.name} 周${course.day} 第${course.startSection}节');
/// }
/// ```
library;

export 'src/exceptions.dart';
export 'src/model/combo_schedule.dart';
export 'src/model/course.dart';
export 'src/model/course_config.dart';
export 'src/model/course_import_result.dart';
export 'src/model/json_utils.dart';
export 'src/model/parse_context.dart';
export 'src/model/parse_options.dart';
export 'src/model/parse_warning.dart';
export 'src/model/time_slot.dart';
export 'src/grid/table_grid.dart';
export 'src/adapter/adapter_registry.dart';
export 'src/adapter/block_list_adapter.dart';
export 'src/adapter/embedded_json_adapter.dart';
export 'src/adapter/builtin/standard_grid_adapter.dart';
export 'src/adapter/builtin/xauat_adapter.dart';
export 'src/adapter/builtin/zhengfang_grid_adapter.dart';
export 'src/adapter/general_matrix_adapter.dart';
export 'src/adapter/builtin_adapters.dart';
export 'src/adapter/matrix_table_adapter.dart';
export 'src/adapter/school_adapter.dart';
export 'src/grid/cell_position.dart';
export 'src/grid/matrix_layout.dart';
export 'src/parse/cell_text.dart';
export 'src/parse/course_cell_layout.dart';
export 'src/parse/course_source.dart';
export 'src/parse/course_source_parser.dart';
export 'src/parse/field_extractors.dart';
export 'src/parse/html_utils.dart';
export 'src/parse/section_parser.dart';
export 'src/parse/time_slot_parser.dart';
export 'src/parse/week_parser.dart';
