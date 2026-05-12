import 'package:flutter/material.dart';
import 'package:redcube_campus/i18n/strings.g.dart';
import 'package:redcube_campus/settings/settings_dropdown.dart';
import 'package:redcube_campus/settings/settings_screen.dart';
import 'package:redcube_campus/shared/components/dropdown_list_tile.dart';
import 'package:redcube_campus/shared/prefs.dart';

class GeneralSettingsSection extends StatelessWidget {
  const GeneralSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: SettingsScreen.initiallyExpanded,
      leading: const Icon(Icons.app_settings_alt_rounded),
      title: Text(t.settings.general.title),
      shape: Border.all(color: Colors.transparent),
      children: [
        SettingsDropdown(
          title: t.settings.general.initialLocation.title,
          pref: Prefs.initialLocation,
          options: [
            DropdownItem(t.settings.general.initialLocation.dashboard, "/"),
            DropdownItem(t.settings.general.initialLocation.calendar, "/calendar"),
            DropdownItem(t.settings.general.initialLocation.mealplan, "/meals"),
          ],
        ),
      ],
    );
  }
}
