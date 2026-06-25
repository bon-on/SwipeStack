import 'package:flutter/material.dart';

import '../game/swipe_stack_screen.dart';

class SwipeStackApp extends StatelessWidget {
  const SwipeStackApp({super.key, this.enableAds = false});

  final bool enableAds;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwipeStack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB25B),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1622),
      ),
      home: SwipeStackScreen(enableAds: enableAds),
    );
  }
}
