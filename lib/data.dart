import 'package:flutter/material.dart';

/// Sample video used until the backend serves real lectures.
const sampleVideoUrl =
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

enum UnitStatus { done, inProgress, todo }

/// One lecture inside a unit. It can have a video, a PDF, or both.
/// A PDF-only item (notes, formula sheet) has hasVideo = false.
class Lecture {
  final String title;
  final bool hasVideo;
  final bool hasPdf;

  /// Free lectures play in Demo Mode. The Telegram bot will toggle this later.
  final bool free;
  const Lecture(this.title,
      {this.hasVideo = true, this.hasPdf = false, this.free = false});
}

class UnitItem {
  final String title;
  final UnitStatus status;
  final List<Lecture> lectures;
  const UnitItem(this.title, this.status, this.lectures);

  int get videos => lectures.where((l) => l.hasVideo).length;
  int get pdfs => lectures.where((l) => l.hasPdf).length;
  int get freeCount => lectures.where((l) => l.free).length;
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

/// Builds sample lectures: [videos] video lectures (the first [withPdf] also
/// have a PDF), the first [free] are free, plus [onlyPdf] PDF-only items.
List<Lecture> _make(int videos, {int withPdf = 0, int onlyPdf = 0, int free = 0}) {
  return [
    for (var i = 1; i <= videos; i++)
      Lecture('Lecture $i', hasVideo: true, hasPdf: i <= withPdf, free: i <= free),
    for (var i = 1; i <= onlyPdf; i++)
      Lecture(i == 1 ? 'Formula Sheet' : 'Practice Sheet $i',
          hasVideo: false, hasPdf: true),
  ];
}

// Sample content. The Telegram bot will replace this with real data.
final sampleBatches = <Batch>[
  Batch('Class 12 Science', Icons.menu_book_rounded, const Color(0xFF5B5BFF), [
    Subject('Physics', Icons.bolt_rounded, const Color(0xFF5B5BFF), [
      UnitItem('Units and Measurement', UnitStatus.done,
          _make(3, withPdf: 2, onlyPdf: 1, free: 1)),
      UnitItem('Laws of Motion', UnitStatus.inProgress,
          _make(4, withPdf: 3, onlyPdf: 2)),
      UnitItem('Work, Energy and Power', UnitStatus.todo,
          _make(3, withPdf: 2, onlyPdf: 1)),
      UnitItem('Rotational Motion', UnitStatus.todo, _make(3, withPdf: 2)),
    ]),
    Subject('Chemistry', Icons.science_rounded, const Color(0xFF19C3B1), [
      UnitItem('Atomic Structure', UnitStatus.todo, _make(3, withPdf: 2)),
      UnitItem('Chemical Bonding', UnitStatus.todo, _make(4, withPdf: 2)),
      UnitItem('Thermodynamics', UnitStatus.todo, _make(3, withPdf: 2)),
    ]),
    Subject('Mathematics', Icons.calculate_rounded, const Color(0xFFFF6AA2), [
      UnitItem('Relations and Functions', UnitStatus.todo, _make(2, withPdf: 1)),
      UnitItem('Calculus', UnitStatus.todo, _make(5, withPdf: 3, onlyPdf: 1)),
    ]),
    Subject('Biology', Icons.eco_rounded, const Color(0xFFFFB84D), [
      UnitItem('The Living World', UnitStatus.todo, _make(3, withPdf: 2)),
      UnitItem('Genetics', UnitStatus.todo, _make(4, withPdf: 3)),
    ]),
  ]),
  Batch('Revision Crash Course', Icons.bolt_rounded, const Color(0xFF19C3B1), [
    Subject('Physics Revision', Icons.bolt_rounded, const Color(0xFF5B5BFF), [
      UnitItem('Mechanics in One Shot', UnitStatus.todo, _make(2, withPdf: 1)),
    ]),
    Subject('Chemistry Revision', Icons.science_rounded, const Color(0xFF19C3B1), [
      UnitItem('Organic in One Shot', UnitStatus.todo, _make(2, withPdf: 1)),
    ]),
  ]),
];
