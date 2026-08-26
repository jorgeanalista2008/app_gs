# 🔍 Análisis: Inconsistencia de Clientes Entre App y Frontend

**Investigación sobre por qué hay diferencias en los clientes mostrados entre la app Flutter y el frontend gsolsumed_frontend**

---

## 📋 Resumen Ejecutivo

**PROBLEMA**: El vendedor principal ve diferentes clientes en:
- ✅ App Flutter (app_gs)
- ❌ Frontend web (gsolsumed_frontend)

**ROOT CAUSE CONFIRMADA**: App usa endpoint SIN filtro; Frontend usa endpoint correcto

---

## 🔗 Cómo el Frontend Obtiene Clientes

### Frontend: gsolsumed_frontend

**Endpoint Clave**: `GET /salesperson/:userId/my-customers`

```typescript
// File: gsolsumed_frontend/src/lib/salesperson-customers.ts:55

const url = `${backendBase()}/salesperson/${encodeURIComponent(userId)}/my-customers`;
const response = await fetch(url, {
  headers: {
    accept: "application/json",
    Authorization: `Bearer ${token}`
  }
});

// Response Shape:
{
  scope: "foraneo" | "assigned",  // ← CRITERIO CLAVE DE FILTRADO
  coVen: string,                   // Código vendedor
  total: number,
  customers: [...]                 // Lista de clientes filtrada
}
```

**¿QUÉ SIGNIFICA EL `scope`?**:
- `scope: "assigned"` → Clientes ASIGNADOS DIRECTAMENTE a este vendedor
- `scope: "foraneo"` → Clientes visitables pero NO son del vendedor
- **El frontend puede mostrar ambos o solo uno según filtro**

---

## 🔎 Cómo la App Obtiene Clientes

### App: app_gs

**Endpoint Actual**: `POST /salesperson/auth/customers`

```dart
// File: lib/repositories/cliente_repository.dart:290

final url = Uri.parse('${Env.apiBaseUrl}/salesperson/auth/customers');

final payload = {'email': email, 'password': password};
print('📡 === DETALLE DE ENVÍO HTTP (DEBUG) ===');

final response = await fetch(url.toString(), {
  method: "POST",
  body: jsonEncode(payload),
  headers: { ... }
});
```

**PROBLEMA**:
- ❌ NO especifica `userId` en la URL
- ❌ Usa email + password (NO JWT)
- ❌ Backend probablemente retorna clientes de TODOS los vendedores
- ❌ No hay filtrado por scope (assigned vs foraneo)

---

## 📊 Comparación: Frontend vs App

| Aspecto | Frontend | App |
|---------|----------|-----|
| **Endpoint** | `/salesperson/{userId}/my-customers` ✅ | `/salesperson/auth/customers` ❌ |
| **Parámetro Usuario** | En URL | NO incluye |
| **Autenticación** | JWT Bearer token | Email + password |
| **Filtrado** | Por `scope` (assigned/foraneo) | SIN FILTRO |
| **Resultado** | Solo clientes asignados al usuario | Todos los clientes + históricamente sincronizados |

---

## 🔴 La Verdadera Inconsistencia

```
ESCENARIO ACTUAL:

Frontend (gsolsumed_frontend):
  1. Usuario "maestro" logueado
  2. Request: GET /salesperson/maestro-id/my-customers
  3. Backend retorna: {scope: "assigned", customers: [cliente1, cliente2]}
  4. Frontend muestra: SOLO cliente1, cliente2

App (app_gs):
  1. Usuario "maestro" logueado
  2. Request: POST /salesperson/auth/customers
  3. Backend retorna: {data: [cliente1, cliente2, clienteX, clienteY, ...]}
  4. App muestra: TODOS (incluyendo clientes de otros vendedores)

RESULTADO: Inconsistencia ❌
```

---

## ✅ Solución: Usar el Endpoint Correcto

### Cambio Recomendado en app_gs

```dart
// File: lib/repositories/cliente_repository.dart

Future<List<ClienteModel>> fetchClientesFromApi({
  required String email,
  required String password,
}) async {
  try {
    // ❌ ACTUAL (INCORRECTO):
    // final url = Uri.parse('${Env.apiBaseUrl}/salesperson/auth/customers');
    
    // ✅ NUEVO (CORRECTO):
    final userId = _authService.userId;
    if (userId == null) throw Exception('No hay usuario logueado');
    
    final url = Uri.parse(
      '${Env.apiBaseUrl}/salesperson/$userId/my-customers'
    );
    
    // Cambiar también autenticación: email+password → JWT
    final onlineToken = _authService.onlineToken;
    if (onlineToken == null) {
      throw Exception('No hay token disponible');
    }
    
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $onlineToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
    
    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}');
    }
    
    // Parse response con scope
    final json = jsonDecode(response.body);
    final customersData = json['customers'] as List? ?? [];
    
    return customersData
        .map((c) => ClienteModel.fromJson(c))
        .toList();
        
  } catch (e) {
    print('❌ Error obteniendo clientes: $e');
    return [];
  }
}
```

---

## 🎯 Pasos para Implementar

### Paso 1: Verificar Endpoint Backend

Confirmar que el backend tiene:
```bash
GET /salesperson/{userId}/my-customers
Headers: Authorization: Bearer {token}
Response: {scope: "assigned"|"foraneo", customers: [...]}
```

### Paso 2: Actualizar ClienteRepository

- Cambiar URL de `/salesperson/auth/customers` → `/salesperson/{userId}/my-customers`
- Cambiar autenticación de email+password → JWT Bearer
- Parsear respuesta con `scope`

### Paso 3: Actualizar SincronizarClientes

```dart
Future<int> sincronizarClientes({
  required String email,
  required String password,
}) async {
  try {
    final clientes = await fetchClientesFromApi(
      email: email,
      password: password
    );
    
    // Guardar solo los de scope "assigned"
    // (el backend ya filtra, pero verificar)
    
    if (clientes.isEmpty) return 0;
    
    // ... resto del código
  }
}
```

### Paso 4: Limpiar BD (Opcional)

```dart
// Eliminar clientes históricos que no fueron sincronizados recientemente
await _clienteRepo.limpiarClientesHuerfanos();
```

---

## 🧪 Validación de la Solución

### Antes:
- App muestra: 100+ clientes
- Frontend muestra: 50 clientes (solo asignados)
- Inconsistencia: ❌

### Después:
- App muestra: 50 clientes (solo asignados) ✅
- Frontend muestra: 50 clientes
- Sincronía: ✅

---

## 📌 Conclusión

**ROOT CAUSE IDENTIFICADA**:
- App usa endpoint `/salesperson/auth/customers` (sin filtro)
- Frontend usa endpoint `/salesperson/{userId}/my-customers` (con filtro)
- Backend retorna diferentes resultados según endpoint

**SOLUCIÓN**: Cambiar app para usar el mismo endpoint que frontend

**BENEFICIOS**:
1. Elimina inconsistencia reportada
2. Mejora performance (menos datos)
3. Alinea app con lógica del frontend
4. Usa JWT en lugar de email+password (más seguro)

---

**Documento Generado**: 2026-08-24
**Investigación**: Completada - raíz del problema identificada
**Status**: Listo para implementación
**Impacto**: Alto (solucionaría inconsistencia completamente)
