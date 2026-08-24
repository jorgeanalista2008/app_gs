# 📡 Análisis: Cómo se Traen las Encuestas del Backend

**Revisión detallada del flujo de obtención de encuestas desde el servidor**

---

## 🎯 Resumen Ejecutivo

```
USUARIO SELECCIONA CLIENTE VISITADO
         ↓
DetalleVisitaPage abre
         ↓
_loadCustomer360() se ejecuta en background
         ↓
SurveyRepository.getCustomer360(customerId)
         ↓
POST /survey/auth/customers/{customerId}/360
Body: {email, password}
         ↓
BACKEND RETORNA Customer360 con encuesta recomendada
         ↓
App cachea localmente
         ↓
SurveyFormWidget muestra encuesta
```

---

## 🔗 Flujo Paso a Paso

### Paso 1: DetalleVisitaPage Se Abre

**Archivo**: `lib/pages/detalle_visita_page.dart:91-105`

```dart
@override
void initState() {
  super.initState();
  _loadDetalle();  // ← Carga datos locales
}

Future<void> _loadDetalle() async {
  setState(() => _isLoading = true);
  try {
    // 1. Carga preguntas locales (antiguo sistema)
    final preguntasData = await db.query('preguntas');
    
    // 2. Carga respuestas previas
    final rows = await _encuestaRepo.getRespuestas(widget.visita.id);
    
    // 3. CARGA ENCUESTA DEL BACKEND ← AQUÍ ES LA MAGIA
    _loadCustomer360();  // ← Llamada en background
  }
}

Future<void> _loadCustomer360() async {
  setState(() => _loadingCustomer360 = true);
  try {
    // Obtiene encuestas dinámicas del servidor
    final customer360 = await _surveyRepo.getCustomer360(
      customerId: widget.visita.customerId,  // ← Parámetro clave
    );
    if (mounted) {
      setState(() => _customer360 = customer360);  // Actualiza UI
    }
  }
}
```

**Explicación**:
- Se ejecuta en `initState()` → background
- No bloquea UI (es async)
- Usa `widget.visita.customerId` para obtener encuestas específicas

---

### Paso 2: SurveyRepository.getCustomer360() - LA PETICIÓN AL SERVIDOR

**Archivo**: `lib/repositories/survey_repository.dart:23-76`

```dart
Future<Customer360?> getCustomer360({
  required String customerId,  // ← ID del cliente
}) async {
  try {
    // 1. Obtener usuario logueado
    final userId = _authService.userId;
    if (userId == null) return null;
    
    // 2. Obtener credenciales locales
    final userLocal = await _db.getUsuario(userId);
    if (userLocal == null) return null;
    
    final username = userLocal['username']?.toString();  // maestro
    final password = userLocal['password']?.toString();  // 1234
    
    // 3. PETICIÓN AL SERVIDOR
    print('📡 [SurveyRepository] Solicitando ficha 360 para $customerId...');
    
    final response = await _genericRepo.postOnline<Map<String, dynamic>>(
      path: '/survey/auth/customers/$customerId/360',  // ← ENDPOINT
      body: {
        'email': username,      // maestro
        'password': password,   // 1234
      },
      fromJson: (json) => json,
    );
    
    // 4. PROCESAR RESPUESTA
    if (response == null) {
      print('❌ [SurveyRepository] Respuesta nula del servidor');
      return null;
    }
    
    // 5. CREAR OBJETO Customer360
    final customer360 = Customer360.fromJson(response);
    
    // 6. CACHEAR DATOS
    await cacheSurveyPack(customer360.recommendedSurvey);
    await _cacheCustomer(customer360.customer, customerId);
    
    print('✅ [SurveyRepository] Ficha 360 obtenida: ${customer360.customer['name']}');
    return customer360;
  }
}
```

**¿QUÉ PASA AQUÍ?**

| Paso | Acción | Código |
|------|--------|--------|
| 1 | Obtener usuario logueado | `AuthService.instance.userId` |
| 2 | Obtener credenciales locales | `DatabaseHelper.getUsuario(userId)` |
| 3 | **Preparar petición** | `{email, password}` |
| 4 | **Hacer POST al servidor** | `POST /survey/auth/customers/{id}/360` |
| 5 | Procesar respuesta | `Customer360.fromJson()` |
| 6 | Cachear en SQLite | `cacheSurveyPack()`, `_cacheCustomer()` |

---

## 🔍 Endpoint del Backend

### URL Completa

```
POST {BASE_URL}/survey/auth/customers/{customerId}/360
```

**Ejemplo**:
```
POST https://clientes.grupo-solsumed.com/survey/auth/customers/cli-123/360
```

### Headers (Generado por GenericRepository)

```
Content-Type: application/json
Authorization: Bearer {token}  (si aplica)
```

### Body (Enviado)

```json
{
  "email": "maestro",
  "password": "1234"
}
```

**⚠️ NOTA IMPORTANTE**: 
- NO usa JWT token
- Usa email + password en CADA petición
- Las credenciales vienen del usuario logueado localmente

### Response Esperada (Simplificada)

```json
{
  "customer": {
    "id": "cli-123",
    "name": "Empresa XYZ",
    "code_client_profit": "CLI-001",
    "phone": "0414-1234567",
    "email": "info@empresa.com",
    "address": "Calle Principal 123",
    "contact": {
      "phone": "0414-1234567",
      "email": "info@empresa.com",
      "address": "Calle Principal 123"
    }
  },
  "visitsStats": {
    "totalVisits": 15,
    "lastVisitDate": "2026-08-20T14:30:00Z"
  },
  "profitSummary": {
    "totalPurchasesUsd": 5000.50,
    "last30DaysVolume": 1200.75,
    "recentPurchases": [...]
  },
  "recommendedSurvey": {
    "id": "survey-uuid-123",
    "name": "Encuesta Cliente Nuevo",
    "pack_type": "NEW_CUSTOMER",
    "description": "Encuesta para clientes nuevos",
    "is_active": 1,
    "questions": [
      {
        "id": 1,
        "description": "¿Cómo califica nuestro servicio?",
        "type": "RATING",
        "is_required": 1,
        "sort_order": 1
      },
      {
        "id": 2,
        "description": "¿Recomendaría nuestros productos?",
        "type": "BOOLEAN",
        "is_required": 1,
        "sort_order": 2
      }
    ]
  }
}
```

---

## 📊 Cómo el Backend Decide Qué Encuesta Mostrar

### Lógica del Backend (Inferida)

El backend recibe:
- `customerId` en URL
- `email` + `password` en body

Probablemente el backend:

1. **Valida credenciales**
   - Verifica que email/password son válidas
   - Retorna 401 si son inválidas

2. **Obtiene datos del cliente**
   - Query: SELECT * FROM customers WHERE id = customerId
   - Obtiene: nombre, contacto, historial de compras, etc

3. **DETERMINA ENCUESTA RECOMENDADA** ← AQUÍ ES LA CLAVE
   ```sql
   -- Pseudocódigo de lo que hace el backend:
   
   IF customer.is_new_customer THEN
     recommended_survey = SELECT * FROM survey_packs 
                         WHERE pack_type = 'NEW_CUSTOMER'
   ELSE IF customer.last_purchase < 30_days_ago THEN
     recommended_survey = SELECT * FROM survey_packs 
                         WHERE pack_type = 'EXISTING_CUSTOMER'
   ELSE
     recommended_survey = SELECT * FROM survey_packs 
                         WHERE pack_type = 'CUSTOM'
   END IF
   ```

4. **Obtiene preguntas del pack**
   - Carga todas las preguntas asociadas al survey pack
   - Ordena por sort_order

5. **Retorna Customer360 con encuesta**
   - Incluye recomendedSurvey con todas las preguntas

---

## 🗂️ Estructura de Datos: Customer360

### Cómo Llega al Cliente

```dart
class Customer360 {
  final Map<String, dynamic> customer;           // ← Datos cliente
  final Customer360Contact? contact;              // ← Contacto
  final Customer360VisitsStats? visitsStats;     // ← Visitas
  final Customer360ProfitSummary? profitSummary; // ← Compras
  final SurveyPack? recommendedSurvey;           // ← ⭐ ENCUESTA
}

class SurveyPack {
  final String id;                      // UUID del pack
  final String name;                    // "Encuesta Cliente Nuevo"
  final String packType;                // NEW_CUSTOMER, EXISTING_CUSTOMER, CUSTOM
  final String? description;
  final List<SurveyQuestion> questions; // ← Las preguntas
  final bool isActive;
  final DateTime? createdAt;
}

class SurveyQuestion {
  final int id;                            // 1, 2, 3, ...
  final String description;                // "¿Cómo califica...?"
  final String questionType;               // RATING, BOOLEAN, TEXT, MULTIPLE_CHOICE
  final List<ResponseOption>? responseOptions;
  final bool isRequired;
  final int sortOrder;                     // 1, 2, 3, ...
}
```

---

## 💾 Cómo Se Cachea Localmente

Una vez que el backend retorna Customer360, la app:

### 1. Cachea el Survey Pack

```dart
await cacheSurveyPack(customer360.recommendedSurvey);
```

Esto hace:
```sql
INSERT INTO cached_survey_packs (
  id,          -- survey-uuid-123
  name,        -- Encuesta Cliente Nuevo
  pack_type,   -- NEW_CUSTOMER
  description, -- Encuesta para clientes nuevos
  questions,   -- JSON array de SurveyQuestion
  cached_at    -- NOW()
)
```

### 2. Cachea el Cliente

```dart
await _cacheCustomer(customer360.customer, customerId);
```

Esto hace:
```sql
INSERT INTO cached_customers (
  id,                    -- cli-123
  name,                  -- Empresa XYZ
  code_client_profit,    -- CLI-001
  phone,                 -- 0414-1234567
  email,                 -- info@empresa.com
  address,               -- Calle Principal 123
  latitude,              -- 10.1234
  longitude,             -- -66.5678
  last_sync_at           -- NOW()
)
```

---

## 🎨 Cómo Se Renderiza en UI

Una vez en cache, el widget la muestra:

### Paso 1: Customer360Card (Datos Cliente)

```dart
if (_customer360 != null)
  Card(
    child: Customer360Card(customer360: _customer360!),
  )
```

Muestra:
- Avatar + nombre
- Contacto
- Estadísticas de visitas
- Resumen de compras

### Paso 2: SurveyFormWidget (Encuesta)

```dart
if (_customer360!.recommendedSurvey != null)
  Card(
    child: SurveyFormWidget(
      pack: _customer360!.recommendedSurvey!,
      customerId: widget.visita.customerId,
      onCompleted: () { ... }
    ),
  )
```

Muestra:
- Nombre del pack
- Descripción
- Contador de preguntas
- Preguntas renderizadas dinámicamente:
  - RATING: 5 botones (1-5)
  - BOOLEAN: Sí/No
  - TEXT: textarea
  - MULTIPLE_CHOICE: radio buttons

---

## ⚡ Flujo Resumido en Diagrama

```
Usuario abre DetalleVisitaPage
         ↓
initState() → _loadDetalle()
         ↓
_loadCustomer360() [async/background]
         ↓
SurveyRepository.getCustomer360(customerId)
         ↓
Obtener credenciales locales (maestro/1234)
         ↓
POST /survey/auth/customers/{customerId}/360
Body: {email: maestro, password: 1234}
         ↓
✅ Backend retorna Customer360
         ↓
┌─ Cachea survey pack en SQLite
└─ Cachea cliente en SQLite
         ↓
setState(_customer360 = customer360)
         ↓
build() renderiza:
├─ Customer360Card (datos cliente)
└─ SurveyFormWidget (encuesta dinámicamente)
         ↓
✅ Usuario ve encuesta recomendada
```

---

## 🔒 Consideraciones de Seguridad

### ✅ Lo Que Está Bien

1. **No envía token JWT en cada request**
   - Usa credenciales locales
   - Perfecto para scenarios donde JWT expira

2. **Credenciales nunca se envían a otros endpoints**
   - Solo en `/survey/auth/customers/:id/360`
   - Otros endpoints usan JWT normalmente

3. **Datos se cachean localmente**
   - Si servidor falla, sigue mostrando último pack
   - Offline-friendly

### ⚠️ Consideraciones

1. **Credenciales en cada petición**
   - Aumenta tráfico (envía password)
   - Más riesgo si hay MITM
   - Mejor: obtener token y reutilizar

2. **Sin timeout explícito documentado**
   - ¿Cuánto espera si servidor lento?
   - 30 segundos por defecto en GenericRepository

3. **Sin reintentos documentados**
   - Si falla la petición, retorna null
   - Usuario ve "no hay encuesta"
   - ¿Debería reintentar?

---

## 🎯 Flujo Completo: De Visita a Encuesta

```
1. CREAR VISITA (VisitasPage)
   └─ Seleccionar cliente
   └─ Crear visita localmente

2. IR A DETALLE (DetalleVisitaPage)
   └─ Abrir DetalleVisitaPage(visita)

3. CARGAR FICHA 360 (background)
   └─ _loadCustomer360()
   └─ POST /survey/auth/customers/{customerId}/360

4. BACKEND DECIDE ENCUESTA
   └─ ¿Cliente nuevo? → NEW_CUSTOMER pack
   └─ ¿Compró hace <30d? → EXISTING_CUSTOMER pack
   └─ ¿Otro? → CUSTOM pack

5. APP CACHEA
   └─ cached_survey_packs ← packId, preguntas, etc
   └─ cached_customers ← nombre, contacto, etc

6. RENDERIZAR
   └─ Customer360Card (ficha cliente)
   └─ SurveyFormWidget (encuesta dinámicamente)

7. USUARIO RESPONDE
   └─ Selecciona respuestas
   └─ Toca "Enviar"
   └─ savePendingAnswer() → SQLite
   └─ SyncQueueService.enqueue() o BackgroundSync

8. SINCRONIZAR
   └─ POST /survey/auth/assignments/:id/complete
   └─ Backoff exponencial si falla
```

---

## 📋 Resumen: ¿Cómo Llegan las Encuestas?

| Aspecto | Respuesta |
|---------|-----------|
| **¿De dónde vienen?** | Endpoint POST /survey/auth/customers/:id/360 |
| **¿Quién decide cuál?** | Backend (según tipo de cliente) |
| **¿Cómo se traen?** | Email + password (credenciales locales) |
| **¿Se cachean?** | Sí, en cached_survey_packs + cached_customers |
| **¿Si servidor falla?** | Muestra última encuesta en caché |
| **¿Qué información tiene?** | Customer360 (cliente + visitas + compras + encuesta) |
| **¿Se renderiza cómo?** | SurveyFormWidget (dinámicamente por tipo) |
| **¿Cómo se sincronizan?** | SyncQueueService (online) + BackgroundSync (offline) |

---

**Conclusión**: El sistema trae dinámicamente las encuestas del backend basándose en el ID del cliente, el backend decide cuál mostrar, y la app las cachea localmente para disponibilidad offline. ✅

