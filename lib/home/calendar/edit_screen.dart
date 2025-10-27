import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:redcube_campus/home/calendar/add/add_screen.dart';
import 'package:redcube_campus/home/calendar/calendar_body.dart';
import 'package:redcube_campus/home/calendar/calendar_screen.dart';
import 'package:redcube_campus/home/calendar/edit_calendar_popup.dart';
import 'package:redcube_campus/home/calendar/ical_sync_state.dart';
import 'package:redcube_campus/home/calendar/models/calendar.dart';
import 'package:redcube_campus/home/calendar/parse_events.dart';
import 'package:redcube_campus/i18n/strings.g.dart';
import 'package:redcube_campus/shared/extensions/extensions_context.dart';
import 'package:redcube_campus/shared/extensions/extensions_date_time.dart';

class CalendarEditScreen extends ConsumerWidget {
  CalendarEditScreen({super.key});

  static const routeName = "calendar.edit";

  final Isar _db = Isar.getInstance()!;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.calendar.edit.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: t.calendar.edit.refresh.tooltip,
            onPressed: () {
              ref.read(iCalSyncStateNotifierProvider.notifier).sync();
            },
          ),
        ],
      ),
      // Listen to any changes in the Calendars storage
      body: Stack(
        children: [
          StreamBuilder(
            stream: _db.calendars.watchLazy(),
            builder: (context, snapshot) {
              // When changes occur, fire a FutureBuilder to rebuild the UI
              return FutureBuilder<List<Calendar>>(
                future: _db.calendars.where().findAll(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }

                  final calendars = snapshot.data!;

                  return _CalendarEditScreenBody(calendars);
                },
              );
            },
          ),
          const SyncProgress(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.pushNamed(AddCalendarScreen.routeName);
        },
        label: Text(t.calendar.add),
        icon: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _CalendarEditScreenBody extends StatelessWidget {
  const _CalendarEditScreenBody(this.calendars);

  final List<Calendar> calendars;

  @override
  Widget build(BuildContext context) {
    if (calendars.isNotEmpty) {
      return ListView.builder(
        itemCount: calendars.length,
        itemBuilder: (context, index) {
          final item = calendars[index];
          return _CalendarRow(
            key: ValueKey("calendar-${item.id}"),
            calendar: item,
          );
        },
      );
    }
    return Center(child: Text(t.calendar.edit.noCalendars));
  }
}

class _CalendarRow extends ConsumerWidget {
  _CalendarRow({super.key, required this.calendar});

  final Calendar calendar;

  final Isar _db = Isar.getInstance()!;

  Future<void> toggle(bool? state, WidgetRef ref) async {
    await _db.writeTxn(() async {
      calendar.isActive = state!;
      await _db.calendars.put(calendar);
    });

    if (state!) {
      final events = await parseEvents(calendar);
      eventsController.addEvents(events.toList());
    } else {
      eventsController.removeWhere(
        (element) => element.eventData?.calendarId == calendar.id,
      );
    }
  }

  Future<void> delete() async {
    await _db.writeTxn(() async {
      await _db.calendars.delete(calendar.isarId);
    });
    eventsController.removeWhere(
      (element) => element.eventData?.calendarId == calendar.id,
    );
  }

  void _warningPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(t.calendar.edit.warning.title),
          content: Text(
            t.calendar.edit.warning.message(
              numOfFails: calendar.numOfFails,
              lastSync: calendar.lastUpdate?.formatdMonth ?? "Never",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.calendar.edit.warning.close),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: context.theme.colorScheme.surfaceContainer,
      elevation: 0,
      child: ListTile(
        leading: Checkbox.adaptive(
          value: calendar.isActive,
          onChanged: (state) => toggle(state, ref),
        ),
        title: Text(calendar.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (calendar.numOfFails != 0)
              IconButton(
                icon: const Icon(Icons.warning_rounded, color: Colors.orange),
                onPressed: () => _warningPopup(context),
              ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: delete,
            ),
          ],
        ),
        onLongPress: () {
          // open popup to edit calendar
          showDialog(
            context: context,
            builder: (context) => EditCalendarPopup(calendar: calendar),
          );
        },
      ),
    );
  }
}
