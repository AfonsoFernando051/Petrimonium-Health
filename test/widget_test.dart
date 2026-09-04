import 'package:flutter_test/flutter_test.dart';

import 'package:petrimonium_health/main.dart';

void main() {
  testWidgets('App boots without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const PetrimoniumHealthApp());
    await tester.pump();
  });
}
