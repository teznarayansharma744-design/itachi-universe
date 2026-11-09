import 'package:flutter/material.dart';

import 'screens/welcome_screen.dart';
import 'theme.dart';

void main() => runApp(const ItachiApp());

class ItachiApp extends StatelessWidget {
  const ItachiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (_, mode, __) => MaterialApp(
        title: 'Itachi Universe',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const WelcomeScreen(),
      ),
    );
  }
}
