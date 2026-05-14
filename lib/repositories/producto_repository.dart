import '../models/product_model.dart';
import 'generic_repository.dart';

class ProductoRepository {
  final GenericRepository _repo = GenericRepository.instance;

  /// Obtiene productos con paginación
  Future<List<ProductoModel>> getProductos({
    int page = 1,
    int limit = 25,
  }) async {
    return _repo.getList<ProductoModel>(
      path: '/product/profit',
      queryParams: {
        'limit': limit.toString(),
        'page': page.toString(),
      },
      nestedKey: 'data',
      fromJson: (json) => ProductoModel.fromJson(json),
    );
  }

  /// Busca productos por descripción, código o categoría
  Future<List<ProductoModel>> buscarProductos(String query) async {
    return _repo.getList<ProductoModel>(
      path: '/product/profit',
      queryParams: {
        'search': query,
        'limit': '50',
      },
      nestedKey: 'data',
      fromJson: (json) => ProductoModel.fromJson(json),
    );
  }

  /// Obtiene un producto por código
  Future<ProductoModel?> getProductoByCodigo(String codigo) async {
    return _repo.getById<ProductoModel>(
      path: '/product/profit/$codigo',
      fromJson: (json) => ProductoModel.fromJson(json),
    );
  }
}