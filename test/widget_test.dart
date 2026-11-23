import 'package:flutter_test/flutter_test.dart';
import 'package:sutoor/main.dart';
void main(){testWidgets('App bootstraps', (tester) async {
  await tester.pumpWidget(const SutoorApp());
  expect(find.byType(SutoorApp), findsOneWidget);
});}
