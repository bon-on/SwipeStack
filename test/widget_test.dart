import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_stack/src/app/swipe_stack_app.dart';
import 'package:swipe_stack/src/game/how_to_play.dart';

class _SeenStore extends HowToPlayStore {
  const _SeenStore();
  @override
  Future<bool> loadSeen() async => true;
  @override
  Future<void> markSeen() async {}
}

void main() {
  testWidgets('SwipeStack loads stacking HUD', (WidgetTester tester) async {
    await tester.pumpWidget(const SwipeStackApp(howToPlayStore: _SeenStore()));
    await tester.pump();

    expect(find.text('SwipeStack'), findsOneWidget);
    expect(find.text('Swipe to line up'), findsOneWidget);
    expect(
      find.text(
        'Tap or swipe to drop. Drags only trim the glide. Perfect drops keep your width.',
      ),
      findsOneWidget,
    );
    expect(find.text('Stack'), findsOneWidget);
    expect(find.text('Best'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
  });
}
