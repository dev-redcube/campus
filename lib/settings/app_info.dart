import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:redcube_campus/i18n/strings.g.dart';
import 'package:url_launcher/url_launcher.dart';

class AppInfo extends StatelessWidget {
  const AppInfo({super.key});

  static final Uri privacyPolicy = Uri.parse(
    "https://github.com/dev-redcube/betterHM/blob/master/PRIVACY.md",
  );

  void _showAboutDialog(
    BuildContext context,
    PackageInfo info,
    String versionText,
  ) => showAboutDialog(
    context: context,
    applicationVersion: versionText,
    applicationLegalese: t.app_info.licenseNotice(buildYear: "2026"),
    children: [
      const SizedBox(height: 10),
      TextButton(
        onPressed: () => launchUrl(privacyPolicy),
        child: SizedBox(
          width: double.infinity,
          child: Text(t.app_info.privacyPolicy),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final PackageInfo? info = snapshot.data;
        String text;
        if (!snapshot.hasData) {
          text = "loading version info";
        } else {
          text = "v${info!.version} (${info.buildNumber})";
        }
        return TextButton(
          child: Text(text),
          onPressed: () {
            _showAboutDialog(context, info!, text);
          },
        );
      },
    );
  }
}
