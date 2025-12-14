import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/unit_service.dart';
import 'screens/home_screen.dart';
import 'widgets/overlay_window.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => UnitService(),
      child: const MyApp(),
    ),
  );
}

@pragma("vm:entry-point")
void overlayMain() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayWindow(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '润农扫码激活辅助',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF007AFF), // iOS System Blue
          background: const Color(0xFFF2F2F7), // iOS Grouped Background
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF2F2F7), // Transparent-like
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
          iconTheme: IconThemeData(color: Color(0xFF007AFF)),
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: EdgeInsets.zero,
        ),
        dialogTheme: DialogTheme(
          backgroundColor: Colors.white.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

