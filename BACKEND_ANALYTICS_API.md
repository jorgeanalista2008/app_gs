# API de Analytics del Backend — Guía de Integración para App Mobile

> **Fecha**: 26/08/2026  
> **Estado**: ✅ Implementado en rama `jorge` del backend (`gsolsumed_backend`)  
> **Autoridad**: Cambios en `gsolsumed_backend/src/modules/salesperson/`  

---

## TL;DR

Se agregaron **8 nuevos endpoints públicos** para que la app móvil acceda a análisis de clientes. **No necesitan JWT Bearer tokens** — utilizan autenticación offline con email+password en el body (patrón ya usado en otros endpoints de `salesperson/auth`).

---

## Resumen de Endpoints

| Método | Ruta | Qué devuelve |
|--------|------|--------------|
| `POST` | `/salesperson/auth/customers/:customerId/dashboard` | Saldos, deuda por vencer/vencida, desglose por rango de días |
| `POST` | `/salesperson/auth/customers/:customerId/stats` | Facturas totales, última compra, USD/Bs, días sin comprar |
| `POST` | `/salesperson/auth/customers/:customerId/invoices` | Historial de facturas paginado con filtros |
| `POST` | `/salesperson/auth/customers/:customerId/rfm` | RFM segmentation (Recency, Frequency, Monetary) |
| `POST` | `/salesperson/auth/customers/:customerId/value-matrix` | Posición en matriz valor (margen vs esfuerzo) |
| `POST` | `/salesperson/auth/customers/:customerId/ltv` | LTV 12m/24m, margen estimado, score de churn |
| `POST` | `/salesperson/auth/customers/:customerId/trend` | Tendencia de compras últimos N días |
| `POST` | `/salesperson/auth/churn-alerts` | Clientes en riesgo (sin compras o score alto) |

---

## Estructura de Requests

### Request Base (sin filtros)
```json
{
  "email": "vendedor@correo.com",
  "password": "MiClave123"
}
```

### Con Filtros Opcionales

**Dashboard + Stats + RFM + Value Matrix + LTV**:
```json
{
  "email": "vendedor@correo.com",
  "password": "MiClave123"
}
```

**Invoices** (soporta filtros):
```json
{
  "email": "vendedor@correo.com",
  "password": "MiClave123",
  "period": "30d",           // "30d" | "90d" | "180d" | "1y" | "all"
  "from": "2026-01-01",
  "to": "2026-08-26",
  "search": "FAC-001",       // búsqueda por número de factura
  "page": 1,
  "limit": 10
}
```

**Trend** (filtra por días):
```json
{
  "email": "vendedor@correo.com",
  "password": "MiClave123",
  "days": 30                 // últimos N días (default 30)
}
```

**Churn Alerts** (filtros de riesgo):
```json
{
  "email": "vendedor@correo.com",
  "password": "MiClave123",
  "minDaysWithoutPurchase": 30,  // mínimo días sin compra para alertar
  "limit": 50                    // máximo de alertas a retornar
}
```

---

## Ejemplos en Dart/Flutter

### 1. Dashboard del Cliente

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<Map<String, dynamic>> fetchCustomerDashboard(
  String apiUrl,
  String customerId,
  String email,
  String password,
) async {
  final url = Uri.parse('$apiUrl/salesperson/auth/customers/$customerId/dashboard');
  
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': password,
    }),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else if (response.statusCode == 401) {
    throw Exception('Credenciales inválidas');
  } else if (response.statusCode == 403) {
    throw Exception('Cliente no asignado a tu cartera');
  } else {
    throw Exception('Error: ${response.statusCode}');
  }
}

// Uso:
try {
  final dashboard = await fetchCustomerDashboard(
    'http://localhost:4000/api',
    'e123abc0-1234-5678-9abc-def012345678',
    'vendedor@correo.com',
    'MiClave123',
  );
  
  print('Saldos por vencer: ${dashboard['saldos_por_vencer']}');
  print('Saldos vencidos: ${dashboard['saldos_vencidos']}');
  print('Total documentos: ${dashboard['total_docs']}');
} catch (e) {
  print('Error: $e');
}
```

### 2. Historial de Facturas con Filtros

```dart
Future<Map<String, dynamic>> fetchCustomerInvoices(
  String apiUrl,
  String customerId,
  String email,
  String password, {
  String period = '30d',
  int page = 1,
  int limit = 10,
}) async {
  final url = Uri.parse('$apiUrl/salesperson/auth/customers/$customerId/invoices');
  
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': password,
      'period': period,  // "30d", "90d", "180d", "1y", "all"
      'page': page,
      'limit': limit,
    }),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
    // Estructura: { rows: [...], total: 42, page: 1, limit: 10 }
  } else {
    throw Exception('Error ${response.statusCode}');
  }
}

// Uso:
final invoices = await fetchCustomerInvoices(
  'http://localhost:4000/api',
  customerId,
  email,
  password,
  period: '90d',
  page: 1,
  limit: 20,
);

for (final invoice in invoices['rows']) {
  print('${invoice['fact_num']} - ${invoice['fecha']} - ${invoice['tot_neto']}');
}
```

### 3. Análisis RFM

```dart
Future<Map<String, dynamic>> fetchCustomerRFM(
  String apiUrl,
  String customerId,
  String email,
  String password,
) async {
  final url = Uri.parse('$apiUrl/salesperson/auth/customers/$customerId/rfm');
  
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': password,
    }),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Error ${response.statusCode}');
  }
}

// Respuesta incluye:
// - recency_dias: días desde última compra
// - facturas_totales: cantidad total
// - frequency_facturas_mes: compras por mes
// - monetary_total_ves, monetary_total_usd: montos totales
// - rfm_score: 1-9 (score combinado de segmentación)
```

### 4. Lifetime Value + Churn Risk

```dart
Future<Map<String, dynamic>> fetchCustomerLTV(
  String apiUrl,
  String customerId,
  String email,
  String password,
) async {
  final url = Uri.parse('$apiUrl/salesperson/auth/customers/$customerId/ltv');
  
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': password,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    // data['ltv_proyectado_12m'] - LTV para próximos 12 meses
    // data['churn']['churn_score'] - Score de churn (0-100)
    // data['churn']['churn_risk'] - Clasificación (bajo/medio/alto/crítico)
    // data['margen_pct'] - Margen estimado como porcentaje
    return data;
  } else {
    throw Exception('Error ${response.statusCode}');
  }
}
```

### 5. Alertas de Churn

```dart
Future<List<Map<String, dynamic>>> fetchChurnAlerts(
  String apiUrl,
  String email,
  String password, {
  int minDaysWithoutPurchase = 30,
  int limit = 50,
}) async {
  final url = Uri.parse('$apiUrl/salesperson/auth/churn-alerts');
  
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': password,
      'minDaysWithoutPurchase': minDaysWithoutPurchase,
      'limit': limit,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data);
  } else {
    throw Exception('Error ${response.statusCode}');
  }
}

// Retorna lista de clientes con:
// - id, name, code_client_profit
// - churn.dias_sin_comprar
// - churn.churn_score (0-100)
// - churn.churn_risk (clasificación)
// - ltv_proyectado_12m, margen_pct, etc.
```

---

## Estructura de Respuestas

### Dashboard Response
```json
{
  "co_cli": "001ABC",
  "cliente": "Clínica Central",
  "dias_credito": 15,
  "saldos_por_vencer": 50000.00,
  "saldos_vencidos": 120000.00,
  "docs_por_vencer": 2,
  "docs_vencidos": 5,
  "rango_0_3": 30000,
  "rango_4_7": 20000,
  "rango_8_15": 25000,
  "rango_16_30": 25000,
  "rango_mas_30": 20000,
  "total_saldo": 170000.00,
  "total_docs": 7
}
```

### Stats Response
```json
{
  "num_facturas": 42,
  "facturas_anio_actual": 15,
  "primera_compra": "2024-01-15",
  "ultima_compra": "2026-08-20",
  "total_neto_ves": 5000000.00,
  "total_neto_usd": 125000.00,
  "ticket_promedio_ves": 119047.62,
  "facturas_30d": 3,
  "total_30d_ves": 450000.00,
  "saldo_pendiente_ves": 170000.00,
  "dias_sin_comprar": 6
}
```

### LTV Response
```json
{
  "total_historico_ves": 5000000.00,
  "ticket_promedio": 119047.62,
  "facturas": 42,
  "meses_activos": 32,
  "primera_compra": "2024-01-15",
  "ultima_compra": "2026-08-20",
  "ltv_mensual_promedio": 155944.12,
  "ltv_proyectado_12m": 1871329.47,
  "ltv_proyectado_24m": 3742658.93,
  "margen_bruto_estimado_ves": 750000.00,
  "margen_pct": 15.0,
  "churn": {
    "dias_sin_comprar": 6,
    "saldo_vencido": 120000.00,
    "churn_score": 35,
    "churn_risk": "bajo"
  }
}
```

---

## Códigos de Respuesta HTTP

| Código | Significado | Acción |
|--------|------------|--------|
| `200` | ✅ Éxito | Procesar respuesta normalmente |
| `400` | ❌ Request inválido | Revisar estructura de JSON (validación class-validator) |
| `401` | ❌ No autorizado | Email o password incorrectos |
| `403` | ❌ Acceso denegado | Cliente no está asignado a este vendedor |
| `404` | ❌ No encontrado | Cliente no existe en sistema |
| `500` | ❌ Error servidor | Problema en backend (revisar logs) |

---

## Configuración de URL Base

La app debe construir la URL así:

```dart
// En utils/config.dart o similar
const String API_BASE_URL = 'http://192.168.0.135:4000/api';
// Producción:
// const String API_BASE_URL = 'https://api.gsolsumed.com/api';
```

Luego en las llamadas:

```dart
final url = Uri.parse('$API_BASE_URL/salesperson/auth/customers/$customerId/dashboard');
```

---

## Notas de Implementación

### 1. **Credenciales Seguras**
- **Guardar en Keychain/Keystore**, no en SharedPreferences en texto plano
- Los endpoints son públicos (`@Public()`), pero requieren credenciales válidas en cada request
- Considerar caching local con caducidad si se llama múltiples veces

### 2. **Clientes sin Profit Code**
- Algunos clientes pueden no tener `code_client_profit` asignado (casos nuevos)
- Cuando eso ocurre, el endpoint retorna:
  ```json
  { "message": "Cliente sin código Profit", "data": null }
  ```
- Mostrar mensaje amigable: *"Este cliente no tiene datos de Profit aún"*

### 3. **Rate Limiting**
- 600 requests por minuto por IP
- Implementado via `@Throttle` decorator
- Si se alcanza el límite, retorna `429 Too Many Requests`

### 4. **Errores de Validación**
- DTO validados con `class-validator`
- Si se envía `period` inválida (no en `["30d", "90d", "180d", "1y", "all"]`), retorna 400

### 5. **Integración con Estado Local**
- Cachear respuestas en SQLite local con `sync_service.dart`
- Refrescar cuando se abre la vista del cliente
- Considerar worker/thread para no bloquear UI

---

## Próximos Pasos

1. **Backend**: Reiniciar con `npm run start:dev` una vez SQL Server esté disponible
2. **App**: Crear servicio de HTTP wrapper:
   ```dart
   class AnalyticsService {
     Future<Map> getDashboard(String customerId) async { ... }
     Future<Map> getStats(String customerId) async { ... }
     // ... etc
   }
   ```
3. **UI**: Agregar screens de analytics:
   - Dashboard widget
   - Historial de facturas con paginación
   - RFM visualization (scatter plot)
   - LTV card + churn indicator
4. **Testing**: Validar con vendedor real en ambiente de staging

---

## Referencia Técnica

- **Backend**: `gsolsumed_backend/CUSTOMER_ANALYTICS_ENDPOINTS.md`
- **Servicios**: `gsolsumed_backend/src/modules/customer/customer.service.ts`
- **Controlador**: `gsolsumed_backend/src/modules/salesperson/salesperson-public.controller.ts`
- **Swagger**: `http://localhost:4000/api-docs` (cuando backend esté corriendo)

---

**Si hay preguntas, revisar el documento de backend o preguntar en el PR.**
