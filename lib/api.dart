import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, [this.statusCode = 0]);
  final String message;
  final int statusCode;
  @override
  String toString() => message;
}

class SutoorApi {
  SutoorApi({http.Client? client}) : _client = client ?? http.Client();
  static const baseUrl = String.fromEnvironment('SUTOOR_API_URL',
      defaultValue: 'https://sutoor.it.com/api/v1');
  final http.Client _client;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _token;

  Future<void> restore() async { _token = await _storage.read(key: 'auth_token'); }
  bool get loggedIn => _token != null && _token!.isNotEmpty;

  Future<Map<String, dynamic>> request(String path,
      {String method = 'GET', Map<String, dynamic>? body, bool auth = false}) async {
    if (auth && !loggedIn) throw const ApiException('يجب تسجيل الدخول أولاً', 401);
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Accept': 'application/json',
      'Content-Type': 'application/json'};
    if (auth && _token != null) headers['Authorization'] = 'Bearer $_token';
    late http.Response r;
    try {
      r = await _client.send(http.Request(method, uri)
        ..headers.addAll(headers)
        ..body = body == null ? '' : jsonEncode(body)).then(http.Response.fromStream)
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const ApiException('تعذر الاتصال بالخادم. تحقق من الإنترنت أو الموقع.');
    }
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(r.body);
      json = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      throw ApiException('الخادم لم يرجع استجابة JSON سليمة', r.statusCode);
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      const messages = {
        'invalid_credentials': 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
        'unauthorized': 'انتهت الجلسة. سجل الدخول من جديد',
        'invalid_registration': 'تأكد من الاسم والبريد وكلمة مرور من 10 أحرف على الأقل',
        'email_unavailable': 'هذا البريد مستخدم بالفعل',
        'service_unavailable': 'خدمة قاعدة البيانات غير متاحة حالياً',
        'invalid_plan_or_payment_method': 'الباقة أو طريقة الدفع غير متاحة',
        'whatsapp_unavailable': 'طلب واتساب غير متاح حالياً',
      };
      final key = json['error']?.toString() ?? '';
      throw ApiException(messages[key] ?? 'تعذر تنفيذ الطلب ($key)', r.statusCode);
    }
    return json;
  }

  Future<List<Map<String, dynamic>>> list(String path) async {
    final response = await request(path);
    final values = response['data'];
    if (values is! List) throw const ApiException('تنسيق البيانات غير متوقع');
    return values.whereType<Map>().map((item) => Map<String,dynamic>.from(item)).toList();
  }
  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await request('/auth/login',method:'POST',body:{'email':email,'password':password});
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) throw const ApiException('لم يرجع الخادم رمز الدخول');
    _token = token;
    await _storage.write(key:'auth_token',value:token);
    return Map<String, dynamic>.from(data['user'] as Map);
  }
  Future<void> register(String name, String email, String password) async {
    await request('/auth/register', method:'POST',body:{'name':name,'email':email,'password':password});
  }
  Future<Map<String, dynamic>> me() async =>
    Map<String,dynamic>.from((await request('/me',auth:true))['data'] as Map);
  Future<List<Map<String,dynamic>>> orders() async =>
    _authorizedList('/me/orders');
  Future<List<Map<String,dynamic>>> subscriptions() async =>
    _authorizedList('/me/subscriptions');
  Future<List<Map<String,dynamic>>> _authorizedList(String path) async {
    final response = await request(path,auth:true);
    return (response['data'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
  }
  Future<Map<String,dynamic>> access(int bookId) async =>
    Map<String,dynamic>.from((await request('/books/$bookId/access',auth:true))['data'] as Map);
  Future<Map<String,dynamic>> order(int planId,int paymentId) async =>
    Map<String,dynamic>.from((await request('/me/orders',method:'POST',auth:true,
      body:{'plan_id':planId,'payment_method_id':paymentId}))['data'] as Map);
  Future<void> logout() async {
    if (loggedIn) {
      try { await request('/auth/logout',method:'POST',auth:true); } catch (_) {}
    }
    _token = null;
    await _storage.delete(key:'auth_token');
  }
  void dispose() => _client.close();
}
