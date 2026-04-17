import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _host = '192.168.1.9';

  static const String _baseUrl = 'http://$_host:3000/api';
  static const String _mlBaseUrl = 'http://$_host:8000/api/ml';
  static const String _apiKey = 'delisure-demo-key-2026';
  static const Duration _timeout = Duration(seconds: 10);

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _currentWorkerId;
  String? get currentWorkerId => _currentWorkerId;

  String? _adminToken;
  String? get adminToken => _adminToken;
  bool get isAdmin => _adminToken != null;

  Future<void> setWorkerId(String id) async {
    _currentWorkerId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('worker_id', id);
  }

  Future<String?> loadWorkerId() async {
    final prefs = await SharedPreferences.getInstance();
    _currentWorkerId = prefs.getString('worker_id');
    return _currentWorkerId;
  }

  Future<void> clearWorkerId() async {
    _currentWorkerId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('worker_id');
  }

  Future<void> setAdminToken(String token) async {
    _adminToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_token', token);
  }

  Future<String?> loadAdminToken() async {
    final prefs = await SharedPreferences.getInstance();
    _adminToken = prefs.getString('admin_token');
    return _adminToken;
  }

  Future<void> clearAdminToken() async {
    _adminToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-api-key': _apiKey,
    };
    if (_adminToken != null) headers['x-admin-token'] = _adminToken!;
    return headers;
  }

  Future<http.Response> _get(String url, {Map<String, String>? headers}) {
    return http.get(Uri.parse(url), headers: headers ?? _headers).timeout(_timeout);
  }

  Future<http.Response> _post(String url, {Map<String, dynamic>? body}) {
    return http.post(
      Uri.parse(url),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(_timeout);
  }

  Future<http.Response> _put(String url, {Map<String, dynamic>? body}) {
    return http.put(
      Uri.parse(url),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(_timeout);
  }

  Future<Map<String, dynamic>> login(String partnerId, String phone) async {
    try {
      final res = await _post('$_baseUrl/workers/login', body: {
        'partnerId': partnerId,
        'phone': phone,
      });
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['worker'] != null) {
        await setWorkerId(data['worker']['id']);
        return data;
      }
      return {'error': data['error'] ?? 'Login failed'};
    } on TimeoutException {
      return {'error': 'Server not reachable. Check that backend is running.'};
    } catch (e) {
      return {'error': 'Could not connect to server. Is the backend running on $_host:3000?'};
    }
  }

  Future<Map<String, dynamic>> verifyAadhaar(String aadhaar) async {
    try {
      final res = await _post('$_baseUrl/workers/verify-aadhaar', body: {'aadhaar': aadhaar});
      return jsonDecode(res.body);
    } catch (e) {
      return {'valid': false, 'error': 'Could not reach server'};
    }
  }

  Future<Map<String, dynamic>> registerWorker({
    required String partnerId,
    required String name,
    required String phone,
    required List<String> zones,
    required String aadhaar,
    String? upiId,
    String platform = 'swiggy',
  }) async {
    try {
      final res = await _post('$_baseUrl/workers/register', body: {
        'partnerId': partnerId,
        'name': name,
        'phone': phone,
        'zones': zones,
        'aadhaar': aadhaar,
        'upiId': upiId,
        'platform': platform,
      });
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 201 && data['worker'] != null) {
        await setWorkerId(data['worker']['id']);
      }
      return data;
    } catch (e) {
      return {'error': 'Could not reach server'};
    }
  }

  Future<Map<String, dynamic>?> getWorker(String workerId) async {
    try {
      final res = await _get('$_baseUrl/workers/$workerId');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getDashboard(String workerId) async {
    try {
      final res = await _get('$_baseUrl/workers/$workerId/dashboard');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getRiskProfile(String workerId) async {
    try {
      final res = await _get('$_baseUrl/workers/$workerId/risk-profile');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> updateWorker(String workerId, Map<String, dynamic> data) async {
    try {
      final res = await _put('$_baseUrl/workers/$workerId', body: data);
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> activatePolicy(String workerId) async {
    try {
      final res = await _post('$_baseUrl/policies/activate', body: {'workerId': workerId});
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': 'Could not reach server'};
    }
  }

  Future<Map<String, dynamic>?> getPolicies(String workerId) async {
    try {
      final res = await _get('$_baseUrl/policies/$workerId');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> pausePolicy(String policyId) async {
    try {
      final res = await _put('$_baseUrl/policies/$policyId/pause');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> resumePolicy(String policyId) async {
    try {
      final res = await _put('$_baseUrl/policies/$policyId/resume');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> renewPolicy(String policyId) async {
    try {
      final res = await _put('$_baseUrl/policies/$policyId/renew');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getActiveTriggers() async {
    try {
      final res = await _get('$_baseUrl/triggers/active');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> simulateTrigger({
    required String type,
    required String zone,
    double? intensity,
    double? durationHours,
    int? startHour,
    bool forceReview = false,
    bool forceBlock = false,
  }) async {
    try {
      final res = await _post('$_baseUrl/triggers/simulate', body: {
        'type': type,
        'zone': zone,
        if (intensity != null) 'intensity': intensity,
        if (durationHours != null) 'duration_hours': durationHours,
        if (startHour != null) 'start_hour': startHour,
        if (forceReview) 'forceReview': true,
        if (forceBlock) 'forceBlock': true,
      });
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': 'Could not reach server'};
    }
  }

  Future<Map<String, dynamic>?> resolveTrigger(String triggerId) async {
    try {
      final res = await _post('$_baseUrl/triggers/resolve/$triggerId');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getTriggerHistory(String zone) async {
    try {
      final res = await _get('$_baseUrl/triggers/history/$zone');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getTriggerThresholds() async {
    try {
      final res = await _get('$_baseUrl/triggers/thresholds');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getPayouts(String workerId) async {
    try {
      final res = await _get('$_baseUrl/payouts/$workerId');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getPayoutBreakdown(String workerId, String payoutId) async {
    try {
      final res = await _get('$_baseUrl/payouts/$workerId/breakdown/$payoutId');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getPayoutStats() async {
    try {
      final res = await _get('$_baseUrl/payouts/stats/summary');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getWeather(String zone) async {
    try {
      final res = await _get('$_baseUrl/monitor/weather/$zone');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<List<String>> getMonitoredZones() async {
    try {
      final res = await _get('$_baseUrl/monitor/zones');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<String>.from(data['zones']);
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> getMLPremium(String workerId) async {
    try {
      final res = await http.get(
        Uri.parse('$_mlBaseUrl/premium/$workerId'),
      ).timeout(_timeout);
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getRiskCalendar(String zone) async {
    try {
      final res = await http.get(
        Uri.parse('$_mlBaseUrl/risk-calendar/$zone'),
      ).timeout(_timeout);
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getPremiumHistory(String workerId) async {
    try {
      final res = await _get('$_baseUrl/policies/$workerId/premium-history');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getAdminStats() async {
    try {
      final res = await _get('$_baseUrl/admin/stats');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getAllWorkers() async {
    try {
      final res = await _get('$_baseUrl/workers');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getFraudChecks() async {
    try {
      final res = await _get('$_baseUrl/admin/fraud-checks');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getPendingPayouts() async {
    try {
      final res = await _get('$_baseUrl/admin/pending-payouts');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> approvePayout(String payoutId) async {
    try {
      final res = await _put('$_baseUrl/admin/payouts/$payoutId/approve');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> rejectPayout(String payoutId) async {
    try {
      final res = await _put('$_baseUrl/admin/payouts/$payoutId/reject');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getAllTriggerHistory() async {
    try {
      final res = await _get('$_baseUrl/triggers/history');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> adminLogin(String username, String password) async {
    try {
      final res = await _post('$_baseUrl/admin/login', body: {
        'username': username,
        'password': password,
      });
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['adminToken'] != null) {
        await setAdminToken(data['adminToken']);
        return data;
      }
      return {'error': data['error'] ?? 'Admin login failed'};
    } on TimeoutException {
      return {'error': 'Server not reachable. Check that backend is running.'};
    } catch (e) {
      return {'error': 'Could not connect to server.'};
    }
  }

  Future<void> adminLogout() async {
    try {
      await _post('$_baseUrl/admin/logout');
    } catch (_) {}
    await clearAdminToken();
  }

  Future<bool> verifyAdmin() async {
    if (_adminToken == null) return false;
    try {
      final res = await _get('$_baseUrl/admin/verify');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['valid'] == true;
      }
    } catch (_) {}
    return false;
  }

  Future<Map<String, dynamic>?> getAdminAnalytics() async {
    try {
      final res = await _get('$_baseUrl/admin/analytics');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getMLModelMetrics() async {
    try {
      final res = await _get('$_baseUrl/admin/ml-metrics');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getAdminAppeals() async {
    try {
      final res = await _get('$_baseUrl/admin/appeals');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> approveAppeal(int appealId, {String? notes}) async {
    try {
      final res = await _put('$_baseUrl/admin/appeals/$appealId/approve',
          body: {'adminNotes': notes ?? ''});
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> rejectAppeal(int appealId, {String? notes}) async {
    try {
      final res = await _put('$_baseUrl/admin/appeals/$appealId/reject',
          body: {'adminNotes': notes ?? ''});
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> simulateSpoof(String workerId, String zone, String spoofType) async {
    try {
      final res = await _post('$_baseUrl/triggers/simulate-spoof', body: {
        'workerId': workerId,
        'zone': zone,
        'spoofType': spoofType,
      });
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': 'Could not reach server'};
    }
  }

  String get auditReportUrl {
    final params = <String, String>{
      'apiKey': _apiKey,
      if (_adminToken != null) 'adminToken': _adminToken!,
    };
    final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '$_baseUrl/admin/audit-report?$qs';
  }

  Future<bool> postDeviceSignals(String workerId, Map<String, dynamic> signals) async {
    try {
      final res = await _post('$_baseUrl/workers/$workerId/device-signals', body: signals);
      return res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> verifyUpi(String upi) async {
    try {
      final res = await _post('$_baseUrl/workers/verify-upi', body: {'upi': upi});
      return jsonDecode(res.body);
    } catch (e) {
      return {'valid': false, 'error': 'Could not reach server'};
    }
  }

  Future<Map<String, dynamic>?> getInvoice(String payoutId) async {
    try {
      final res = await _get('$_baseUrl/payouts/$payoutId/invoice');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  String invoicePdfUrl(String payoutId) {
    final params = <String, String>{
      'apiKey': _apiKey,
      if (_adminToken != null) 'adminToken': _adminToken!,
    };
    final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '$_baseUrl/payouts/$payoutId/invoice/pdf?$qs';
  }

  Future<Map<String, dynamic>> submitAppeal(String payoutId, String workerId, String reason) async {
    try {
      final res = await _post('$_baseUrl/payouts/$payoutId/appeal', body: {
        'workerId': workerId,
        'reason': reason,
      });
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': 'Could not reach server'};
    }
  }

  Future<Map<String, dynamic>?> getWorkerAppeals(String workerId) async {
    try {
      final res = await _get('$_baseUrl/payouts/$workerId/appeals/list');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<bool> isBackendHealthy() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/health')).timeout(
        const Duration(seconds: 3),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
