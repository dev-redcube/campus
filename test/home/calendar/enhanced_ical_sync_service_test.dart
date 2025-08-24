import 'package:flutter_test/flutter_test.dart';
import 'package:redcube_campus/home/calendar/service/enhanced_ical_sync_service.dart';

void main() {
  group('EnhancedICalSyncService', () {
    test('sync progress tracking works correctly', () {
      final progress = SyncProgress(
        status: SyncStatus.inProgress,
        totalCalendars: 5,
        syncedCalendars: 2,
        failedCalendars: 0,
      );
      
      expect(progress.progressPercent, equals(0.4));
      expect(progress.isCompleted, isFalse);
      expect(progress.hasErrors, isFalse);
    });
    
    test('sync result handles errors correctly', () {
      final errors = [
        CalendarSyncError(
          calendarId: 'test-id',
          calendarName: 'Test Calendar',
          error: 'Connection failed',
        ),
      ];
      
      final result = SyncResult(
        success: false,
        syncedCount: 1,
        failedCount: 1,
        errors: errors,
      );
      
      expect(result.success, isFalse);
      expect(result.errors, hasLength(1));
      expect(result.errors[0].calendarName, equals('Test Calendar'));
    });
    
    test('sync status enum works correctly', () {
      expect(SyncStatus.idle, isNotNull);
      expect(SyncStatus.inProgress, isNotNull);
      expect(SyncStatus.completed, isNotNull);
      expect(SyncStatus.completedWithErrors, isNotNull);
      expect(SyncStatus.failed, isNotNull);
    });
  });
}