import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, [this.statusCode = 0]);
  final String message;
  final int statusCode;
  @override
  String toString() => message;
}

/// No MySQL credentials are stored on the device. All customer data comes
/// from the existing website's authenticated HTTPS API.
class SutoorApi {
  SutoorApi({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  static const baseUrl = String.fromEnvironment('SUTOOR_API_URL',
      defaultValue: 'https://sutoor.it.com/api/v1');
  final http.Client _client;
  final FlutterSecureStorage _storage;
  String? _token;

  Future<void> restore() async {
    try { _token = await _storage.read(key: 'auth_token'); }
    catch (_) { _token = null; }
  }
  bool get loggedIn => _token?.isNotEmpty == true;
  Map<String, String> _headers({bool auth = false}) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=utf-8',
    if (auth && loggedIn) 'Authorization': 'Bearer $_token',
  };

  Future<Map<String, dynamic>> request(String path,
      {String method = 'GET', Map<String, dynamic>? body, bool auth = false}) async {
    if (auth && !loggedIn) throw const ApiException('يرجى تسجيل الدخول أولاً', 401);
    final uri = Uri.parse('$baseUrl$path');
    late http.Response response;
    try {
      final req = http.Request(method, uri)..headers.addAll(_headers(auth: auth));
      if (body != null) req.body = jsonEncode(body);
      response = await _client.send(req).then(http.Response.fromStream)
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw const ApiException('انتهت مهلة الاتصال. حاول مرة أخرى.');
    } catch (_) {
      throw const ApiException('تعذر الاتصال بالموقع. تحقق من الإنترنت وحاول مجدداً.');
    }
    Map<String, dynamic> result;
    try {
      final decoded = jsonDecode(response.body);
      result = decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      throw ApiException('استجابة الخادم غير صالحة (${response.statusCode})', response.statusCode);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      const errors = <String, String>{
        'invalid_credentials': 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
        'unauthorized': 'انتهت الجلسة، يرجى تسجيل الدخول مجدداً',
        'invalid_registration': 'تأكد من الاسم والبريد وكلمة مرور لا تقل عن 10 أحرف',
        'email_unavailable': 'البريد الإلكتروني مسجل مسبقاً',
        'service_unavailable': 'خدمة قاعدة البيانات غير متاحة حالياً',
        'invalid_plan_or_payment_method': 'الباقة أو وسيلة الدفع غير متاحة',
        'whatsapp_unavailable': 'خدمة واتساب غير متاحة حالياً',
        'access_denied': 'ليست لديك صلاحية الوصول إلى هذا الكتاب',
        'content_unavailable': 'لم يتم رفع ملف هذا الكتاب بعد',
        'not_found': 'العنصر غير موجود',
      };
      final code = result['error']?.toString() ?? '';
      throw ApiException(errors[code] ?? 'تعذر إتمام الطلب (${response.statusCode})', response.statusCode);
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> list(String path, {bool auth = false}) async {
    final data = (await request(path, auth: auth))['data'];
    if (data is! List) throw const ApiException('البيانات المستلمة غير متوقعة');
    return data.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList();
  }
  Future<void> health() async { await request('/health'); }
  Future<void> login(String email, String password) async {
    final data = await request('/auth/login', method: 'POST',
        body: {'email': email, 'password': password});
    final token = data['token']?.toString() ?? '';
    if (token.isEmpty) throw const ApiException('لم يرجع الموقع رمز جلسة صالحاً');
    await _storage.write(key: 'auth_token', value: token);
    _token = token;
  }
  Future<void> register(String name, String email, String password) async {
    await request('/auth/register', method: 'POST',
        body: {'name': name, 'email': email, 'password': password});
  }
  Future<Map<String, dynamic>> me() async =>
      Map<String, dynamic>.from((await request('/me', auth: true))['data'] as Map);
  Future<List<Map<String, dynamic>>> orders() => list('/me/orders', auth: true);
  Future<List<Map<String, dynamic>>> subscriptions() => list('/me/subscriptions', auth: true);
  Future<List<Map<String, dynamic>>> myLibrary() => list('/me/library', auth: true);
  Future<Map<String, dynamic>> access(int bookId) async =>
      Map<String, dynamic>.from((await request('/books/$bookId/access', auth: true))['data'] as Map);
  Future<Map<String, dynamic>> order(int planId, int paymentId) async =>
      Map<String, dynamic>.from((await request('/me/orders', method: 'POST', auth: true,
          body: {'plan_id': planId, 'payment_method_id': paymentId}))['data'] as Map);

  /// Protected PDF bytes. Requires the PHP API upgrade bundled with this app.
  Future<Uint8List> bookPdf(int bookId, {bool download = false}) async {
    if (!loggedIn) throw const ApiException('يرجى تسجيل الدخول أولاً', 401);
    final path = '/books/$bookId/${download ? 'download' : 'content'}';
    late http.Response response;
    try {
      response = await _client.get(Uri.parse('$baseUrl$path'), headers: _headers(auth: true))
          .timeout(const Duration(seconds: 60));
    } catch (_) { throw const ApiException('تعذر تحميل محتوى الكتاب'); }
    if (response.statusCode != 200) {
      if (response.statusCode == 403) throw const ApiException('القراءة غير مسموحة لهذا الحساب', 403);
      if (response.statusCode == 404) throw const ApiException('ملف PDF غير متوفر على الخادم', 404);
      throw ApiException('تعذر فتح الكتاب (${response.statusCode})', response.statusCode);
    }
    final bytes = response.bodyBytes;
    if (bytes.length < 5 || String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw const ApiException('المحتوى المستلم ليس ملف PDF صالحاً');
    }
    return bytes;
  }

  Future<void> logout() async {
    if (loggedIn) {
      try { await request('/auth/logout', method: 'POST', auth: true); } catch (_) {}
    }
    _token = null;
    try { await _storage.delete(key: 'auth_token'); } catch (_) {}
  }
  void dispose() => _client.close();
}
