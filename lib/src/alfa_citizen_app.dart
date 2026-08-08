import 'package:flutter/material.dart';

import 'screens/auth_gate.dart';

class AlfaCitizenApp extends StatelessWidget {
  const AlfaCitizenApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF176B52);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Alpha Community',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F1E8),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFFF5F1E8),
          foregroundColor: Color(0xFF10291F),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        cardTheme: const CardThemeData(
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}
