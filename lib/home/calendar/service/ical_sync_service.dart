import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:redcube_campus/home/calendar/calendar_body.dart';
import 'package:redcube_campus/home/calendar/models/calendar.dart';
import 'package:redcube_campus/home/calendar/parse_events.dart';
import 'package:redcube_campus/home/calendar/service/enhanced_ical_sync_service.dart';

/// Legacy ICalService - use EnhancedICalSyncService instead
@Deprecated('Use EnhancedICalSyncService for better reliability and error handling')
class ICalService {
  final httpClient = http.Client();
  final Isar _db;
  final Logger _log = Logger("IcalSyncService");
  final bool updateCalendarController;
  late final EnhancedICalSyncService _enhancedService;

  ICalService({this.updateCalendarController = false})
    : _db = Isar.getInstance()! {
    _enhancedService = EnhancedICalSyncService(
      updateCalendarController: updateCalendarController,
    );
  }

  static Future<Directory> getPath() async =>
      Directory("${(await getApplicationSupportDirectory()).path}/calendars");

  Future<bool> sync({
    void Function(int synced, int total)? onSyncProgress,
  }) async {
    final result = await _enhancedService.sync(onSyncProgress: onSyncProgress);
    return result.success;
  }

  Future<void> syncSingle(Calendar calendar) async {
    await _enhancedService.syncSingle(calendar);
  }

  void cleanupOldCalendars(Directory path, Iterable<Calendar> calendars) {
    _enhancedService.cleanupOldCalendars(path, calendars);
  }

  Future<List<Calendar>> getActiveCalendars() async => 
      _enhancedService.getActiveCalendars();
}
