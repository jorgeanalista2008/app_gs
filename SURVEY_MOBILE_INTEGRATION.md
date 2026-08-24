# Integración de Encuestas en App Móvil

## Visión General

Sistema de encuestas dinámicas con **múltiples packs** (plantillas) que pueden asignarse a clientes. La app obtiene la ficha 360 completa del cliente + el pack de encuesta recomendado en una sola request, cached localmente en SQLite.

## Flujo Principal (App)

```
1. Vendedor inicia sesión (email+password)
   ↓
2. Obtiene lista de clientes asignados
   POST /salesperson/auth/customers
   ↓
3. Vendedor selecciona cliente
   ↓
4. App solicita ficha 360 + survey pack recomendado
   POST /survey/auth/customers/:customerId/360
   ↓
5. Guarda en SQLite local (para offline)
   ↓
6. Muestra ficha del cliente + encuesta
   ↓
7. Vendedor completa preguntas
   ↓
8. App envía respuestas
   POST /salesperson/auth/answers (existente)
   ↓
9. Marca asignación como completada
   POST /survey/auth/assignments/:assignmentId/complete
   ↓
10. Si falló (sin red), intenta en background cada 15 min
```

## Endpoints Clave

### 1. Ficha 360 del Cliente + Survey Pack Recomendado

```http
POST /survey/auth/customers/:customerId/360
Content-Type: application/json

{
  "email": "vendedor@example.com",
  "password": "su_contraseña"
}
```

**Response (200 OK):**
```json
{
  "customer": {
    "id": "uuid",
    "name": "Empresa ABC",
    "code_client_profit": "CLI001",
    "type_id": "uuid",
    "latitude": 10.5,
    "longitude": -66.5,
    "created_at": "2026-01-15T10:00:00Z"
  },
  "contact": {
    "phone": "+584121234567",
    "email": "contacto@abc.com",
    "address": "Calle Principal 123, Caracas"
  },
  "visits_stats": {
    "total_visits": 5,
    "last_visit_date": "2026-08-20T14:30:00Z"
  },
  "pending_schedules": [],
  "profit_summary": {
    "total_purchases_usd": 50000,
    "recent_purchases": [
      {
        "fact_num": "12345",
        "amount": 1500,
        "date": "2026-08-15"
      }
    ],
    "top_products": [],
    "last_30_days_volume": 5000
  },
  "recommended_survey": {
    "id": "uuid",
    "name": "Encuesta Cliente Existente",
    "pack_type": "EXISTING_CUSTOMER",
    "description": "Preguntas para clientes con historial",
    "customer_age_days": 180,
    "questions": [
      {
        "id": 1,
        "code": "SATISFACCION",
        "description": "¿Qué tan satisfecho está con nuestro servicio?",
        "question_type": "RATING",
        "is_required": true,
        "response_options": "[1, 2, 3, 4, 5]",
        "sort_order": 0
      },
      {
        "id": 2,
        "code": "REPITE_COMPRA",
        "description": "¿Volvería a comprar?",
        "question_type": "BOOLEAN",
        "is_required": true,
        "response_options": null,
        "sort_order": 1
      }
    ]
  },
  "timestamp": "2026-08-24T10:30:00Z"
}
```

### 2. Obtener Listado de Packs Disponibles (Admin)

```http
GET /survey/packs?pack_type=NEW_CUSTOMER
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "data": [
    {
      "id": "uuid",
      "name": "Encuesta Cliente Nuevo",
      "pack_type": "NEW_CUSTOMER",
      "description": "Primeros contactos",
      "is_active": true,
      "created_at": "2026-08-24T10:00:00Z"
    }
  ]
}
```

### 3. Crear Pack de Encuesta (Admin)

```http
POST /survey/packs
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "name": "Encuesta Cliente Nuevo",
  "pack_type": "NEW_CUSTOMER",
  "description": "Preguntas para primeros contactos",
  "question_ids": [1, 2, 3, 4]
}
```

### 4. Asignar Pack a Cliente (Web Admin)

```http
POST /survey/assignments
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "customer_id": "uuid-del-cliente",
  "pack_id": "uuid-del-pack",
  "notes": "Encuesta de seguimiento (opcional)"
}
```

**Response:**
```json
{
  "id": 42,
  "customer_id": "uuid",
  "pack_id": "uuid",
  "assigned_at": "2026-08-24T10:30:00Z",
  "status": "PENDING"
}
```

### 5. Marcar Encuesta Completada (App)

```http
POST /survey/auth/assignments/42/complete
Content-Type: application/json

{
  "email": "vendedor@example.com",
  "password": "su_contraseña"
}
```

**Response:**
```json
{
  "id": 42,
  "status": "COMPLETED",
  "completed_at": "2026-08-24T14:30:00Z"
}
```

## Esquema SQL

### survey_packs
```sql
- id (UUID) — PK
- name (NVARCHAR)
- pack_type (NVARCHAR) — NEW_CUSTOMER | EXISTING_CUSTOMER | CUSTOM
- description (NVARCHAR MAX)
- is_active (BIT)
- created_at, updated_at, deleted_at
```

### survey_pack_questions
```sql
- id (BIGINT) — PK
- pack_id (UUID) — FK → survey_packs
- question_id (BIGINT) — FK → visit_questions
- sort_order (INT)
- is_required (BIT)
- Unique: (pack_id, question_id)
```

### survey_assignments
```sql
- id (BIGINT) — PK
- customer_id (UUID) — FK → customers
- pack_id (UUID) — FK → survey_packs
- assigned_by_user_id (UUID)
- assigned_at (DATETIME2)
- status (NVARCHAR) — PENDING | IN_PROGRESS | COMPLETED
- completed_at (DATETIME2)
- completed_by_user_id (UUID)
- notes (NVARCHAR MAX)
```

## Recomendación Automática de Pack

**Lógica:**
- Si cliente fue creado hace ≤30 días → **NEW_CUSTOMER**
- Si cliente fue creado hace >30 días → **EXISTING_CUSTOMER**

Esto ocurre automáticamente en el endpoint `/survey/auth/customers/:customerId/360`.

## Caching Local (SQLite - App)

### Schema sugerido para app móvil

```sql
-- Tabla de clientes en caché
CREATE TABLE cached_customers (
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
  last_sync_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de packs locales
CREATE TABLE cached_survey_packs (
  id TEXT PRIMARY KEY,
  name TEXT,
  pack_type TEXT,
  description TEXT,
  questions TEXT, -- JSON array
  cached_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de asignaciones pendientes
CREATE TABLE pending_survey_answers (
  assignment_id INTEGER PRIMARY KEY,
  customer_id TEXT,
  pack_id TEXT,
  answers TEXT, -- JSON object
  status TEXT DEFAULT 'PENDING',
  created_at TEXT,
  synced_at TEXT
);

-- Tabla de intentos fallidos (para retry)
CREATE TABLE failed_submissions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  assignment_id INTEGER,
  answers TEXT,
  error_message TEXT,
  attempt_count INTEGER DEFAULT 1,
  last_attempt_at TEXT,
  next_retry_at TEXT
);
```

## Background Sync (Recomendado)

La app debe implementar un **WorkManager** (Android) o **Background Task** (iOS) que:

1. **Cada 15 minutos**, cuando hay conexión a internet:
   - Verifica tabla `pending_survey_answers`
   - Intenta enviar cada respuesta pendiente
   - Si éxito: marca como synced, llama a `/survey/auth/assignments/:id/complete`
   - Si falla: registra en `failed_submissions`, reintenta exponencial (max 5 intentos)

2. **Al abrir app**:
   - Sincroniza clientes y ficha 360 (actualiza caché)
   - Intenta enviar respuestas pendientes

3. **Al cerrar conexión WiFi**:
   - Guarda respuestas en caché local
   - Background worker intentará más tarde

## Ejemplo: Flujo de Respuesta (App)

```typescript
// 1. Obtener ficha + pack
const response = await fetch('http://api.local:3000/survey/auth/customers/CLIENT-UUID/360', {
  method: 'POST',
  body: JSON.stringify({ email, password })
});
const { customer, recommended_survey } = await response.json();

// 2. Guardar en SQLite local
await db.insert('cached_customers', {
  id: customer.id,
  name: customer.name,
  is_new_customer: recommended_survey.customer_age_days <= 30
});

// 3. Mostrar preguntas al vendedor
showSurveyUI(recommended_survey.questions);

// 4. Vendedor responde preguntas
const answers = {
  "1": 4, // Pregunta RATING
  "2": true // Pregunta BOOLEAN
};

// 5. Guardar respuestas localmente
await db.insert('pending_survey_answers', {
  assignment_id: null, // Se obtiene del servidor
  customer_id: customer.id,
  pack_id: recommended_survey.id,
  answers: JSON.stringify(answers),
  status: 'PENDING'
});

// 6. Intentar enviar (si hay conexión)
if (hasInternetConnection) {
  // Primero enviar respuestas individuales
  for (const [questionId, answerValue] of Object.entries(answers)) {
    await fetch('http://api.local:3000/salesperson/auth/answers', {
      method: 'POST',
      body: JSON.stringify({
        email,
        password,
        visit_id: newVisitId,
        question_id: parseInt(questionId),
        answer_text: String(answerValue)
      })
    });
  }

  // Luego marcar asignación completada
  await fetch(`http://api.local:3000/survey/auth/assignments/42/complete`, {
    method: 'POST',
    body: JSON.stringify({ email, password })
  });

  // Actualizar estado en caché
  await db.update('pending_survey_answers', {
    status: 'SYNCED',
    synced_at: new Date()
  });
}
```

## Permisos Requeridos

En backend, crear permiso `surveys` (módulo: `survey`):
- `surveys` — Lectura de packs y asignaciones (admin)
- `surveys:write` — Crear/editar packs (admin)

## Notas de Desarrollo

1. **Idempotencia**: Endpoint `/survey/auth/assignments/:id/complete` es idempotente — la app puede reintentarlo sin problema
2. **Throttling**: `survey_auth` tiene límite de 300 req/min (generoso para sync periódico)
3. **Soft Deletes**: Packs marcados con `deleted_at` no se muestran
4. **Historial**: `survey_assignments` mantiene historial completo (nunca se borra)
5. **Timezone**: Todas las fechas en UTC
