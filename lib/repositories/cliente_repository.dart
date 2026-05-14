import '../models/cliente_model.dart';
import 'generic_repository.dart';

class ClienteRepository {
  final GenericRepository _repo = GenericRepository.instance;

  /// Obtiene los clientes asignados a un vendedor específico
  Future<List<ClienteModel>> getClientesByVendedor(String userId) async {
    return _repo.getList<ClienteModel>(
      path: '/salesperson/me/customers/',
      nestedKey: 'customers',
      fromJson: (json) => ClienteModel.fromJson(json),
    );
  }
  /// Obtiene los clientes del vendedor logueado
Future<List<ClienteModel>> getMisClientes() async {
  final userId = await _repo.getUserId();  // <-- Usar el método público
  if (userId == null) throw Exception('Usuario no autenticado');
  
  return getClientesByVendedor(userId);
}


}