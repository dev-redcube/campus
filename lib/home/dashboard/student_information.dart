import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:redcube_campus/home/dashboard/dashboard_card.dart';

class TopInformation extends StatelessWidget {
  const TopInformation({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // StudentInformation(),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              WebOpenCard(
                label: "Moodle",
                icon: Icons.school_rounded,
                url: "https://moodle.hm.edu",
              ),
              WebOpenCard(
                label: "ZPA",
                icon: Icons.language_rounded,
                url: "https://zpa.cs.hm.edu",
              ),
              WebOpenCard(
                label: "NINE",
                icon: Icons.language_rounded,
                url: "https://nine.hm.edu",
              ),
              WebOpenCard(
                label: "Primuss",
                icon: Icons.language_rounded,
                url: "https://www3.primuss.de/cgi-bin/login/index.pl?FH=fhm",
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class WebOpenCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String url;

  const WebOpenCard({
    super.key,
    required this.label,
    required this.icon,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      usePrimaryColor: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[Icon(icon), const SizedBox(width: 12), Text(label)],
      ),
      onTap: () {
        ChromeSafariBrowser().open(url: WebUri(url));
      },
    );
  }
}

class StudentInformation extends StatelessWidget {
  const StudentInformation({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardCard(
      usePrimaryColor: true,
      child: Row(
        children: [
          CircleAvatar(radius: 30, child: Icon(Icons.person_rounded)),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [Text("Max Mustermann"), Text("Wirtschaftsinformatik")],
          ),
        ],
      ),
    );
  }
}
