import 'package:flutter/painting.dart';
import 'package:isar_community/isar.dart';

part 'calendar.g.dart';

@collection
class Calendar {
  String id;

  Id get isarId => fastHash(id);
  bool isActive;
  int numOfFails;
  DateTime? lastUpdate;
  String name;
  String url;
  int? colorValue;

  Calendar({
    required this.id,
    required this.isActive,
    required this.numOfFails,
    required this.name,
    required this.url,
    Color? color,
  }) : colorValue = color?.toARGB32();

  @ignore
  Color? get color => colorValue == null ? null : Color(colorValue!);

  set color(Color? color) => colorValue = color?.toARGB32();

  @override
  String toString() =>
      "Calendar(id: $id, isActive: $isActive, numOfFails: $numOfFails, lastUpdate: $lastUpdate, name: $name, url: $url)";
}

/// FNV-1a 64bit Hash-Algorithmus optimiert für Dart-Strings
/// https://isar.dev/de/recipes/string_ids.html
int fastHash(String string) {
  var hash = 0xcbf29ce484222325;

  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }

  return hash;
}
