import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/env.dart';
import '../models/customer_analytics_model.dart';

class CustomerAnalyticsService {
  static final CustomerAnalyticsService _instance =
      CustomerAnalyticsService._internal();

  factory CustomerAnalyticsService() => _instance;
  CustomerAnalyticsService._internal();

  /// Dashboard del cliente (saldos, deuda, desglose)
  Future<CustomerAnalyticsModel?> getDashboard({
    required String customerId,
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse(
          '${Env.apiBaseUrl}/salesperson/auth/customers/$customerId/dashboard');

      print('📡 Fetching dashboard for $customerId...');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          print('✅ Dashboard loaded');
          return CustomerAnalyticsModel.fromDashboardJson(data);
        }
      } else if (response.statusCode == 401) {
        throw Exception('Credenciales inválidas');
      } else if (response.statusCode == 403) {
        throw Exception('Cliente no asignado');
      }
      return null;
    } catch (e) {
      print('❌ Error getting dashboard: $e');
      rethrow;
    }
  }

  /// Estadísticas de compra del cliente
  Future<CustomerAnalyticsModel?> getStats({
    required String customerId,
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse(
          '${Env.apiBaseUrl}/salesperson/auth/customers/$customerId/stats');

      print('📡 Fetching stats for $customerId...');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          print('✅ Stats loaded');
          return CustomerAnalyticsModel.fromStatsJson(data);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting stats: $e');
      rethrow;
    }
  }

  /// Historial de facturas (con filtros opcionales)
  Future<Map<String, dynamic>?> getInvoices({
    required String customerId,
    required String email,
    required String password,
    String period = '30d',
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final url = Uri.parse(
          '${Env.apiBaseUrl}/salesperson/auth/customers/$customerId/invoices');

      print('📡 Fetching invoices for $customerId...');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
              'period': period,
              'page': page,
              'limit': limit,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        print('✅ Invoices loaded');
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Error getting invoices: $e');
      rethrow;
    }
  }

  /// RFM Analysis
  Future<CustomerAnalyticsModel?> getRFM({
    required String customerId,
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse(
          '${Env.apiBaseUrl}/salesperson/auth/customers/$customerId/rfm');

      print('📡 Fetching RFM for $customerId...');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          print('✅ RFM loaded');
          return CustomerAnalyticsModel.fromRfmJson(data);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting RFM: $e');
      rethrow;
    }
  }

  /// Value Matrix
  Future<Map<String, dynamic>?> getValueMatrix({
    required String customerId,
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse(
          '${Env.apiBaseUrl}/salesperson/auth/customers/$customerId/value-matrix');

      print('📡 Fetching value-matrix for $customerId...');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        print('✅ Value-matrix loaded');
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Error getting value-matrix: $e');
      rethrow;
    }
  }

  /// LTV + Churn Risk
  Future<CustomerAnalyticsModel?> getLTV({
    required String customerId,
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse(
          '${Env.apiBaseUrl}/salesperson/auth/customers/$customerId/ltv');

      print('📡 Fetching LTV for $customerId...');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          print('✅ LTV loaded');
          return CustomerAnalyticsModel.fromLtvJson(data);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting LTV: $e');
      rethrow;
    }
  }

  /// Tendencia de compras (últimos N días)
  Future<Map<String, dynamic>?> getTrend({
    required String customerId,
    required String email,
    required String password,
    int days = 30,
  }) async {
    try {
      final url = Uri.parse(
          '${Env.apiBaseUrl}/salesperson/auth/customers/$customerId/trend');

      print('📡 Fetching trend for $customerId...');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
              'days': days,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        print('✅ Trend loaded');
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Error getting trend: $e');
      rethrow;
    }
  }

  /// Alertas de churn
  Future<List<Map<String, dynamic>>?> getChurnAlerts({
    required String email,
    required String password,
    int minDaysWithoutPurchase = 30,
    int limit = 50,
  }) async {
    try {
      final url = Uri.parse('${Env.apiBaseUrl}/salesperson/auth/churn-alerts');

      print('📡 Fetching churn alerts...');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
              'minDaysWithoutPurchase': minDaysWithoutPurchase,
              'limit': limit,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          print('✅ Churn alerts loaded: ${data.length} alerts');
          return List<Map<String, dynamic>>.from(data);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting churn alerts: $e');
      rethrow;
    }
  }

  /// Top productos más comprados por el cliente
  Future<List<Map<String, dynamic>>?> getTopProducts({
    required String customerId,
    required String email,
    required String password,
    int limit = 10,
  }) async {
    try {
      final url = Uri.parse(
          '${Env.apiBaseUrl}/salesperson/auth/customers/$customerId/top-products');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting top products: $e');
      return null;
    }
  }

  /// Productos sugeridos para el cliente (basado en clientes de la misma zona)
  Future<List<Map<String, dynamic>>?> getSuggestedProducts({
    required String customerId,
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse(
          '${Env.apiBaseUrl}/salesperson/auth/customers/$customerId/suggested-products');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting suggested products: $e');
      return null;
    }
  }

  /// Correlación visita -> venta del cliente
  Future<Map<String, dynamic>>? getSalesCorrelation({
    required String customerId,
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse(
          '${Env.apiBaseUrl}/salesperson/auth/customers/$customerId/sales-correlation');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      print('❌ Error getting sales correlation: $e');
      return {};
    }
  }
}
