import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sutoor/api.dart';
import 'package:sutoor/main.dart';

void main() {
  test('Site brand colors and cover helpers', () {
    expect(coverColor({'color':'#176653'}).toARGB32(), 0xFF176653);
    expect(coverColor({'color':'invalid'}).toARGB32(), green.toARGB32());
    expect(numId({'id':'27'}), 27);
    expect(val({}, 'title', 'غير متوفر'), 'غير متوفر');
    expect(truth(1), true);
    expect(truth('0'), false);
  });
  test('Books are mapped from the same website API', () async {
    final api=SutoorApi(client:MockClient((request) async {
      expect(request.url.path, '/api/v1/books');
      return http.Response(jsonEncode({'data':[{'id':5,'title':'كتاب حقيقي'}]}),200);
    }));
    final books=await api.list('/books');
    expect(books.first['title'], 'كتاب حقيقي');
    api.dispose();
  });
  test('Registration posts the entered customer data to PHP backend', () async {
    final api=SutoorApi(client:MockClient((request) async {
      expect(request.method,'POST');
      expect(request.url.path,'/api/v1/auth/register');
      final body=jsonDecode(request.body) as Map<String,dynamic>;
      expect(body['name'],'قارئ سطور');
      expect(body['email'],'reader@example.com');
      expect(body['password'],'0123456789');
      return http.Response('{"ok":true}',201);
    }));
    await api.register('قارئ سطور','reader@example.com','0123456789');
    api.dispose();
  });
  test('API validates structured error responses', () async {
    final api=SutoorApi(client:MockClient((_)async=>http.Response(
      '{"error":"email_unavailable"}',409)));
    await expectLater(api.register('س','taken@example.com','0123456789'),
      throwsA(isA<ApiException>()));
    api.dispose();
  });
}
