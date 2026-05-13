import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:redcube_campus/home/calendar/models/calendar.dart';
import 'package:redcube_campus/home/calendar/service/ical_sync_service.dart';

final icalSyncStateNotifierProvider =
    NotifierProvider<ICalSyncStateNotifier, ICalSyncState>(
      ICalSyncStateNotifier.new,
    );

enum ICalSyncProgressEnum { idle, inProgress, done }

class ICalSyncState {
  final ICalSyncProgressEnum syncProgress;
  final double progressInPercent;

  ICalSyncState({required this.syncProgress, this.progressInPercent = 0});
}

class ICalSyncStateNotifier extends Notifier<ICalSyncState> {
  @override
  ICalSyncState build() {
    final syncState = ICalSyncState(syncProgress: ICalSyncProgressEnum.idle);
    return syncState;
  }

  // TODO queue

  Future<void> sync([Calendar? calendar]) async {
    // Prevent multiple simultaneous syncs
    if (state.syncProgress == ICalSyncProgressEnum.inProgress) {
      return;
    }
    state = ICalSyncState(syncProgress: ICalSyncProgressEnum.inProgress);

    final icalSyncService = ICalService(updateCalendarController: true);

    if (calendar == null) {
      await icalSyncService.sync(
        onSyncProgress: (synced, total) {
          state = ICalSyncState(
            syncProgress: ICalSyncProgressEnum.inProgress,
            progressInPercent: synced / total,
          );
        },
      );
    } else {
      await icalSyncService.syncSingle(calendar);
    }
    state = ICalSyncState(
      syncProgress: ICalSyncProgressEnum.done,
      progressInPercent: 1,
    );
  }
}
