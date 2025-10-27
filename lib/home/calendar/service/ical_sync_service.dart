import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:isar_community/isar.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:redcube_campus/home/calendar/calendar_body.dart';
import 'package:redcube_campus/home/calendar/models/calendar.dart';
import 'package:redcube_campus/home/calendar/parse_events.dart';

class ICalService {
  final httpClient = http.Client();
  final Isar _db;
  final Logger _log = Logger("IcalSyncService");
  final bool updateCalendarController;

  ICalService({this.updateCalendarController = false})
    : _db = Isar.getInstance()!;

  static Future<Directory> getPath() async =>
      Directory("${(await getApplicationSupportDirectory()).path}/calendars");

  Future<bool> sync({
    void Function(int synced, int total)? onSyncProgress,
  }) async {
    final activeCalendars =
        await _db.calendars.filter().isActiveEqualTo(true).findAll();
    final path = await getPath();

    if (!await path.exists()) {
      await path.create();
    }

    int synced = 0;

    _log.info("Syncing ${activeCalendars.length} calendars");

    for (final calendar in activeCalendars) {
      await syncSingle(calendar);

      synced++;
      onSyncProgress?.call(synced, activeCalendars.length);
    }
    return true;
  }

  Future<void> syncSingle(Calendar calendar) async {
    final path = await getPath();
    if (!await path.exists()) await path.create();
    final file = File("${path.path}/${calendar.id}.ics");
    _log.info("Downloading calendar ${calendar.name}");
    try {
      final response = await httpClient.get(Uri.parse(calendar.url));

      if (200 != response.statusCode) {
        _log.warning(
          "Failed to download calendar ${calendar.name} with status code ${response.statusCode}",
          response.body,
        );
        await _db.writeTxn(() async {
          calendar.numOfFails++;
          await _db.calendars.put(calendar);
        });
        return;
      }

      await file.writeAsBytes(response.bodyBytes);
      _log.info("Saved calendar ${calendar.name} to ${file.path}");

      // Update calendar
      if (updateCalendarController) {
        eventsController.removeWhere(
          (element) => element.eventData?.calendarId == calendar.id,
        );

        final events = await parseEvents(calendar);
        eventsController.addEvents(events.toList());
      }

      await _db.writeTxn(() async {
        calendar.lastUpdate = DateTime.now();
        calendar.numOfFails = 0;
        await _db.calendars.put(calendar);
      });
    } catch (e) {
      _log.warning("Failed to download calendar ${calendar.name}", e);
      if (updateCalendarController) {
        eventsController.removeWhere(
          (element) => element.eventData?.calendarId == calendar.id,
        );
      }
      await _db.writeTxn(() async {
        calendar.numOfFails++;
        await _db.calendars.put(calendar);
      });
    }
  }

  void cleanupOldCalendars(Directory path, Iterable<Calendar> calendars) {
    path.list().forEach((element) {
      final filename = element.path.split(Platform.pathSeparator).last;
      final calendarId = filename.split(".").first;

      if (!calendars.any((element) => element.id == calendarId)) {
        element.delete();
      }
    });
  }

  Future<List<Calendar>> getActiveCalendars() async =>
      _db.calendars.filter().isActiveEqualTo(true).findAll();
}
