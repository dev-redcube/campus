import 'package:redcube_campus/home/calendar/models/calendar.dart';
import 'package:redcube_campus/home/calendar/service/enhanced_ical_sync_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ical_sync_state.g.dart';

enum ICalSyncProgressEnum { idle, inProgress, done, error }

class ICalSyncState {
  final ICalSyncProgressEnum syncProgress;
  final double progressInPercent;
  final List<CalendarSyncError> errors;
  final String? errorMessage;

  ICalSyncState({
    required this.syncProgress,
    this.progressInPercent = 0,
    this.errors = const [],
    this.errorMessage,
  });
  
  bool get hasErrors => errors.isNotEmpty || errorMessage != null;
  
  ICalSyncState copyWith({
    ICalSyncProgressEnum? syncProgress,
    double? progressInPercent,
    List<CalendarSyncError>? errors,
    String? errorMessage,
  }) {
    return ICalSyncState(
      syncProgress: syncProgress ?? this.syncProgress,
      progressInPercent: progressInPercent ?? this.progressInPercent,
      errors: errors ?? this.errors,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

@riverpod
class ICalSyncStateNotifier extends _$ICalSyncStateNotifier {
  EnhancedICalSyncService? _syncService;
  
  @override
  Future<ICalSyncState> build() async {
    final syncState = ICalSyncState(syncProgress: ICalSyncProgressEnum.idle);
    return Future.value(syncState);
  }

  EnhancedICalSyncService _getSyncService() {
    _syncService ??= EnhancedICalSyncService(updateCalendarController: true);
    return _syncService!;
  }

  Future<void> sync([Calendar? calendar]) async {
    // Prevent multiple simultaneous syncs
    if (state.value?.syncProgress == ICalSyncProgressEnum.inProgress) {
      return;
    }

    try {
      state = AsyncValue.data(
        ICalSyncState(syncProgress: ICalSyncProgressEnum.inProgress),
      );

      final syncService = _getSyncService();

      if (calendar == null) {
        // Sync all calendars
        final result = await syncService.sync(
          onSyncProgress: (synced, total) {
            state = AsyncValue.data(
              ICalSyncState(
                syncProgress: ICalSyncProgressEnum.inProgress,
                progressInPercent: synced / total,
              ),
            );
          },
        );
        
        // Update final state based on result
        if (result.success) {
          state = AsyncValue.data(
            ICalSyncState(
              syncProgress: result.errors.isEmpty 
                  ? ICalSyncProgressEnum.done 
                  : ICalSyncProgressEnum.error,
              progressInPercent: 1,
              errors: result.errors,
            ),
          );
        } else {
          state = AsyncValue.data(
            ICalSyncState(
              syncProgress: ICalSyncProgressEnum.error,
              progressInPercent: 1,
              errors: result.errors,
              errorMessage: "Sync failed with ${result.failedCount} failures",
            ),
          );
        }
      } else {
        // Sync single calendar
        final result = await syncService.syncSingle(calendar);
        
        state = AsyncValue.data(
          ICalSyncState(
            syncProgress: result.success 
                ? ICalSyncProgressEnum.done 
                : ICalSyncProgressEnum.error,
            progressInPercent: 1,
            errorMessage: result.error,
          ),
        );
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
  
  /// Get real-time sync progress updates
  Stream<SyncProgress> getSyncProgressStream() {
    return _getSyncService().progressStream;
  }
  
  @override
  void dispose() {
    _syncService?.dispose();
    super.dispose();
  }
}
