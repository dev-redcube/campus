import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:icalendar/icalendar.dart';
import 'package:kalender/kalender.dart';
import 'package:logging/logging.dart';
import 'package:redcube_campus/home/calendar/calendar_service.dart';
import 'package:redcube_campus/home/calendar/models/calendar.dart';
import 'package:redcube_campus/home/calendar/service/enhanced_ical_sync_service.dart';
import 'package:redcube_campus/shared/models/event_data.dart';
import 'package:rrule/rrule.dart' as rrule;

Future<List<CustomCalendarEvent>> parseAllEvents() async {
  final activeCalendars = await EnhancedICalSyncService().getActiveCalendars();
  final path = await EnhancedICalSyncService.getPath();

  final List<CustomCalendarEvent> events = [];

  for (final calendar in activeCalendars) {
    final file = File("${path.path}/${calendar.id}.ics");
    // TODO fetch
    if (!await file.exists()) continue;

    events.addAll(await parseICal(file, calendar));
  }

  return events;
}

Future<Iterable<CustomCalendarEvent>> parseEvents(Calendar calendar) async {
  final path = await EnhancedICalSyncService.getPath();
  final file = File("${path.path}/${calendar.id}.ics");
  if (!await file.exists()) return Future.value([]);

  return parseICal(file, calendar);
}

Future<Iterable<CustomCalendarEvent>> parseICal(
  File file,
  Calendar calendar,
) async {
  return await compute((_) => _parseICal(file, calendar), null);
}

Future<Iterable<CustomCalendarEvent>> _parseICal(
  File file,
  Calendar calendar,
) async {
  final lines = await file.readAsLines();

  final stopwatch = Stopwatch()..start();
  late final List<ICalendar> ical;
  try {
    ical = ICalendar.fromICalendarLines(lines);
  } catch (e, stacktrace) {
    Logger(
      "Calendar",
    ).severe("Failed to parse Calendar $calendar", e, stacktrace);
    return Future.value([]);
  }

  final List<CustomCalendarEvent> events = [];

  // VCALENDAR
  for (final cal in ical) {
    // VEVENT
    for (final component in cal.components) {
      if (component is EventComponent) {
        // start and either end or duration must be specified
        if (component.dateTimeStart == null) continue;
        if (component.end == null && component.duration == null) continue;

        final event = CalendarEvent(
          dateTimeRange: DateTimeRange(
            start: component.dateTimeStart!.value.value,
            end:
                component.end?.value.value ??
                component.dateTimeStart!.value.value.add(
                  component.duration!.value.value,
                ),
          ),
          eventData: EventData(
            calendarId: calendar.id,
            component: component,
            color: calendar.color,
          ),
          modifiable: false,
        );
        events.add(event);
      }
    }
  }
  stopwatch.stop();
  Logger(
    "IcalParser",
  ).info("$calendar parsed in ${stopwatch.elapsed.inSeconds} seconds");
  return splitEvents(events);
}

List<CustomCalendarEvent> splitEvents(List<CustomCalendarEvent> events) {
  final List<CustomCalendarEvent> splitEvents = [];
  for (final event in events) {
    // add original event
    splitEvents.add(event);

    final data = event.eventData!.component;

    // RecurrenceDateTimes, "skip" if none
    if (data.recurrenceDateTimes != null) {
      splitEvents.addAll(_splitRecurrenceDates(event));
    }

    // RRULE
    if (data.recurrenceRules != null) {
      splitEvents.addAll(splitRRule(event));
    }
  }
  return splitEvents;
}

List<CustomCalendarEvent> _splitRecurrenceDates(CustomCalendarEvent event) {
  final List<CustomCalendarEvent> splitEvents = [];
  for (final time in event.eventData!.component.recurrenceDateTimes!) {
    for (final t in time.value.values) {
      final start = t.value.copyWith(
        hour: event.dateTimeRange.start.hour,
        minute: event.dateTimeRange.start.minute,
      );
      splitEvents.add(
        CalendarEvent(
          dateTimeRange: DateTimeRange(
            start: start,
            end: start.add(event.duration),
          ),
          eventData: event.eventData,
          modifiable: false,
        ),
      );
    }
  }
  return splitEvents;
}

List<CustomCalendarEvent> splitRRule(CustomCalendarEvent event) {
  final List<CustomCalendarEvent> splitEvents = [];
  final data = event.eventData!.component;
  for (final rule in data.recurrenceRules!) {
    final recur = rrule.RecurrenceRule.fromString(rule.toString());
    final instances = recur.getInstances(
      start: DateTime.now()
          .subtract(const Duration(days: 60))
          .copyWith(isUtc: true),
    );

    // year before and after today
    final ranged = instances.takeWhile((value) {
      final diff = value.difference(DateTime.now()).inDays;
      return diff >= -61 && diff <= 6 * 30;
    });

    for (final instance in ranged) {
      splitEvents.add(
        CalendarEvent(
          dateTimeRange: DateTimeRange(
            start: instance,
            end: instance.add(event.duration),
          ),
          eventData: event.eventData,
          modifiable: false,
        ),
      );
    }
  }

  return splitEvents;
}
