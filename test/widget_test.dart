import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sutoor/api.dart';
import 'package:sutoor/main.dart';

http.Response jsonResponse(Object payload, int status) => http.Response.bytes(
  utf8.encode(jsonEncode(payload)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('Site colors and book utilities match the website', () {
    expect(coverColor({'color': '#176653'}).toARGB32(), 0xFF176653);
    expect(coverColor({'color': 'invalid'}).toARGB32(), green.toARGB32());
    expect(numId({'id': '27'}), 27);
    expect(val({}, 'title', 'غير متوفر'), 'غير متوفر');
    expect(truth(1), true);
    expect(truth('0'), false);
  });

  test('Book API maps Unicode titles through a mocked HTTP response', () async {
    Uri? requestedUri;
    final api = SutoorApi(client: MockClient((request) async {
      requestedUri = request.url;
      return jsonResponse({'data': [{'id': 5, 'title': 'كتاب حقيقي'}]}, 200);
    }));
    try {
      final books = await api.list('/books');
      expect(requestedUri, isNotNull);
      expect(requestedUri!.path, '/api/v1/books');
      expect(books, hasLength(1));
      expect(books.single['id'], 5);
      expect(books.single['title'], 'كتاب حقيقي');
    } finally {
      api.dispose();
    }
  });

  test('Registration sends customer details to PHP API', () async {
    final api = SutoorApi(client: MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/auth/register');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['name'], 'قارئ سطور');
      expect(body['email'], 'reader@example.com');
      expect(body['password'], '0123456789');
      return jsonResponse({'ok': true}, 201);
    }));
    try {
      await api.register('قارئ سطور', 'reader@example.com', '0123456789');
    } finally {
      api.dispose();
    }
  });

  test('Email collision is reported as an API error', () async {
    final api = SutoorApi(client: MockClient(
      (_) async => jsonResponse({'error': 'email_unavailable'}, 409),
    ));
    try {
      await expectLater(api.register('قارئ', 'taken@example.com', '0123456789'),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)));
    } finally {
      api.dispose();
    }
  });

  test('Invalid book-list JSON reports a data error', () async {
    final api = SutoorApi(client: MockClient(
      (_) async => jsonResponse({'data': {'bad': 'shape'}}, 200),
    ));
    try {
      await expectLater(api.list('/books'), throwsA(isA<ApiException>()));
    } finally {
      api.dispose();
    }
  });

  test('Protected book content requires authentication', () async {
    final api = SutoorApi(client: MockClient(
      (_) async => throw StateError('Unauthenticated request must not be sent'),
    ));
    try {
      await expectLater(api.bookPdf(5),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));
    } finally {
      api.dispose();
    }
  });
}
