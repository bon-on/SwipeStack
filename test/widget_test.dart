import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_stack/src/app/swipe_stack_app.dart';

void main() {
  testWidgets('SwipeStack loads stacking HUD', (WidgetTester tester) async {
    await tester.pumpWidget(const SwipeStackApp());
    await tester.pump();

    expect(find.text('SwipeStack'), findsOneWidget);
    expect(find.text('Swipe to line up'), findsOneWidget);
    expect(
      find.text(
        'Drag to correct the glide, release to drop. Only the overlap survives.',
      ),
      findsOneWidget,
    );
    expect(find.text('Stack'), findsOneWidget);
    expect(find.text('Best'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
  });
}
