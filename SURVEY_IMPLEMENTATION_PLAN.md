# Plan de Implementación: Sistema de Encuestas con Survey Packs

**Fecha**: 2026-08-24  
**Estado**: Análisis Completo  
**Prioridad**: 🔴 CRÍTICA (Requerido antes de producción)

---

## 📋 RESUMEN EJECUTIVO

La app actual tiene un sistema básico de encuestas offline-first, pero **falta la integración con Survey Packs** del backend. Se necesita:

1. **4 nuevos modelos** para representar packs y asignaciones
2. **5 nuevas tablas SQLite** para caché y sincronización
3. **Nuevo repositorio** (SurveyRepository) para manejar el flujo 360+surveys
4. **Widgets nuevos** para mostrar encuestas dinámicas
5. **Sincronización en background** con retry exponencial

---

## 🔍 ANÁLISIS ACTUAL DE LA APP

### ✅ Lo Que YA Existe (y Funciona)

| Componente | Ubicación | Estado | Notas |
|-----------|-----------|--------|-------|
| **Tablas base** | `database_helper.dart` | ✅ Funcional | `encuestas`, `preguntas`, `respuestas_pendientes`, `encuestas_visita` |
| **Modelos** | `lib/models/` | ✅ Funcional | `EncuestaModel`, `PreguntaModel`, `PreguntaOption` |
| **EncuestaRepository** | `lib/repositories/` | ✅ Funcional | Métodos: `getEncuesta()`, `getPlantillaEncuesta()`, `getRespuestas()` |
| **GenericRepository** | `lib/repositories/` | ✅ Funcional | `postOnline()`, `getListOnline()`, `executeRequest()` |
| **SyncService** | `lib/services/` | ✅ Funcional | Autenticación, sincronización offline-first |
| **SyncQueueService** | `lib/services/` | ✅ Funcional | Cola de operaciones con retry exponencial |
| **AuthService** | `lib/services/` | ✅ Funcional | Login local + token JWT |
| **Integración en UI** | `detalle_visita_page.dart`, `encuesta_page.dart` | ✅ Funcional | Mostrar preguntas y respuestas |

### ❌ Lo Que FALTA (Crítico)

| Componente | Necesario | Impacto | Motivo |
|-----------|-----------|--------|--------|
| **SurveyRepository** | 🆕 NUEVO | 🔴 CRÍTICO | Obtener ficha 360 + pack recomendado |
| **Modelos Survey** | 🆕 NUEVO (4) | 🔴 CRÍTICO | Representar packs y asignaciones |
| **Tablas SQLite** | 🆕 NUEVO (5) | 🔴 CRÍTICO | Caché local y sincronización |
| **SurveyForm Widget** | 🆕 NUEVO | 🟡 ALTA | Mostrar formulario dinámico |
| **Customer360 Card** | 🆕 NUEVO | 🟡 ALTA | Ficha 360 del cliente |
| **Background Sync** | ✏️ MODIFICAR | 🟡 ALTA | Retry automático de encuestas |
| **DetalleVisita Page** | ✏️ MODIFICAR | 🟡 ALTA | Integrar ficha 360 + encuesta |

---

## 🏗️ ESTRUCTURA DE CAMBIOS POR CATEGORÍA

### **1️⃣ NUEVOS MODELOS (lib/models/)**

```
├── survey_pack_model.dart           🆕 CREAR
│   ├── SurveyPack (UUID, name, packType, description, questions[], isActive)
│
├── survey_question_model.dart       🆕 CREAR (extiende PreguntaModel)
│   ├── SurveyQuestion (id, code, description, questionType, responseOptions, sortOrder)
│
├── customer_360_model.dart          🆕 CREAR
│   ├── Customer360 (customer, contact, visitsStats, profitSummary, recommendedSurvey, timestamp)
│
└── survey_assignment_model.dart     🆕 CREAR
    ├── SurveyAssignment (id, customerId, packId, status, answers, assignedAt, completedAt)
```

**Decisión de diseño**: `SurveyQuestion` puede reutilizar lógica de `PreguntaModel` o crear uno nuevo.  
**Recomendación**: Crear nuevo para mantener separación clara entre encuestas locales y survey packs del backend.

---

### **2️⃣ NUEVAS TABLAS SQLite (database_helper.dart)**

#### **Tablas Backend Sync** (migración v10 → v11)

```sql
-- 1. Survey Packs desde backend
CREATE TABLE survey_packs (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  pack_type TEXT NOT NULL,           -- NEW_CUSTOMER | EXISTING_CUSTOMER | CUSTOM
  description TEXT,
  is_active INTEGER DEFAULT 1,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT                    -- soft delete
);

-- 2. Preguntas dentro de packs
CREATE TABLE survey_pack_questions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pack_id TEXT NOT NULL,
  question_id INTEGER NOT NULL,       -- FK a visita_questions (backend)
  sort_order INTEGER DEFAULT 0,
  is_required INTEGER DEFAULT 1,
  FOREIGN KEY (pack_id) REFERENCES survey_packs(id),
  UNIQUE (pack_id, question_id)
);

-- 3. Asignaciones de packs a clientes
CREATE TABLE survey_assignments (
  id INTEGER PRIMARY KEY,             -- NO autoincrement, viene del servidor
  customer_id TEXT NOT NULL,
  pack_id TEXT NOT NULL,
  assigned_by_user_id TEXT,
  assigned_at TEXT,
  status TEXT DEFAULT 'PENDING',      -- PENDING | IN_PROGRESS | COMPLETED
  completed_at TEXT,
  completed_by_user_id TEXT,
  notes TEXT,
  FOREIGN KEY (pack_id) REFERENCES survey_packs(id),
  FOREIGN KEY (customer_id) REFERENCES clientes(id)
);
```

#### **Tablas Caché Local** (migración v10 → v11)

```sql
-- 4. Caché de datos 360 del cliente
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
  last_sync_at TEXT,
  FOREIGN KEY (id) REFERENCES clientes(id)
);

-- 5. Caché de packs descargados
CREATE TABLE cached_survey_packs (
  id TEXT PRIMARY KEY,
  name TEXT,
  pack_type TEXT,
  description TEXT,
  questions TEXT,                      -- JSON array
  cached_at TEXT
);

-- 6. Respuestas pendientes de sincronizar (POR PACK)
CREATE TABLE pending_survey_answers (
  assignment_id INTEGER,               -- nullable si aún no se asignó
  customer_id TEXT NOT NULL,
  pack_id TEXT NOT NULL,
  answers TEXT NOT NULL,               -- JSON object: {question_id: answer_value}
  status TEXT DEFAULT 'PENDING',       -- PENDING | SYNCED | FAILED
  created_at TEXT NOT NULL,
  synced_at TEXT,
  last_sync_attempt TEXT,
  sync_attempts INTEGER DEFAULT 0,
  PRIMARY KEY (customer_id, pack_id, created_at),
  FOREIGN KEY (customer_id) REFERENCES clientes(id),
  FOREIGN KEY (pack_id) REFERENCES survey_packs(id)
);

-- 7. Intentos fallidos (para retry con backoff exponencial)
CREATE TABLE failed_survey_submissions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  assignment_id INTEGER,
  customer_id TEXT,
  answers TEXT,                        -- JSON de respuestas fallidas
  error_message TEXT,
  attempt_count INTEGER DEFAULT 0,
  last_attempt_at TEXT,
  next_retry_at TEXT,
  backoff_level INTEGER DEFAULT 0,     -- 0-4 para [30s, 2m, 8m, 30m, 30m]
  FOREIGN KEY (customer_id) REFERENCES clientes(id)
);
```

**Índices recomendados**:
```sql
CREATE INDEX idx_survey_packs_active ON survey_packs(is_active, deleted_at);
CREATE INDEX idx_survey_assignments_status ON survey_assignments(status, customer_id);
CREATE INDEX idx_pending_answers_status ON pending_survey_answers(status, customer_id);
CREATE INDEX idx_failed_submissions_retry ON failed_survey_submissions(next_retry_at, attempt_count);
CREATE INDEX idx_cached_survey_packs_type ON cached_survey_packs(pack_type);
```

---

### **3️⃣ NUEVO REPOSITORIO (lib/repositories/survey_repository.dart)**

```dart
class SurveyRepository {
  // Métodos clave necesarios:
  
  // 1. Obtener ficha 360 + pack recomendado (ENDPOINT CRÍTICO)
  Future<Customer360?> getCustomer360({
    required String customerId,
  })
  
  // 2. Guardar pack en caché local
  Future<void> cacheSurveyPack(SurveyPack pack)
  
  // 3. Guardar respuesta pendiente
  Future<void> savePendingAnswer({
    required String customerId,
    required String packId,
    required Map<String, dynamic> answers,
  })
  
  // 4. Enviar respuestas al backend
  Future<bool> completeAssignment(int assignmentId)
  
  // 5. Obtener respuestas pendientes (para retry)
  Future<List<Map<String, dynamic>>> getPendingAnswers()
  
  // 6. Registrar fallo + siguiente retry
  Future<void> scheduleRetry(...)
  
  // 7. Limpiar caché de packs viejos
  Future<void> purgeCachedPacks()
}
```

---

### **4️⃣ MODIFICACIONES A REPOSITORIOS EXISTENTES**

#### **EncuestaRepository** (`lib/repositories/encuesta_repository.dart`)

**Agregar métodos**:
```dart
// Sincronizar respuestas pendientes
Future<void> syncPendingAnswers()

// Obtener survey packs disponibles
Future<List<SurveyPack>> getSurveyPacks({String? packType})

// Marcar encuesta como completada en backend
Future<bool> markAssignmentComplete(int assignmentId)
```

**Mantener métodos existentes** (sin cambios):
- `getEncuesta(visitaId)`
- `getPlantillaEncuesta(plantillaId, visitaId)`
- `getRespuestas(visitaId)`
- `saveRespuesta(...)`

---

### **5️⃣ NUEVOS WIDGETS (lib/organisms/ y lib/molecules/)**

#### **SurveyFormWidget** (`lib/organisms/survey_form_widget.dart`)
```
Responsabilidades:
- Renderizar preguntas dinámicamente según tipo (RATING, BOOLEAN, TEXT, etc)
- Capturar respuestas del usuario
- Guardar localmente en pending_survey_answers
- Intentar sincronizar si hay conexión
- Mostrar errores y estado de sincronización
```

#### **Customer360Card** (`lib/molecules/customer_360_card.dart`)
```
Responsabilidades:
- Mostrar datos del cliente (nombre, contacto, dirección)
- Stats de visitas (total, última fecha)
- Resumen de compras (USD, últimos 30 días)
- Productos top
- Encuesta recomendada (si aplica)
```

---

### **6️⃣ MODIFICACIONES A PÁGINAS**

#### **DetalleVisitaPage** (`lib/pages/detalle_visita_page.dart`)

**Cambios**:
1. Cargar ficha 360 desde `SurveyRepository.getCustomer360()`
2. Si existe `recommendedSurvey`, mostrar `SurveyFormWidget`
3. Mostrar `Customer360Card` con datos del cliente
4. Capturar respuestas y guardar en BD local

**Flujo nuevo**:
```
1. Usuario abre visita
   ↓
2. App obtiene ficha 360 (con recomendación de pack)
   ↓
3. Si hay internet: carga pack desde servidor
   Si no: carga desde caché local
   ↓
4. Muestra ficha + formulario
   ↓
5. Usuario responde
   ↓
6. Guarda localmente
   ↓
7. Si hay conexión: sincroniza automáticamente
   Si no: queda pendiente para sync en background
```

---

### **7️⃣ MODIFICACIONES A SERVICIOS**

#### **BackgroundSyncService** (`lib/services/background_sync_service.dart`)

**Agregar método**:
```dart
Future<void> syncSurveyAnswers() async {
  // 1. Obtener respuestas pendientes
  // 2. Para cada respuesta:
  //    a. Enviar a /salesperson/auth/answers
  //    b. Si éxito: marcar como SYNCED
  //    c. Si falla: registrar en failed_submissions + calcular próximo retry
  // 3. Reintento con backoff: [30s, 2m, 8m, 30m, 30m]
  // 4. Máximo 5 intentos
}
```

**Integración**:
- Llamar cada 15 minutos (WorkManager)
- Llamar al abrir app
- Llamar cuando vuelve conexión WiFi

---

## 📊 COMPARATIVA: ANTES vs DESPUÉS

### **Antes (Estado Actual)**

| Aspecto | Implementación |
|---------|----------------|
| **Encuestas** | Offline-only, plantillas locales |
| **Flujo** | Vendedor crea respuestas → Sincroniza manual |
| **Backend** | `/salesperson/auth/answers` (respuestas simples) |
| **Recomendación** | Manual (admin asigna) |
| **Caché** | Solo respuestas pendientes |
| **Retry** | Genérico (SyncQueueService) |

### **Después (Con Survey Packs)**

| Aspecto | Implementación |
|---------|----------------|
| **Encuestas** | Packs dinámicos del backend + offline cache |
| **Flujo** | Solicita ficha 360 → Descarga pack recomendado → Responde → Auto-sync |
| **Backend** | `/survey/auth/customers/:id/360` (ficha completa) |
| **Recomendación** | Automática según antigüedad cliente |
| **Caché** | Clientes, packs, respuestas, intentos fallidos |
| **Retry** | Exponencial específico para encuestas |

---

## 🎯 ORDEN DE IMPLEMENTACIÓN (RECOMENDADO)

### **Fase 1: Datos (CRÍTICA)** ⏱️ ~4 horas
1. ✅ Crear modelos (4 nuevos)
2. ✅ Crear tablas SQLite (5 nuevas + índices)
3. ✅ Crear SurveyRepository (métodos CRUD)

### **Fase 2: Interfaz (ALTA)** ⏱️ ~3 horas
4. ✅ Crear SurveyFormWidget
5. ✅ Crear Customer360Card
6. ✅ Integrar en DetalleVisitaPage

### **Fase 3: Sincronización (ALTA)** ⏱️ ~2 horas
7. ✅ Modificar BackgroundSyncService (retry logic)
8. ✅ Modificar EncuestaRepository (sync methods)
9. ✅ Testing del flujo offline → online

### **Fase 4: Pulido (MEDIA)** ⏱️ ~1 hora
10. ✅ Testing E2E
11. ✅ Manejo de errores
12. ✅ Logging para debugging

---

## ⚠️ PUNTOS CRÍTICOS A CONSIDERAR

### **1. Identificadores (UUID vs Integer)**

**Problema**: Backend usa UUIDs para packs, SQLite usa INTEGER para algunas tablas.

**Solución**:
- `survey_packs.id` → TEXT (UUID)
- `survey_pack_questions.id` → INTEGER (autoincrement local)
- `survey_assignments.id` → INTEGER (viene del servidor)
- Usar `id_mapping` table para mapear UUIDs ↔ IDs locales

### **2. Autenticación en Endpoints**

**Problema**: `/survey/auth/customers/:id/360` usa email+password (NO JWT)

**Solución**:
- Guardar credenciales locales en `AuthService`
- Recuperar usuario/contraseña en SQLite para requests
- Nunca guardar credenciales en SharedPreferences

### **3. Datos Sincronizados vs Caché**

**Problema**: Diferenciar entre datos del servidor y caché local

**Solución**:
```
survey_packs → Tabla principal (datos del servidor)
cached_survey_packs → Caché local (copia de seguridad)
pending_survey_answers → Respuestas NO sincronizadas
```

### **4. Conflictos de Transacción**

**Problema**: Si dos operaciones intentan sincronizar respuestas simultáneamente

**Solución**:
- Usar transacciones SQLite en métodos de sync
- Flag `status = 'IN_PROGRESS'` durante sync
- Rollback si falla

### **5. Limpieza de Caché**

**Problema**: Tablas cache puede crecer indefinidamente

**Solución**:
- Limpiar packs no usados hace >30 días
- Limpiar respuestas sincronizadas hace >7 días
- Ejecutar al iniciar app o semanalmente

---

## 🔗 DEPENDENCIAS ENTRE COMPONENTES

```
DetalleVisitaPage
    ↓
    ├─→ SurveyRepository (obtener 360)
    │      ↓
    │      ├─→ GenericRepository.postOnline()
    │      └─→ DatabaseHelper (guardar caché)
    │
    ├─→ SurveyFormWidget (mostrar preguntas)
    │      ↓
    │      ├─→ SurveyRepository (guardar respuestas)
    │      └─→ SyncQueueService (encolar si hay red)
    │
    └─→ Customer360Card (mostrar ficha)
           ↓
           └─→ DatabaseHelper (leer caché)

BackgroundSyncService
    ↓
    ├─→ SurveyRepository (obtener pendientes)
    ├─→ EncuestaRepository (sincronizar)
    └─→ DatabaseHelper (actualizar estado)
```

---

## 📝 CHECKLIST DE IMPLEMENTACIÓN

### Modelos
- [ ] Crear `survey_pack_model.dart`
- [ ] Crear `survey_question_model.dart`
- [ ] Crear `customer_360_model.dart`
- [ ] Crear `survey_assignment_model.dart`

### Base de Datos
- [ ] Crear migración v10 → v11 en `database_helper.dart`
- [ ] Agregar tablas de packs
- [ ] Agregar tablas de caché
- [ ] Agregar índices
- [ ] Versión actualizada a 11

### Repositorios
- [ ] Crear `survey_repository.dart` (nuevo)
- [ ] Método `getCustomer360()`
- [ ] Método `cacheSurveyPack()`
- [ ] Método `savePendingAnswer()`
- [ ] Método `completeAssignment()`
- [ ] Método `getPendingAnswers()`
- [ ] Modificar `encuesta_repository.dart`
- [ ] Agregar `syncPendingAnswers()`
- [ ] Agregar `getSurveyPacks()`
- [ ] Agregar `markAssignmentComplete()`

### Widgets
- [ ] Crear `survey_form_widget.dart`
- [ ] Renderizar preguntas dinámicamente
- [ ] Capturar respuestas
- [ ] Guardar en BD
- [ ] Mostrar estado de sincronización
- [ ] Crear `customer_360_card.dart`
- [ ] Mostrar datos 360
- [ ] Mostrar stats de visitas
- [ ] Mostrar profit summary

### Páginas
- [ ] Modificar `detalle_visita_page.dart`
- [ ] Cargar ficha 360
- [ ] Integrar SurveyFormWidget
- [ ] Integrar Customer360Card
- [ ] Manejo de errores

### Servicios
- [ ] Modificar `background_sync_service.dart`
- [ ] Agregar `syncSurveyAnswers()`
- [ ] Implementar retry exponencial
- [ ] Integrar en WorkManager (Android)

### Testing
- [ ] Test unitarios (modelos)
- [ ] Test integración (repositorios)
- [ ] Test E2E (flujo completo)
- [ ] Testing offline → online
- [ ] Testing de retry

---

## 🚀 PRÓXIMOS PASOS

1. **Revisar este análisis** ← 👈 YOU ARE HERE
2. **Validar cambios** con el equipo backend
3. **Iniciar Fase 1** (modelos + BD)
4. **Crear PR** con cambios de estructura
5. **Testing** offline-first
6. **Deploy** a staging
7. **QA** en dispositivos reales
8. **Deploy** a producción

---

## 📚 Documentación Relacionada

- `SURVEY_SETUP.md` — Guía de configuración del sistema
- `SURVEY_MOBILE_INTEGRATION.md` — Especificación de endpoints
- `CLAUDE.md` — Arquitectura general de la app
- `README.md` — Instrucciones de compilación

