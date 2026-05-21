import '../models/cliente_model.dart';
import 'generic_repository.dart';

class ClienteRepository {
  final GenericRepository _repo = GenericRepository.instance;

  /// Obtiene todos los clientes desde la API en línea
  Future<List<ClienteModel>> getClientes() async {
    return _repo.getList<ClienteModel>(
      path: '/customer/profit',
      nestedKey: 'data',
      fromJson: (json) => ClienteModel.fromJson(json),
    );
  }

  /// Busca clientes en línea por término de búsqueda
  Future<List<ClienteModel>> buscarClientes(String query) async {
    return _repo.getList<ClienteModel>(
      path: '/customer/profit',
      queryParams: {
        'search': query,
        'limit': '50',
      },
      nestedKey: 'data',
      fromJson: (json) => ClienteModel.fromJson(json),
    );
  }

  /// Obtiene un cliente por ID en línea
  Future<ClienteModel?> getClienteById(String id) async {
    return _repo.getById<ClienteModel>(
      path: '/customer/profit/$id',
      fromJson: (json) => ClienteModel.fromJson(json),
    );
  }

  /// Guarda una lista de clientes en SQLite
  Future<void> guardarClientes(List<ClienteModel> clientes) async {
    for (var cliente in clientes) {
      await _repo.insert(
        table: 'clientes',
        data: cliente.toJson(),
        id: cliente.id,
      );
    }
  }

  /// Obtiene el total de clientes
  Future<int> contarClientes() async {
    final result = await _repo.rawQuery('SELECT COUNT(*) as total FROM clientes');
    return result.isNotEmpty ? (result.first['total'] as int?) ?? 0 : 0;
  }
}