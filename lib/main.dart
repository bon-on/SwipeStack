import 'package:flutter/material.dart';

import 'src/ads/ad_service.dart';
import 'src/app/swipe_stack_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdService.instance.initialize();
  runApp(const SwipeStackApp(enableAds: true));
}
