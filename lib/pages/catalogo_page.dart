import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/product_model.dart';
import '../repositories/producto_repository.dart';
import '../atoms/app_text_field.dart';

// Color BIALY
const Color bialyColor = Color(0xFF2DCCD3);

class CatalogoPage extends StatefulWidget {
  const CatalogoPage({super.key});

  @override
  State<CatalogoPage> createState() => _CatalogoPageState();
}

class _CatalogoPageState extends State<CatalogoPage> {
  final ProductoRepository _productoRepo = ProductoRepository();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ProductoModel> _productos = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMorePages = true;
  static const int _limit = 25;

  @override
  void initState() {
    super.initState();
    _loadProductos();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMorePages) {
      _loadMoreProductos();
    }
  }

  List<ProductoModel> _ordenarProductos(List<ProductoModel> productos) {
    final bialy = productos.where((p) => p.desCol.toUpperCase() == 'BIALY').toList();
    final otros = productos.where((p) => p.desCol.toUpperCase() != 'BIALY').toList();
    return [...bialy, ...otros];
  }

  Future<void> _loadProductos() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 1;
      _hasMorePages = true;
    });

    try {
      final productos = await _productoRepo.getProductos(page: _currentPage, limit: _limit);
      if (mounted) {
        setState(() {
          _productos = _ordenarProductos(productos);
          _isLoading = false;
          _hasMorePages = productos.length >= _limit;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar productos: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreProductos() async {
    if (_isLoadingMore || !_hasMorePages) return;
    setState(() => _isLoadingMore = true);
    try {
      _currentPage++;
      final nuevosProductos = await _productoRepo.getProductos(page: _currentPage, limit: _limit);
      if (mounted) {
        setState(() {
          _productos.addAll(nuevosProductos);
          _productos = _ordenarProductos(_productos);
          _isLoadingMore = false;
          _hasMorePages = nuevosProductos.length >= _limit;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _currentPage--;
        });
      }
    }
  }

  Future<void> _buscarProductos(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final productos = query.isEmpty
          ? await _productoRepo.getProductos(page: 1, limit: _limit)
          : await _productoRepo.buscarProductos(query);
      if (mounted) {
        setState(() {
          _productos = _ordenarProductos(productos);
          _isLoading = false;
          _hasMorePages = query.isEmpty && productos.length >= _limit;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al buscar: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Catálogo'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: AppTextField(
              controller: _searchController,
              labelText: 'Buscar producto',
              hintText: 'Nombre, código o categoría...',
              icon: Icons.search,
              onSubmitted: _buscarProductos,
            ),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadProductos, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    if (_productos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty ? 'No hay productos disponibles' : 'No se encontraron productos',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProductos,
      color: AppColors.primaryColor,
      child: Column(
        children: [
          // Contador
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.inventory, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '${_productos.length} producto${_productos.length != 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                if (_productos.any((p) => p.desCol.toUpperCase() == 'BIALY'))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: bialyColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'BIALY: ${_productos.where((p) => p.desCol.toUpperCase() == "BIALY").length}',
                      style: TextStyle(fontSize: 11, color: bialyColor, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),

          // Grid
          Expanded(
            child: GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.68,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _productos.length + (_hasMorePages ? 2 : 0),
              itemBuilder: (context, index) {
                if (index >= _productos.length) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
                }
                return _buildProductoCard(_productos[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductoCard(ProductoModel producto) {
    final esBialy = producto.desCol.toUpperCase() == 'BIALY';

    return Card(
      elevation: esBialy ? 5 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: esBialy ? BorderSide(color: bialyColor, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _mostrarDetalleProducto(producto),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: esBialy
                ? LinearGradient(
                    colors: [bialyColor.withOpacity(0.05), Colors.white],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen
             // Imagen
            Center(
              child: GestureDetector(
                onTap: () => _mostrarGaleria(producto),
                child: Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: esBialy ? bialyColor.withOpacity(0.3) : Colors.transparent),
                  ),
                  child: Stack(
                    children: [
                      // Mostrar imagen real o icono por defecto
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: producto.imagen1Url.isNotEmpty
                            ? Image.network(
                                producto.imagen1Url,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 90,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primaryColor,
                                      strokeWidth: 2,
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(Icons.inventory_2, color: AppColors.primaryColor.withOpacity(0.3), size: 50),
                                  );
                                },
                              )
                            : Center(
                                child: Icon(Icons.inventory_2, color: AppColors.primaryColor.withOpacity(0.3), size: 50),
                              ),
                      ),

                      // Badge BIALY
                      if (esBialy)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: bialyColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'BIALY',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),

                      // Badge stock
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: producto.tieneStock ? Colors.green.withOpacity(0.8) : Colors.red.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            producto.tieneStock ? 'DISP' : 'AGOT',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      // Ícono galería (solo si hay más de 1 imagen)
                      if (producto.imagenesUrls.length > 1)
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.zoom_in, size: 16, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
              const SizedBox(height: 10),

              // Código
              Text(
                producto.coArt,
                style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),

              // Descripción
              Text(
                producto.artDes,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: esBialy ? bialyColor : AppColors.textPrimary,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),

              // Marca
              if (producto.desCol.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: esBialy ? bialyColor.withOpacity(0.1) : Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    producto.desCol,
                    style: TextStyle(
                      fontSize: 9,
                      color: esBialy ? bialyColor : Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // Precio y stock
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      '\$${producto.mejorPrecio.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: esBialy ? bialyColor : AppColors.primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    producto.tieneStock ? '${producto.stockAct}' : '0',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: producto.tieneStock ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

    void _mostrarGaleria(ProductoModel producto) {
      // USAR LAS URLs COMPLETAS

        print('=== DEBUG IMÁGENES ===');
        print('imagen1 crudo: "${producto.imagen1}"');
        print('imagen2 crudo: "${producto.imagen2}"');
        print('imagen1Url: "${producto.imagen1Url}"');
        print('imagen2Url: "${producto.imagen2Url}"');
        print('imagenesUrls: ${producto.imagenesUrls}');
        print('=======================');
      final imagenes = producto.imagenesUrls;

      if (imagenes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay imágenes disponibles')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _GaleriaPage(producto: producto, imagenes: imagenes),
        ),
      );
    }

  void _mostrarDetalleProducto(ProductoModel producto) {
    final esBialy = producto.desCol.toUpperCase() == 'BIALY';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Badge BIALY
                  if (esBialy)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: bialyColor, borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text('PRODUCTO DESTACADO BIALY',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),

                  Text(
                    producto.artDes,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: esBialy ? bialyColor : AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text('Código: ${producto.coArt}', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildPreciosSection(producto),
                  const SizedBox(height: 20),
                  _buildDetailRow(Icons.business, 'Marca', producto.desCol),
                  _buildDetailRow(Icons.category, 'Línea', producto.linDes),
                  _buildDetailRow(Icons.label, 'Categoría', producto.catDes),
                  _buildDetailRow(Icons.location_on, 'Ubicación', producto.ubicacion),
                  _buildDetailRow(Icons.straighten, 'Unidad', producto.uniVenta),
                  _buildDetailRow(Icons.inventory, 'Stock', producto.tieneStock ? '${producto.stockAct} ${producto.uniVenta}' : 'Agotado'),
                  _buildDetailRow(Icons.local_shipping, 'Proveedor', producto.proveedor),
                  _buildDetailRow(Icons.shopping_cart, 'Última compra', producto.ultimaCompra),
                  _buildDetailRow(Icons.point_of_sale, 'Última venta', producto.ultimaVenta),
                  _buildDetailRow(Icons.receipt, 'Impuesto', producto.tipoImpuestoDesc),
                  _buildDetailRow(Icons.update, 'Última modificación', producto.ultimaModificacion),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPreciosSection(ProductoModel producto) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Precios de Venta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(children: [_buildPrecioCard('Precio 1', producto.precVta1), const SizedBox(width: 8), _buildPrecioCard('Precio 2', producto.precVta2)]),
          const SizedBox(height: 8),
          Row(children: [_buildPrecioCard('Precio 3', producto.precVta3), const SizedBox(width: 8), _buildPrecioCard('Precio 4', producto.precVta4)]),
        ],
      ),
    );
  }

  Widget _buildPrecioCard(String label, double precio) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const SizedBox(height: 4),
            Text('\$${precio.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 10),
          Text('$label: ', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GALERÍA DE IMÁGENES
// ─────────────────────────────────────────────────────────────────────────────
class _GaleriaPage extends StatefulWidget {
  final ProductoModel producto;
  final List<String> imagenes;

  const _GaleriaPage({required this.producto, required this.imagenes});

  @override
  State<_GaleriaPage> createState() => _GaleriaPageState();
}

class _GaleriaPageState extends State<_GaleriaPage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.producto.artDes,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              '${_currentIndex + 1} de ${widget.imagenes.length}',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imagenes.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                widget.imagenes[index],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Colors.white,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Cargando...',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ],
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  print('❌ Error cargando imagen: $error');
                  print('URL: ${widget.imagenes[index]}');
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 80, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text(
                        'No se pudo cargar la imagen',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Imagen ${index + 1} de ${widget.imagenes.length}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {});
                        },
                        child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Indicador de puntos
            ...List.generate(widget.imagenes.length, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentIndex == index ? Colors.white : Colors.grey[600],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}