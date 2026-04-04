import 'package:flutter/material.dart';
import 'package:flutter_travel_agency/screens/home_page.dart';
import 'package:flutter_travel_agency/widgets/chat_overlay_shell.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Travelista Adventures',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
          primary: const Color(0xFF1E3A5F),
          secondary: const Color(0xFF2563EB),
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => ChatOverlayShell(child: child ?? const SizedBox.shrink()),
            ),
          ],
        );
      },
      home: const TravelHomePage(),
    );
  }
}
