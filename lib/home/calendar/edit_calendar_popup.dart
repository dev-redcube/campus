import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:redcube_campus/home/calendar/add/add_new_calendar.dart';
import 'package:redcube_campus/home/calendar/models/calendar.dart';
import 'package:redcube_campus/home/calendar/service/ical_sync_service.dart';
import 'package:redcube_campus/i18n/strings.g.dart';
import 'package:redcube_campus/shared/prefs.dart';

class EditCalendarPopup extends StatefulWidget {
  const EditCalendarPopup({super.key, required this.calendar});

  final Calendar calendar;

  @override
  State<EditCalendarPopup> createState() => _EditCalendarPopupState();
}

class _EditCalendarPopupState extends State<EditCalendarPopup> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController nameController;
  late final TextEditingController urlController;
  late Color? color;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.calendar.name);
    urlController = TextEditingController(text: widget.calendar.url);
    color = widget.calendar.color;
  }

  @override
  void dispose() {
    nameController.dispose();
    urlController.dispose();
    formKey.currentState?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Edit Calendar"),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InputContainer(
              child: TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Name",
                  border: InputBorder.none,
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return t.calendar.edit.add.errors.emptyName;
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 8),
            InputContainer(
              child: TextFormField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: "URL",
                  border: InputBorder.none,
                ),
                validator: (value) {
                  if (Uri.tryParse(value ?? "")?.hasAbsolutePath ?? false) {
                    return null;
                  }
                  return t.calendar.edit.add.errors.invalidUrl;
                },
              ),
            ),
            const SizedBox(height: 8),
            CalendarColorPicker(
              color: color,
              onColorChanged: (newColor) {
                setState(() {
                  color = newColor;
                });
              },
            ),
            if (Prefs.devMode.value) const SizedBox(height: 8),
            if (Prefs.devMode.value)
              Text(
                "Id: ${widget.calendar.id}\nLast sync: ${widget.calendar.lastUpdate}\nNumOfFails: ${widget.calendar.numOfFails}",
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;

            final db = Isar.getInstance();
            await db?.writeTxn(() async {
              widget.calendar.name = nameController.text;
              widget.calendar.url = urlController.text;
              widget.calendar.color = color;
              db.calendars.put(widget.calendar);
            });
            final icalService = ICalService(updateCalendarController: true);
            icalService.syncSingle(widget.calendar);
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
    );
  }
}
