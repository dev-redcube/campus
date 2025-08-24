import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:redcube_campus/home/calendar/calendar_body.dart';
import 'package:redcube_campus/home/calendar/edit_screen.dart';
import 'package:redcube_campus/home/calendar/ical_sync_state.dart';
import 'package:redcube_campus/i18n/strings.g.dart';
import 'package:redcube_campus/shared/extensions/extensions_context.dart';
import 'package:redcube_campus/shared/prefs.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.app_name),
        backgroundColor: context.theme.colorScheme.secondaryContainer.withAlpha(
          100,
        ),
        scrolledUnderElevation: 0.0,
        actions: [
          IconButton(
            onPressed: () {
              Prefs.calendarViewConfiguration.value =
                  (Prefs.calendarViewConfiguration.value + 1) %
                  calendarViewConfigurations.length;
            },
            icon: const _CalendarViewConfigurationIcon(),
          ),
          IconButton(
            icon: const Icon(Icons.today_rounded),
            onPressed: () {
              calendarController.animateToDate(DateTime.now());
            },
            tooltip: t.calendar.today,
          ),
          IconButton(
            icon: const Icon(Icons.edit_calendar_rounded),
            onPressed: () {
              context.pushNamed(CalendarEditScreen.routeName);
            },
            tooltip: t.calendar.edit.tooltip,
          ),
        ],
      ),
      body: const Stack(
        alignment: Alignment.topCenter,
        children: [CalendarBody(), SyncProgress()],
      ),
    );
  }
}

class _CalendarViewConfigurationIcon extends StatefulWidget {
  const _CalendarViewConfigurationIcon();

  @override
  State<_CalendarViewConfigurationIcon> createState() =>
      _CalendarViewConfigurationIconState();
}

class _CalendarViewConfigurationIconState
    extends State<_CalendarViewConfigurationIcon> {
  @override
  initState() {
    super.initState();
    Prefs.calendarViewConfiguration.addListener(_rebuild);
  }

  _rebuild() {
    setState(() {});
  }

  @override
  void dispose() {
    Prefs.calendarViewConfiguration.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (Prefs
      .calendarViewConfiguration
      .value) {
    0 => const Icon(Icons.calendar_view_day_rounded),
    1 => const Icon(Icons.calendar_view_week_rounded),
    2 => const Icon(Icons.calendar_view_month_rounded),
    // Never happening
    _ => const Icon(Icons.error_rounded),
  };
}

class SyncProgress extends ConsumerWidget {
  const SyncProgress({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(iCalSyncStateNotifierProvider).value;
    
    if (value?.syncProgress != ICalSyncProgressEnum.inProgress) {
      // Show error state briefly if there are errors
      if (value?.hasErrors == true && value?.syncProgress == ICalSyncProgressEnum.error) {
        return Container(
          height: 4,
          child: LinearProgressIndicator(
            value: 1.0,
            backgroundColor: Colors.red.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
          ),
        );
      }
      return const SizedBox.shrink();
    }
    
    return Container(
      height: 4,
      child: LinearProgressIndicator(
        value: value?.progressInPercent,
        backgroundColor: Colors.blue.withOpacity(0.3),
        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
      ),
    );
  }
}
