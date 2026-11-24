import 'package:flutter_test/flutter_test.dart';
import 'package:sutoor/main.dart';

void main() {
  test('Book cover color uses a valid color from the API', () {
    expect(coverColor(<String, dynamic>{'color': '#176653'}).toARGB32(),
        0xFF176653);
  });

  test('Invalid cover colors use the Sutoor green', () {
    expect(coverColor(<String, dynamic>{'color': 'invalid'}).toARGB32(),
        green.toARGB32());
  });

  test('API helper supports missing fields and numeric IDs', () {
    expect(val(<String, dynamic>{}, 'title', 'غير متوفر'), 'غير متوفر');
    expect(numId(<String, dynamic>{'id': '27'}), 27);
  });
}
