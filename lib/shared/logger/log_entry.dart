import 'package:isar_community/isar.dart';
import 'package:logging/logging.dart';

part 'log_entry.g.dart';

@Collection(accessor: "logEntries", inheritance: false)
class LogEntry {
  Id id = Isar.autoIncrement;
  final String message;

  @Enumerated(EnumType.ordinal)
  final LogLevel level;
  final DateTime timestamp;
  final String? context1;
  final String? context2;

  LogEntry({
    required this.message,
    this.level = LogLevel.WARNING,
    required this.timestamp,
    this.context1,
    this.context2,
  });

  @override
  String toString() {
    return 'InAppLoggerMessage(message: $message, level: $level, timestamp: $timestamp)';
  }
}

/// Log levels according to dart logging [Level.LEVELS]
enum LogLevel {
  ALL,
  FINEST,
  FINER,
  FINE,
  CONFIG,
  INFO,
  WARNING,
  SEVERE,
  SHOUT,
  OFF,
}

extension LevelExtension on Level {
  LogLevel toLogLevel() => LogLevel.values[Level.LEVELS.indexOf(this)];
}
