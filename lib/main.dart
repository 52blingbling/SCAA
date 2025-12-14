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
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

