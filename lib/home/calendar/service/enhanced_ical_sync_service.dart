import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:redcube_campus/home/calendar/calendar_body.dart';
import 'package:redcube_campus/home/calendar/models/calendar.dart';
import 'package:redcube_campus/home/calendar/parse_events.dart';

/// Enhanced sync service with better reliability, retry mechanisms, and queue management
class EnhancedICalSyncService {
  final http.Client httpClient;
  final Isar _db;
  final Logger _log = Logger("EnhancedICalSyncService");
  final bool updateCalendarController;
  final int maxRetries;
  final Duration initialRetryDelay;
  final Duration maxRetryDelay;
  final Duration requestTimeout;
  
  // Queue management
  final Set<String> _currentlySyncing = <String>{};
  final StreamController<SyncProgress> _progressController = StreamController<SyncProgress>.broadcast();
  
  EnhancedICalSyncService({
    this.updateCalendarController = false,
    this.maxRetries = 3,
    this.initialRetryDelay = const Duration(seconds: 1),
    this.maxRetryDelay = const Duration(seconds: 30),
    this.requestTimeout = const Duration(seconds: 30),
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client(),
       _db = Isar.getInstance()!;

  /// Stream of sync progress updates
  Stream<SyncProgress> get progressStream => _progressController.stream;

  static Future<Directory> getPath() async =>
      Directory("${(await getApplicationSupportDirectory()).path}/calendars");

  /// Sync all active calendars with improved error handling and progress tracking
  Future<SyncResult> sync({
    void Function(int synced, int total)? onSyncProgress,
  }) async {
    final activeCalendars = await _db.calendars.filter().isActiveEqualTo(true).findAll();
    final path = await getPath();

    if (!await path.exists()) {
      await path.create(recursive: true);
    }

    int synced = 0;
    int failed = 0;
    final List<CalendarSyncError> errors = [];

    _log.info("Starting sync of ${activeCalendars.length} calendars");
    _emitProgress(SyncProgress(
      status: SyncStatus.inProgress,
      totalCalendars: activeCalendars.length,
      syncedCalendars: 0,
      failedCalendars: 0,
    ));

    for (final calendar in activeCalendars) {
      try {
        final result = await syncSingle(calendar);
        if (result.success) {
          synced++;
        } else {
          failed++;
          if (result.error != null) {
            errors.add(CalendarSyncError(
              calendarId: calendar.id,
              calendarName: calendar.name,
              error: result.error!,
            ));
          }
        }
      } catch (e, stackTrace) {
        failed++;
        _log.severe("Unexpected error syncing calendar ${calendar.name}", e, stackTrace);
        errors.add(CalendarSyncError(
          calendarId: calendar.id,
          calendarName: calendar.name,
          error: e.toString(),
        ));
      }

      onSyncProgress?.call(synced, activeCalendars.length);
      _emitProgress(SyncProgress(
        status: SyncStatus.inProgress,
        totalCalendars: activeCalendars.length,
        syncedCalendars: synced,
        failedCalendars: failed,
      ));
    }

    final finalStatus = failed == 0 ? SyncStatus.completed : SyncStatus.completedWithErrors;
    _emitProgress(SyncProgress(
      status: finalStatus,
      totalCalendars: activeCalendars.length,
      syncedCalendars: synced,
      failedCalendars: failed,
      errors: errors,
    ));

    _log.info("Sync completed: $synced successful, $failed failed");
    
    return SyncResult(
      success: synced > 0,
      syncedCount: synced,
      failedCount: failed,
      errors: errors,
    );
  }

  /// Sync a single calendar with retry logic and proper error handling
  Future<CalendarSyncResult> syncSingle(Calendar calendar) async {
    // Prevent concurrent syncing of the same calendar
    if (_currentlySyncing.contains(calendar.id)) {
      _log.info("Calendar ${calendar.name} is already being synced, skipping");
      return CalendarSyncResult(success: false, error: "Already syncing");
    }

    _currentlySyncing.add(calendar.id);
    
    try {
      final path = await getPath();
      if (!await path.exists()) await path.create(recursive: true);
      
      final file = File("${path.path}/${calendar.id}.ics");
      _log.info("Syncing calendar ${calendar.name}");

      // Attempt sync with retry logic
      Exception? lastException;
      for (int attempt = 0; attempt <= maxRetries; attempt++) {
        try {
          final result = await _attemptSync(calendar, file);
          if (result.success) {
            return result;
          }
          lastException = Exception(result.error);
        } catch (e) {
          lastException = e is Exception ? e : Exception(e.toString());
          
          if (attempt < maxRetries) {
            final delay = _calculateRetryDelay(attempt);
            _log.warning(
              "Sync attempt ${attempt + 1} failed for ${calendar.name}, retrying in ${delay.inSeconds}s: $e"
            );
            await Future.delayed(delay);
          }
        }
      }

      // All attempts failed
      await _handleSyncFailure(calendar, lastException);
      return CalendarSyncResult(
        success: false, 
        error: "Failed after $maxRetries retries: ${lastException?.toString() ?? 'Unknown error'}"
      );
      
    } finally {
      _currentlySyncing.remove(calendar.id);
    }
  }

  /// Attempt to sync a calendar (single attempt)
  Future<CalendarSyncResult> _attemptSync(Calendar calendar, File file) async {
    final request = http.Request('GET', Uri.parse(calendar.url));
    request.headers['User-Agent'] = 'Campus App Calendar Sync/1.0';
    
    final streamedResponse = await httpClient.send(request).timeout(requestTimeout);
    
    if (streamedResponse.statusCode != 200) {
      final error = "HTTP ${streamedResponse.statusCode}: ${streamedResponse.reasonPhrase}";
      await _updateCalendarFailureCount(calendar);
      return CalendarSyncResult(success: false, error: error);
    }

    // Stream the response to handle large files efficiently
    final bytes = await streamedResponse.stream.toBytes();
    await file.writeAsBytes(bytes);
    
    _log.info("Downloaded calendar ${calendar.name} (${bytes.length} bytes)");

    // Update calendar controller if requested
    if (updateCalendarController) {
      try {
        // Remove old events for this calendar
        eventsController.removeWhere(
          (element) => element.eventData?.calendarId == calendar.id,
        );

        // Parse and add new events
        final events = await parseEvents(calendar);
        eventsController.addEvents(events.toList());
        _log.info("Updated calendar controller with ${events.length} events for ${calendar.name}");
      } catch (e) {
        _log.warning("Failed to update calendar controller for ${calendar.name}: $e");
        // Continue with sync success even if controller update fails
      }
    }

    // Update calendar metadata
    await _updateCalendarSuccess(calendar);
    
    return CalendarSyncResult(success: true);
  }

  /// Calculate retry delay using exponential backoff with jitter
  Duration _calculateRetryDelay(int attempt) {
    final baseDelay = initialRetryDelay.inMilliseconds;
    final exponentialDelay = baseDelay * pow(2, attempt);
    final jitter = Random().nextInt(1000); // Add up to 1s jitter
    final totalDelay = min(exponentialDelay + jitter, maxRetryDelay.inMilliseconds);
    return Duration(milliseconds: totalDelay.toInt());
  }

  /// Update calendar metadata on successful sync
  Future<void> _updateCalendarSuccess(Calendar calendar) async {
    await _db.writeTxn(() async {
      calendar.lastUpdate = DateTime.now();
      calendar.numOfFails = 0;
      await _db.calendars.put(calendar);
    });
  }

  /// Update calendar metadata on sync failure
  Future<void> _updateCalendarFailureCount(Calendar calendar) async {
    await _db.writeTxn(() async {
      calendar.numOfFails++;
      await _db.calendars.put(calendar);
    });
  }

  /// Handle sync failure with proper logging and error tracking
  Future<void> _handleSyncFailure(Calendar calendar, Exception? error) async {
    _log.warning("Failed to sync calendar ${calendar.name}", error);
    
    if (updateCalendarController) {
      try {
        // Remove failed calendar events from controller
        eventsController.removeWhere(
          (element) => element.eventData?.calendarId == calendar.id,
        );
      } catch (e) {
        _log.warning("Failed to remove events for failed calendar ${calendar.name}: $e");
      }
    }
    
    await _updateCalendarFailureCount(calendar);
  }

  /// Emit progress update to listeners
  void _emitProgress(SyncProgress progress) {
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  /// Clean up old calendar files that are no longer in use
  Future<void> cleanupOldCalendars(Directory path, Iterable<Calendar> calendars) async {
    if (!await path.exists()) return;
    
    await for (final entity in path.list()) {
      if (entity is File && entity.path.endsWith('.ics')) {
        final filename = entity.path.split(Platform.pathSeparator).last;
        final calendarId = filename.split(".").first;
        
        if (!calendars.any((element) => element.id == calendarId)) {
          try {
            await entity.delete();
            _log.info("Removed old calendar file: $filename");
          } catch (e) {
            _log.warning("Failed to remove old calendar file $filename: $e");
          }
        }
      }
    }
  }

  /// Get all active calendars
  Future<List<Calendar>> getActiveCalendars() async =>
      _db.calendars.filter().isActiveEqualTo(true).findAll();

  /// Dispose resources
  void dispose() {
    httpClient.close();
    _progressController.close();
  }
}

/// Represents the overall sync progress
class SyncProgress {
  final SyncStatus status;
  final int totalCalendars;
  final int syncedCalendars;
  final int failedCalendars;
  final List<CalendarSyncError> errors;

  SyncProgress({
    required this.status,
    required this.totalCalendars,
    required this.syncedCalendars,
    required this.failedCalendars,
    this.errors = const [],
  });

  double get progressPercent => totalCalendars == 0 ? 0.0 : syncedCalendars / totalCalendars;
  
  bool get isCompleted => status == SyncStatus.completed || status == SyncStatus.completedWithErrors;
  bool get hasErrors => failedCalendars > 0 || errors.isNotEmpty;
}

/// Sync status enumeration
enum SyncStatus {
  idle,
  inProgress,
  completed,
  completedWithErrors,
  failed,
}

/// Result of syncing all calendars
class SyncResult {
  final bool success;
  final int syncedCount;
  final int failedCount;
  final List<CalendarSyncError> errors;

  SyncResult({
    required this.success,
    required this.syncedCount,
    required this.failedCount,
    required this.errors,
  });
}

/// Result of syncing a single calendar
class CalendarSyncResult {
  final bool success;
  final String? error;

  CalendarSyncResult({required this.success, this.error});
}

/// Error information for a failed calendar sync
class CalendarSyncError {
  final String calendarId;
  final String calendarName;
  final String error;

  CalendarSyncError({
    required this.calendarId,
    required this.calendarName,
    required this.error,
  });

  @override
  String toString() => '$calendarName: $error';
}