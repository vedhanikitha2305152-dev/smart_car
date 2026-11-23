import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static void init() {
    Logger.root.level = kDebugMode ? Level.ALL : Level.WARNING;
    Logger.root.onRecord.listen((record) {
      if (kDebugMode) {
        // Using debugPrint which is allowed (only plain print is banned)
        debugPrint(
          '[${record.level.name}] ${record.loggerName}: ${record.message}',
        );
        if (record.error != null) {
          debugPrint('  Error: ${record.error}');
        }
        if (record.stackTrace != null) {
          debugPrint('  Stack: ${record.stackTrace}');
        }
      }
    });
  }

  static Logger get(String name) => Logger(name);
}
