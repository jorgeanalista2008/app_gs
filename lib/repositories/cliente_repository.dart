import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/env.dart';
import '../models/cliente_model.dart';
import '../services/database_helper.dart';
import 'generic_repository.dart';

class ClienteRepository {
  final GenericRepository _repo = GenericRepository.instance;
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Obtiene clientes locales desde SQLite
  Future<List<ClienteModel>> getClientesLocales() async {
    return _repo.getListLocal<ClienteModel>(
      table: 'clientes',
      orderBy: 'name ASC',
      fromJson: (json) => ClienteModel.fromJson(json),
    );
  }

  /// Obtiene clientes desde la API con email/password
  Future<List<ClienteModel>> fetchClientesFromApi({
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse('${Env.apiBaseUrl}/salesperson/auth/customers');

      print('🌐 Obteniendo clientes desde API...');
      print('📧 Email: $email');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 30));

      print('📊 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final clientes = data.map((json) => ClienteModel.fromJson(json)).toList();
        print('✅ ${clientes.length} clientes obtenidos de API');
        return clientes;
      }
      return [];
    } catch (e) {
      print('❌ Error obteniendo clientes: $e');
      return [];
    }
  }

  /// Descarga clientes de API y los guarda en SQLite (solo insert)
  Future<int> sincronizarClientes({
    required String email,
    required String password,
  }) async {
    try {
      final clientes = await fetchClientesFromApi(email: email, password: password);
      if (clientes.isEmpty) return 0;

      final db = await _db.database;
      int guardados = 0;

      for (var cliente in clientes) {
        final existente = await db.query(
          'clientes',
          where: 'id = ?',
          whereArgs: [cliente.id],
          limit: 1,
        );

        if (existente.isEmpty) {
          await db.insert('clientes', {
            'id': cliente.id,
            'name': cliente.name,
            'code_client_profit': cliente.codeClientProfit,
            'tax_id': cliente.taxId,
            'sincronizado': 1,
            'fecha_sync': DateTime.now().toIso8601String(),
          });
          guardados++;
        }
      }

      print('✅ $guardados clientes nuevos guardados localmente');
      return guardados;
    } catch (e) {
      print('❌ Error sincronizando clientes: $e');
      return 0;
    }
  }
}