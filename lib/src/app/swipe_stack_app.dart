import 'package:flutter/material.dart';

import '../game/how_to_play.dart';
import '../game/swipe_stack_screen.dart';

class SwipeStackApp extends StatelessWidget {
  const SwipeStackApp({
    super.key,
    this.enableAds = false,
    this.howToPlayStore = const HowToPlayStore(),
  });

  final bool enableAds;
  final HowToPlayStore howToPlayStore;

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
      home: SwipeStackScreen(
        enableAds: enableAds,
        howToPlayStore: howToPlayStore,
      ),
    );
  }
}
