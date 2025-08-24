import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kalender/kalender.dart';
import 'package:redcube_campus/home/calendar/calendar_service.dart';
import 'package:redcube_campus/home/calendar/components/multi_day_tile.dart';
import 'package:redcube_campus/home/calendar/components/tile.dart';
import 'package:redcube_campus/shared/extensions/extensions_context.dart';
import 'package:redcube_campus/shared/models/event_data.dart';
import 'package:redcube_campus/shared/prefs.dart';

final calendarController = CalendarController<EventData>();
final eventsController = DefaultEventsController<EventData>();

class CalendarBody extends ConsumerStatefulWidget {
  const CalendarBody({super.key});

  @override
  ConsumerState<CalendarBody> createState() => _CalendarBodyState();
}

final List<ViewConfiguration> calendarViewConfigurations = [
  DayConfiguration(startHour: 5),
  WorkWeekConfiguration(startHour: 5),
  MonthConfiguration(),
];

class _CalendarBodyState extends ConsumerState<CalendarBody> {
  @override
  void initState() {
    super.initState();
    Prefs.calendarViewConfiguration.addListener(_setViewConfiguration);
  }

  late ViewConfiguration currentViewConfiguration =
      calendarViewConfigurations[Prefs.calendarViewConfiguration.value];

  _setViewConfiguration() {
    setState(() {
      currentViewConfiguration =
          calendarViewConfigurations[Prefs.calendarViewConfiguration.value];
    });
  }

  @override
  void dispose() {
    Prefs.calendarViewConfiguration.removeListener(_setViewConfiguration);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CalendarView(
      controller: calendarController,
      eventsController: eventsController,
      viewConfiguration: currentViewConfiguration,
      tileBuilder: _tileBuilder,
      multiDayTileBuilder: _multiDayTileBuilder,
      scheduleTileBuilder: _scheduleTileBuilder,
    );
  }

  Map<Color, double> luminances = {};

  (Color, Color) getColors(CustomCalendarEvent event, BuildContext context) {
    final color =
        event.eventData?.color ?? context.theme.colorScheme.primaryContainer;

    late final Color textColor;
    if (event.eventData?.color != null) {
      final color = event.eventData!.color!;
      double? luminance = luminances[color];

      if (luminance == null) {
        luminance = color.computeLuminance();
        luminances[color] = luminance;
      }

      textColor = luminance > 0.5 ? Colors.black : Colors.white;
    } else {
      textColor = context.theme.colorScheme.onPrimaryContainer;
    }
    return (color, textColor);
  }

  Widget _tileBuilder(
    CustomCalendarEvent event,
    TileConfiguration configuration,
  ) {
    final colors = getColors(event, context);
    return Tile(event: event, configuration: configuration, colors: colors);
  }

  Widget _multiDayTileBuilder(
    CustomCalendarEvent event,
    MultiDayTileConfiguration configuration,
  ) {
    final colors = getColors(event, context);
    return MultiDayTile(
      event: event,
      configuration: configuration,
      colors: colors,
    );
  }

  Widget _scheduleTileBuilder(CustomCalendarEvent event, DateTime date) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        event.eventData?.component.summary?.value.value ?? 'No title',
      ),
    );
  }
}
