import 'package:flutter/material.dart';

/// Sample video used until the backend serves real lectures.
const sampleVideoUrl =
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

enum UnitStatus { done, inProgress, todo }

class UnitItem {
  final String title;
  final int videos;
  final int pdfs;
  final UnitStatus status;

  /// Free units are playable in Demo Mode. The Telegram bot will toggle this later.
  final bool free;
  const UnitItem(this.title, this.videos, this.pdfs, this.status, {this.free = false});
}

class Subject {
  final String name;
  final IconData icon;
  final Color tint;
  final List<UnitItem> units;
  const Subject(this.name, this.icon, this.tint, this.units);

  int get lectures => units.fold(0, (sum, u) => sum + u.videos);
}

class Batch {
  final String name;
  final IconData icon;
  final Color tint;
  final List<Subject> subjects;
  const Batch(this.name, this.icon, this.tint, this.subjects);

  int get lectures => subjects.fold(0, (sum, s) => sum + s.lectures);
}

// Sample content. The Telegram bot will replace this with real data.
const sampleBatches = <Batch>[
  Batch('Class 12 Science', Icons.menu_book_rounded, Color(0xFF5B5BFF), [
    Subject('Physics', Icons.bolt_rounded, Color(0xFF5B5BFF), [
      UnitItem('Units and Measurement', 3, 2, UnitStatus.done, free: true),
      UnitItem('Laws of Motion', 4, 3, UnitStatus.inProgress),
      UnitItem('Work, Energy and Power', 3, 2, UnitStatus.todo),
      UnitItem('Rotational Motion', 3, 2, UnitStatus.todo),
    ]),
    Subject('Chemistry', Icons.science_rounded, Color(0xFF19C3B1), [
      UnitItem('Atomic Structure', 3, 2, UnitStatus.todo),
      UnitItem('Chemical Bonding', 4, 2, UnitStatus.todo),
      UnitItem('Thermodynamics', 3, 2, UnitStatus.todo),
    ]),
    Subject('Mathematics', Icons.calculate_rounded, Color(0xFFFF6AA2), [
      UnitItem('Relations and Functions', 2, 1, UnitStatus.todo),
      UnitItem('Calculus', 5, 3, UnitStatus.todo),
    ]),
    Subject('Biology', Icons.eco_rounded, Color(0xFFFFB84D), [
      UnitItem('The Living World', 3, 2, UnitStatus.todo),
      UnitItem('Genetics', 4, 3, UnitStatus.todo),
    ]),
  ]),
  Batch('Revision Crash Course', Icons.bolt_rounded, Color(0xFF19C3B1), [
    Subject('Physics Revision', Icons.bolt_rounded, Color(0xFF5B5BFF), [
      UnitItem('Mechanics in One Shot', 2, 1, UnitStatus.todo),
    ]),
    Subject('Chemistry Revision', Icons.science_rounded, Color(0xFF19C3B1), [
      UnitItem('Organic in One Shot', 2, 1, UnitStatus.todo),
    ]),
  ]),
];
