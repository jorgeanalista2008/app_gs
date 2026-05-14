class ProductoModel {
  final String coArt;
  final String artDes;
  final String codigoBarras;
  final String ubicacion;
  final String uniVenta;
  final double precVta1;
  final double precVta2;
  final double precVta3;
  final double precVta4;
  final double ultCosOm;
  final double ultCosUn;
  final double cosProUn;
  final double cosProv;
  final int stockAct;
  final String desCol;
  final String linDes;
  final String catDes;
  final String ultimaCompra;
  final String proveedor;
  final String ultimaVenta;
  final String imagen1;
  final String imagen2;
  final String ultimaModificacion;
  final String tipoImp;
  final String tipoImpuestoDesc;

  ProductoModel({
    required this.coArt,
    required this.artDes,
    this.codigoBarras = '',
    this.ubicacion = '',
    this.uniVenta = 'UND',
    this.precVta1 = 0.0,
    this.precVta2 = 0.0,
    this.precVta3 = 0.0,
    this.precVta4 = 0.0,
    this.ultCosOm = 0.0,
    this.ultCosUn = 0.0,
    this.cosProUn = 0.0,
    this.cosProv = 0.0,
    this.stockAct = 0,
    this.desCol = '',
    this.linDes = '',
    this.catDes = '',
    this.ultimaCompra = '',
    this.proveedor = '',
    this.ultimaVenta = '',
    this.imagen1 = '',
    this.imagen2 = '',
    this.ultimaModificacion = '',
    this.tipoImp = '1',
    this.tipoImpuestoDesc = 'G',
  });

  factory ProductoModel.fromJson(Map<String, dynamic> json) {
    return ProductoModel(
      coArt: json['co_art']?.toString() ?? '',
      artDes: json['art_des']?.toString() ?? 'Sin descripción',
      codigoBarras: json['codigoBarras']?.toString() ?? '',
      ubicacion: json['ubicacion']?.toString() ?? '',
      uniVenta: json['uni_venta']?.toString() ?? 'UND',
      precVta1: double.tryParse(json['prec_vta1']?.toString() ?? '0') ?? 0.0,
      precVta2: double.tryParse(json['prec_vta2']?.toString() ?? '0') ?? 0.0,
      precVta3: double.tryParse(json['prec_vta3']?.toString() ?? '0') ?? 0.0,
      precVta4: double.tryParse(json['prec_vta4']?.toString() ?? '0') ?? 0.0,
      ultCosOm: double.tryParse(json['ult_cos_om']?.toString() ?? '0') ?? 0.0,
      ultCosUn: double.tryParse(json['ult_cos_un']?.toString() ?? '0') ?? 0.0,
      cosProUn: double.tryParse(json['cos_pro_un']?.toString() ?? '0') ?? 0.0,
      cosProv: double.tryParse(json['cos_prov']?.toString() ?? '0') ?? 0.0,
      stockAct: int.tryParse(json['stock_act']?.toString() ?? '0') ?? 0,
      desCol: json['des_col']?.toString() ?? '',
      linDes: json['lin_des']?.toString() ?? '',
      catDes: json['cat_des']?.toString() ?? '',
      ultimaCompra: json['ultima_compra']?.toString() ?? '',
      proveedor: json['proveedor']?.toString() ?? '',
      ultimaVenta: json['ultima_venta']?.toString() ?? '',
      imagen1: json['imagen1']?.toString().trim() ?? '',
      imagen2: json['imagen2']?.toString().trim() ?? '',
      ultimaModificacion: json['ultima_modificacion']?.toString() ?? '',
      tipoImp: json['tipo_imp']?.toString() ?? '1',
      tipoImpuestoDesc: json['tipo_impuesto_desc']?.toString() ?? 'G',
    );
  }

  /// Obtiene el mejor precio de venta (el menor > 0)
  double get mejorPrecio {
    final precios = [precVta1, precVta2, precVta3, precVta4]
        .where((p) => p > 0)
        .toList();
    precios.sort();
    return precios.isNotEmpty ? precios.first : 0.0;
  }

  /// Precio sugerido de venta (el mayor)
  double get precioSugerido {
    final precios = [precVta1, precVta2, precVta3, precVta4]
        .where((p) => p > 0)
        .toList();
    precios.sort();
    return precios.isNotEmpty ? precios.last : 0.0;
  }

  /// Si el producto está en stock
  bool get tieneStock => stockAct > 0;

  /// Nombre de la imagen principal (limpio de espacios)
  String? get imagenPrincipal {
    final img = imagen1.trim();
    return img.isNotEmpty ? img : null;
  }
      static const String _baseImageUrl = 'https://app.grupo-solsumed.com/admin';

      /// URL completa de la imagen 1
      String get imagen1Url {
        final img = imagen1.trim();
        if (img.isEmpty) return '';
        return '$_baseImageUrl$img';
      }

      /// URL completa de la imagen 2
      String get imagen2Url {
        final img = imagen2.trim();
        if (img.isEmpty) return '';
        return '$_baseImageUrl$img';
      }

      /// Lista de URLs de imágenes disponibles
      List<String> get imagenesUrls {
        final urls = <String>[];
        if (imagen1Url.isNotEmpty) urls.add(imagen1Url);
        if (imagen2Url.isNotEmpty) urls.add(imagen2Url);
        return urls;
      }
  Map<String, dynamic> toJson() => {
    'co_art': coArt,
    'art_des': artDes,
    'codigoBarras': codigoBarras,
    'ubicacion': ubicacion,
    'uni_venta': uniVenta,
    'prec_vta1': precVta1,
    'prec_vta2': precVta2,
    'prec_vta3': precVta3,
    'prec_vta4': precVta4,
    'ult_cos_om': ultCosOm,
    'ult_cos_un': ultCosUn,
    'cos_pro_un': cosProUn,
    'cos_prov': cosProv,
    'stock_act': stockAct,
    'des_col': desCol,
    'lin_des': linDes,
    'cat_des': catDes,
    'ultima_compra': ultimaCompra,
    'proveedor': proveedor,
    'ultima_venta': ultimaVenta,
    'imagen1': imagen1,
    'imagen2': imagen2,
    'ultima_modificacion': ultimaModificacion,
    'tipo_imp': tipoImp,
    'tipo_impuesto_desc': tipoImpuestoDesc,
  };

  @override
  String toString() => 'Producto(coArt: $coArt, artDes: $artDes, stock: $stockAct)';
}