/// THIS FILE IS A MODIFIED VERSION OF https://github.com/immich-app/immich/blob/main/mobile/lib/shared/services/immich_logger.service.dart
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:isar_community/isar.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:redcube_campus/shared/logger/log_entry.dart';
import 'package:redcube_campus/shared/prefs.dart';
import 'package:share_plus/share_plus.dart';

/// [HMLogger] is a custom logger that is built on top of the [logging] package.
/// The logs are written to the database and onto console, using `debugPrint` method.
///
/// The logs are deleted when exceeding the `maxLogEntries` (default 500) property
/// in the class.
///
/// Logs can be shared by calling the `shareLogs` method, which will open a share dialog
/// and generate a csv file.
class HMLogger {
  static final HMLogger _instance = HMLogger._internal();
  final maxLogEntries = 2000;
  final Isar _db = Isar.getInstance()!;
  List<LogEntry> _msgBuffer = [];
  Timer? _timer;

  factory HMLogger() => _instance;

  HMLogger._internal() {
    _removeOverflowMessages();
    late final int levelId;
    try {
      levelId = Prefs.logLevel.value;
    } catch (e) {
      levelId = Level.LEVELS.indexOf(Level.INFO);
    }
    Logger.root.level = Level.LEVELS[levelId];
    Logger.root.onRecord.listen(_writeLogToDatabase);
  }

  set level(Level level) => Logger.root.level = level;

  Future<List<LogEntry>> entries() async {
    return await _db.logEntries.where().anyId().findAll();
  }

  void _removeOverflowMessages() {
    final msgCount = _db.logEntries.countSync();
    if (msgCount > maxLogEntries) {
      final numberOfEntryToBeDeleted = msgCount - maxLogEntries;
      _db.writeTxn(
        () =>
            _db.logEntries.where().limit(numberOfEntryToBeDeleted).deleteAll(),
      );
    }
  }

  void _writeLogToDatabase(LogRecord record) {
    debugPrint('[${record.level.name}] [${record.time}] ${record.message}');
    final lm = LogEntry(
      message: record.message,
      level: record.level.toLogLevel(),
      timestamp: record.time,
      context1: record.loggerName,
      context2: record.stackTrace?.toString(),
    );
    _msgBuffer.add(lm);

    // delayed batch writing to database: increases performance when logging
    // messages in quick succession and reduces NAND wear
    _timer ??= Timer(const Duration(seconds: 5), _flushBufferToDatabase);
  }

  void _flushBufferToDatabase() {
    _timer = null;
    final buffer = _msgBuffer;
    _msgBuffer = [];
    _db.writeTxn(() => _db.logEntries.putAll(buffer));
  }

  Future<void> clearLogs() async {
    _timer?.cancel();
    _timer = null;
    _msgBuffer.clear();
    await _db.writeTxn(() async => await _db.logEntries.clear());
  }

  Future<void> shareLogs() async {
    final tempDir = await getTemporaryDirectory();
    final dateTime = DateTime.now().toIso8601String();
    final filePath = '${tempDir.path}/Campus_log_$dateTime.csv';
    final file = await File(filePath).create();
    final io = file.openWrite();
    try {
      // Header
      io.write("created_at;level;context;message;stacktrace\n");

      // Entries
      for (final l in await entries()) {
        io.write(
          '${l.timestamp};${l.level};"${l.context1 ?? ""}";"${l.message}";"${l.context2 ?? ""}"\n',
        );
      }
    } finally {
      await io.flush();
      await io.close();
    }

    await Share.shareXFiles(
      [XFile(filePath)],
      subject: "Campus Logs $dateTime",
      sharePositionOrigin: Rect.zero,
    ).then((value) => file.delete());
  }

  /// Flush pending log messages to persistent storage
  void flush() {
    if (_timer != null) {
      _timer!.cancel();
      _db.writeTxnSync(() => _db.logEntries.putAllSync(_msgBuffer));
    }
  }
}
