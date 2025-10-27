import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar_community/isar.dart';
import 'package:redcube_campus/i18n/strings.g.dart';
import 'package:redcube_campus/shared/extensions/extensions_context.dart';
import 'package:redcube_campus/shared/logger/log_entry.dart';

class LogDetailsScreen extends StatelessWidget {
  LogDetailsScreen({super.key, required String? id})
    : assert(id != null),
      assert(int.tryParse(id!) != null),
      entryId = int.parse(id!);

  final int entryId;

  static const routeName = "logs.details";

  @override
  Widget build(BuildContext context) {
    final entry = Isar.getInstance()!.logEntries.getSync(entryId);
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text("NO LOGS")),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(t.settings.advanced.logs.details.title)),
      body: ListView(
        children: [
          _CardWithTitle(
            title: t.settings.advanced.logs.details.message,
            showCopyIcon: true,
            text: entry.message,
          ),
          if (entry.context1 != null)
            _CardWithTitle(
              title: t.settings.advanced.logs.details.context1,
              showCopyIcon: false,
              text: entry.context1!,
            ),
          if (entry.context2 != null)
            _CardWithTitle(
              title: t.settings.advanced.logs.details.context2,
              showCopyIcon: true,
              text: entry.context2!,
            ),
        ],
      ),
    );
  }
}

class _CardWithTitle extends StatelessWidget {
  const _CardWithTitle({
    required this.title,
    required this.showCopyIcon,
    required this.text,
  });

  final String title;
  final bool showCopyIcon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title.toUpperCase(),
                  style: context.theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.theme.colorScheme.primary,
                  ),
                ),
                if (showCopyIcon)
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: text)).then((_) {
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                t
                                    .settings
                                    .advanced
                                    .logs
                                    .details
                                    .copiedToClipboard,
                              ),
                            ),
                          );
                      });
                    },
                    icon: Icon(
                      Icons.copy,
                      size: 16.0,
                      color: context.theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: context.theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16.0),
            ),
            // color: context.theme.cardColor,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SelectableText(
                text,
                style: TextStyle(
                  color: context.theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.0,
                  fontFamily: "Inconsolata",
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
