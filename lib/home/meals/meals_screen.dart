import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:redcube_campus/home/meals/canteen_picker.dart';
import 'package:redcube_campus/home/meals/components/capacity_card.dart';
import 'package:redcube_campus/home/meals/components/day_picker.dart';
import 'package:redcube_campus/home/meals/meal_view.dart';
import 'package:redcube_campus/home/meals/models/day.dart';
import 'package:redcube_campus/home/meals/service/canteen_service.dart';
import 'package:redcube_campus/i18n/strings.g.dart';
import 'package:redcube_campus/settings/logs/logs_screen.dart';
import 'package:redcube_campus/settings/settings_screen.dart';
import 'package:redcube_campus/shared/extensions/extensions_date_time.dart';
import 'package:redcube_campus/shared/extensions/extensions_list.dart';

class MealsScreen extends ConsumerWidget {
  MealsScreen({super.key});

  final dayPickerController = SelectedDayController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(mealsProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.app_name),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              context.pushNamed(SettingsScreen.routeName);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [SizedBox.shrink(), CanteenPicker()],
          ),
          const SizedBox(height: 8),
          DayPicker(
            controller: dayPickerController,
            dates: meals?.map((day) => day.date).toList() ?? [],
          ),
          if (meals != null) const CapacityCard(),
          if (meals != null)
            Expanded(
              child: _MealsConsumerWrapper(controller: dayPickerController),
            ),
        ],
      ),
    );
  }
}

class _MealsConsumerWrapper extends ConsumerWidget {
  const _MealsConsumerWrapper({this.controller});

  final SelectedDayController? controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(mealsProvider);

    switch (meals) {
      case AsyncData(:final value):
        if (value == null)
          return _MealsError(
            message: t.mealplan.errors.unknown,
            showLogs: true,
          );
        if (value.isEmpty)
          return _MealsError(message: t.mealplan.errors.noMeals);
        return _MealsBody(mealDays: value, controller: controller);
      case _:
        // Loading
        return const SizedBox.shrink();
    }
  }
}

class _MealsBody extends StatefulWidget {
  _MealsBody({required this.mealDays, SelectedDayController? controller})
    : controller = controller ?? SelectedDayController();

  final List<MealDay> mealDays;
  final SelectedDayController controller;

  @override
  State<_MealsBody> createState() => _MealsBodyState();
}

class _MealsBodyState extends State<_MealsBody> {
  final pageController = PageController();

  // Prevents triggering the change while animating from external change
  bool changeBlocker = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(handleExternalDateChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(handleExternalDateChange);
    super.dispose();
  }

  void handleExternalDateChange() {
    final newDate = widget.controller.selectedDate;
    if (newDate != null) {
      final page = widget.mealDays.indexWhereOrNull(
        (meal) => meal.date.sameDayAs(newDate),
      );

      if (page != null) changeBlocker = true;
      pageController
          .animateToPage(
            page!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.ease,
          )
          .then((_) => changeBlocker = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: pageController,
      onPageChanged: (page) {
        if (!changeBlocker)
          widget.controller.selectDate(widget.mealDays[page].date);
      },
      children:
          widget.mealDays
              .map(
                (MealDay day) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TODO Auslastung
                    Expanded(child: MealView(day: day)),
                  ],
                ),
              )
              .toList(),
    );
  }
}

class _MealsError extends StatelessWidget {
  const _MealsError({required this.message, this.showLogs = false});

  final String message;
  final bool showLogs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLogs) Text(message),

          if (showLogs) SizedBox(height: 8),
          TextButton(
            onPressed: () {
              context.pushNamed(LogsScreen.routeName);
            },
            child: Text(t.mealplan.errors.goToLogs),
          ),
        ],
      ),
    );
  }
}
