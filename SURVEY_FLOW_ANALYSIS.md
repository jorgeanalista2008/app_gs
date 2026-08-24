# 📊 Análisis Detallado: Flujo de Obtención de Encuestas

**Análisis crítico de cómo se obtienen, procesan, cachean y sincronizan las encuestas en la app**

---

## 🎯 Flujo Completo: De A a Z

```
VENDEDOR ABRE DETALLE DE VISITA
    ↓
DetalleVisitaPage._loadDetalle()
    ├─ Carga datos de visita desde SQLite (rápido)
    └─ Llama _loadCustomer360() [background]
         ↓
    SurveyRepository.getCustomer360(customerId)
         ├─ ✅ Obtiene usuario logueado
         ├─ ✅ Obtiene credenciales locales (email + password)
         ├─ ✅ POST /survey/auth/customers/:id/360
         │   └─ Body: {email, password}
         ├─ ✅ Respuesta: Customer360 {
         │      customer: {name, contact, ...}
         │      visitsStats: {totalVisits, lastVisitDate}
         │      profitSummary: {totalPurchases, last30Days}
         │      recommendedSurvey: SurveyPack {
         │         id: UUID,
         │         name: "Encuesta Cliente Nuevo",
         │         packType: "NEW_CUSTOMER",
         │         description: "...",
         │         questions: [SurveyQuestion, ...]
         │      }
         │   }
         ├─ ✅ Cachea pack: cacheSurveyPack(recommendedSurvey)
         │   └─ INSERT cached_survey_packs
         ├─ ✅ Cachea cliente: _cacheCustomer()
         │   └─ INSERT cached_customers
         └─ ✅ Retorna Customer360

    setState(_customer360 = customer360)
         ↓
    build()
         ├─ Renderiza Customer360Card(customer360)
         │   ├─ Avatar + nombre + código
         │   ├─ Contacto (teléfono, email, dirección)
         │   ├─ Estadísticas (visitas, última fecha)
         │   └─ Resumen de compras (USD, últimos 30 días)
         │
         └─ if (customer360.recommendedSurvey != null)
            └─ Renderiza SurveyFormWidget(pack)
                ├─ Muestra nombre + descripción del pack
                ├─ Contador de preguntas
                ├─ Renderiza preguntas por tipo:
                │  ├─ RATING: 1-5 estrellas
                │  ├─ BOOLEAN: Sí/No botones
                │  ├─ TEXT: textarea
                │  └─ MULTIPLE_CHOICE: radio buttons
                └─ Botón "Enviar Encuesta"

USUARIO RESPONDE Y ENVÍA ENCUESTA
    ↓
SurveyFormWidget._submitAnswers()
    ├─ ✅ Valida preguntas requeridas
    ├─ ✅ Convierte answer keys: int → String
    ├─ ✅ SurveyRepository.savePendingAnswer()
    │   ├─ INSERT pending_survey_answers {
    │   │   customer_id: customerId,
    │   │   pack_id: packId,
    │   │   answers: JSON,
    │   │   status: 'PENDING',
    │   │   sync_attempts: 0
    │   │ }
    │   └─ SyncQueueService.enqueue()
    │      └─ POST /salesperson/auth/answers
    │
    └─ Muestra SnackBar "✅ Encuesta guardada localmente"

    SI ONLINE: Sincroniza inmediatamente (SyncQueueService.drain)
    SI OFFLINE: Espera siguiente BackgroundSync (cada 15 min)
         ↓
BACKGROUND SYNC (cada 15 min)
    ↓
BackgroundSyncService._syncSurveyAnswers()
    ├─ SELECT pending_survey_answers WHERE status = PENDING
    ├─ Para cada respuesta:
    │  ├─ Verifica sync_attempts < 5
    │  ├─ SurveyRepository.completeAssignment(assignmentId)
    │  │  └─ POST /survey/auth/assignments/:id/complete
    │  ├─ Si éxito: UPDATE status = SYNCED
    │  └─ Si falla: _scheduleRetry()
    │     └─ Backoff: [30s, 2m, 8m, 30m, 30m]
    └─ Máximo 10 respuestas por ciclo
```

---

## 📋 Detalles Técnicos

### 1. Endpoint: POST /survey/auth/customers/:id/360

**URL**: `{BASE_URL}/survey/auth/customers/{customerId}/360`

**Método**: POST

**Autenticación**: Email + Password (NO JWT)
```dart
body: {
  'email': 'maestro',
  'password': '1234'
}
```

**Respuesta Esperada**:
```json
{
  "customer": {
    "id": "cust-123",
    "name": "Empresa XYZ",
    "code_client_profit": "CLI-001",
    "phone": "0414-1234567",
    "email": "info@empresa.com",
    "address": "Calle Principal 123",
    "latitude": 10.1234,
    "longitude": -66.5678,
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
    "recentPurchases": [
      {
        "fact_num": "FAC-001",
        "amount": "500.00",
        "date": "2026-08-22T10:00:00Z"
      }
    ]
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
        "sort_order": 1,
        "response_options": null
      },
      {
        "id": 2,
        "description": "¿Recomendaría nuestros productos?",
        "type": "BOOLEAN",
        "is_required": 1,
        "sort_order": 2,
        "response_options": null
      }
    ]
  }
}
```

### 2. Estructura del Modelo: Customer360

```dart
class Customer360 {
  final Map<String, dynamic> customer;           // Datos básicos cliente
  final Customer360Contact? contact;              // Contacto (tel, email, dir)
  final Customer360VisitsStats? visitsStats;     // Estadísticas de visitas
  final Customer360ProfitSummary? profitSummary; // Resumen de compras
  final SurveyPack? recommendedSurvey;           // ← ENCUESTA RECOMENDADA
}

class SurveyPack {
  final String id;                   // UUID
  final String name;                 // Nombre legible
  final String packType;             // NEW_CUSTOMER, EXISTING_CUSTOMER, CUSTOM
  final String? description;         // Descripción
  final List<SurveyQuestion> questions; // Lista de preguntas
  final bool isActive;
  final DateTime? createdAt;
}

class SurveyQuestion {
  final int id;                      // ID único
  final String description;          // Texto de la pregunta
  final String questionType;         // RATING, BOOLEAN, TEXT, MULTIPLE_CHOICE
  final List<ResponseOption>? responseOptions; // Para MULTIPLE_CHOICE
  final bool isRequired;
  final int sortOrder;
}

class ResponseOption {
  final int id;
  final String label;
  final String value;
}
```

### 3. Tablas SQLite Creadas (v14)

```sql
-- Packs descargados del servidor
survey_packs (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  pack_type TEXT NOT NULL,
  description TEXT,
  is_active INTEGER,
  questions TEXT (JSON array),
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT
)

-- Preguntas individuales
survey_pack_questions (
  id INTEGER PRIMARY KEY,
  pack_id TEXT FK,
  question_id INTEGER,
  sort_order INTEGER,
  is_required INTEGER,
  UNIQUE(pack_id, question_id)
)

-- Asignaciones a clientes
survey_assignments (
  id INTEGER PRIMARY KEY,
  customer_id TEXT FK,
  pack_id TEXT FK,
  assigned_by_user_id TEXT,
  assigned_at TEXT,
  status TEXT (PENDING|IN_PROGRESS|COMPLETED),
  completed_at TEXT,
  completed_by_user_id TEXT,
  notes TEXT
)

-- Caché local de packs para offline
cached_survey_packs (
  id TEXT PRIMARY KEY,
  name TEXT,
  pack_type TEXT,
  description TEXT,
  questions TEXT (JSON array de SurveyQuestion.toJson()),
  cached_at TEXT (timestamp)
)

-- Caché local de clientes para referencia rápida
cached_customers (
  id TEXT PRIMARY KEY,
  name TEXT,
  code_client_profit TEXT,
  phone TEXT,
  email TEXT,
  address TEXT,
  latitude REAL,
  longitude REAL,
  is_new_customer INTEGER,
  created_at TEXT,
  last_sync_at TEXT
)

-- Respuestas pendientes de sincronización
pending_survey_answers (
  customer_id TEXT FK,
  pack_id TEXT FK,
  assignment_id INTEGER,
  answers TEXT (JSON map),
  status TEXT (PENDING|SYNCED|FAILED),
  created_at TEXT,
  synced_at TEXT,
  sync_attempts INTEGER,
  last_sync_attempt TEXT,
  PRIMARY KEY(customer_id, pack_id, created_at)
)

-- Respuestas que fallaron permanentemente
failed_survey_submissions (
  id INTEGER PRIMARY KEY,
  assignment_id INTEGER,
  customer_id TEXT,
  pack_id TEXT,
  answers TEXT (JSON),
  error_message TEXT,
  attempt_count INTEGER,
  last_attempt_at TEXT,
  next_retry_at TEXT,
  backoff_level INTEGER
)
```

---

## 🔍 Análisis de Puntos Críticos

### ✅ Lo Que Funciona Bien

1. **Obtención Offline-First**
   - SurveyRepository obtiene datos del servidor
   - Automáticamente los cachea en SQLite
   - Si falla obtención, la UI sigue funcionando con cache anterior

2. **Autenticación Doble**
   - Usa credenciales locales (email + password)
   - NO requiere JWT token
   - Perfecto para scenarios donde JWT se expira

3. **Sincronización Robusta**
   - Respuestas se guardan localmente primero
   - SyncQueueService + BackgroundSync garantizan delivery
   - Retry con backoff exponencial [30s, 2m, 8m, 30m, 30m]
   - Máximo 5 intentos por respuesta

4. **Caché Inteligente**
   - Packs cacheados se limpian después 30 días
   - Clientes cacheados se usan como fallback
   - JSON comprimido en SQLite

### ⚠️ Puntos a Revisar

1. **Validación de Respuesta del Servidor**
   ```dart
   final response = await _genericRepo.postOnline<Map<String, dynamic>>(
     path: '/survey/auth/customers/$customerId/360',
     body: {
       'email': username,
       'password': password,
     },
     fromJson: (json) => json,
   );
   
   if (response == null) {
     print('❌ [SurveyRepository] Respuesta nula del servidor');
     return null;  // ← PROBLEMA: no distingue error 404 de timeout
   }
   ```
   **Observación**: Si servidor retorna 404, se silencia. Idealmente debería:
   - Registrar error específico
   - Mostrar mensaje al usuario
   - Ofrecer fallback

2. **Customer360.fromJson() - Falta Validación**
   ```dart
   final customer360 = Customer360.fromJson(response);
   ```
   **Observación**: Si respuesta tiene estructura inesperada, `fromJson()` puede fallar. Debería:
   - Validar estructura esperada
   - Manejar campos faltantes
   - Proporcionar defaults sensatos

3. **Assignment ID Incompleto**
   ```dart
   // En pending_survey_answers no se guarda assignment_id
   // Pero en completeAssignment() se necesita
   ```
   **Observación**: El flujo de assignment_id es confuso:
   - ¿Dónde se obtiene assignment_id?
   - ¿Se retorna en POST /survey/auth/customers/:id/360?
   - ¿Se auto-genera en servidor al completar?

4. **Endpoint para Enviar Respuestas**
   ```dart
   endpoint: '/salesperson/auth/answers',  // ← Este es diferente a:
   // '/survey/auth/assignments/:id/complete'
   ```
   **Observación**: Hay dos endpoints:
   - POST `/salesperson/auth/answers` - Enqueue initial
   - POST `/survey/auth/assignments/:id/complete` - Complete in background
   
   ¿Cuál es la diferencia? ¿Se usan los dos?

5. **Conversión de Question IDs**
   ```dart
   // En SurveyFormWidget, questions tienen id INTEGER
   final answersAsString = answers.map((key, value) => 
     MapEntry(key.toString(), value)  // int → String
   );
   ```
   **Observación**: Conversión int→String trabaja, pero:
   - ¿Por qué el servidor espera String si son INT en modelo?
   - Debería validarse en server
   - O cambiar modelo a String desde inicio

---

## 🚀 Flujo Recomendado Vs Actual

### Actual (Implementado)
```
1. DetalleVisitaPage abre
2. _loadCustomer360() llama POST /survey/auth/customers/:id/360
3. Retorna Customer360 con pack recomendado
4. User responde → savePendingAnswer()
5. Si online: SyncQueueService.drain() → POST /salesperson/auth/answers
6. Si offline: Espera BackgroundSync (15 min) → POST /survey/auth/assignments/:id/complete
```

### Potencial Mejora
```
1. DetalleVisitaPage abre
2. Intentar POST /survey/auth/customers/:id/360
   Si falla (timeout/error): 
   → Mostrar mensaje al usuario
   → Usar cache anterior si existe
   → Ofrecer opción "Reintentar"
3. User responde → savePendingAnswer()
4. Guardar localmente + mostrar status claro:
   "✅ Guardada | ⏳ Sincronizando..."
5. Sincronización clara:
   - Mostrar progreso
   - Indicar próximo sync en 15 min
   - Opción "Sincronizar ahora"
```

---

## 📊 Matriz de Validación

| Aspecto | Status | Detalles |
|---------|--------|----------|
| **Obtención de Encuestas** | ✅ | POST endpoint funciona |
| **Estructura de Datos** | ✅ | Modelos completos |
| **Caché Local** | ✅ | 7 tablas, limpieza automática |
| **Sincronización** | ✅ | 2 endpoints, backoff exponencial |
| **Error Handling** | ⚠️ | Silencia algunos errores |
| **Validación de Respuesta** | ⚠️ | Sin validación de estructura |
| **Assignment ID Flow** | ⚠️ | Confuso en documentación |
| **Endpoint Dualities** | ⚠️ | 2 endpoints, propósito unclear |
| **Type Safety** | ⚠️ | int→String conversión manual |

---

## 🔧 Recomendaciones de Mejora

### 1. Mejorar Error Handling en getCustomer360()
```dart
Future<Customer360?> getCustomer360({required String customerId}) async {
  try {
    // ... validation ...
    
    final response = await _genericRepo.postOnline<Map<String, dynamic>>(
      path: '/survey/auth/customers/$customerId/360',
      body: {'email': username, 'password': password},
      fromJson: (json) => json,
    );

    if (response == null) {
      print('❌ [SurveyRepository] Respuesta nula del servidor');
      // ✅ MEJORAR: Diferencia entre tipos de error
      // - 404: Cliente no existe
      // - 401: Credenciales inválidas
      // - 500: Error servidor
      // - Timeout: Sin conexión
      return null;
    }
    
    // ✅ MEJORAR: Validar estructura esperada
    if (!_isValidCustomer360Response(response)) {
      print('❌ [SurveyRepository] Estructura inválida');
      return null;
    }
    
    final customer360 = Customer360.fromJson(response);
    // ...
  }
}

bool _isValidCustomer360Response(Map<String, dynamic> response) {
  // Verificar campos obligatorios
  return response['customer'] != null &&
         response['customer']['id'] != null &&
         response['customer']['name'] != null;
}
```

### 2. Clarificar Assignment ID Flow
```dart
// En respuesta de POST /survey/auth/customers/:id/360:
// ¿Retorna assignment_id? 
// Ejemplo:
{
  "customer": {...},
  "visitsStats": {...},
  "profitSummary": {...},
  "recommendedSurvey": {...},
  "assignmentId": 12345  // ← ¿Se retorna aquí?
}
```

### 3. Unificar Endpoints
Clarificar diferencia entre:
- `POST /salesperson/auth/answers` - Initial submit
- `POST /survey/auth/assignments/:id/complete` - Final confirmation

¿Uno reemplaza al otro? ¿Se ejecutan en orden?

### 4. Type Safety: Question IDs
```dart
// Cambiar SurveyQuestion.id de int a String
// O cambiar answers map para mantener int

class SurveyQuestion {
  final String id;  // ← Cambiar de int a String
  // ...
}
```

---

## 📝 Conclusión del Análisis

✅ **Arquitectura**: Sólida y offline-first

⚠️ **Puntos de Mejora**:
1. Error handling más específico
2. Validación de estructura de respuesta
3. Clarificar flujo de assignment_id
4. Documentar propósito de cada endpoint
5. Mejorar type safety (int vs String para IDs)

✅ **Está Listo Para**:
- Testing E2E
- Staging deployment
- Production (con mejoras recomendadas)

---

**Documento Generado**: 2026-08-24
**Análisis Completo**: ✅
