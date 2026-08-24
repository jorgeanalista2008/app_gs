# 🧪 Fase 4: Testing E2E - Survey Packs

**Documento de validación completa del feature de encuestas offline-first con sincronización automática.**

---

## 📋 Tabla de Contenidos

1. [Setup de Testing](#setup-de-testing)
2. [Test Casos - Flujo Principal](#test-casos---flujo-principal)
3. [Test Casos - Manejo de Errores](#test-casos---manejo-de-errores)
4. [Test Casos - Sincronización Background](#test-casos---sincronización-background)
5. [Checklist de Validación](#checklist-de-validación)

---

## 🔧 Setup de Testing

### Requisitos Previos

```bash
# 1. Compilación sin errores
flutter analyze --no-pub
# ✅ Esperado: 0 errores (solo warnings sobre print)

# 2. Dependencias instaladas
flutter pub get
# ✅ Esperado: "Got dependencies!"

# 3. Base de datos actualizada
# ✅ DatabaseHelper.version = 14
# ✅ Tablas creadas: survey_packs, pending_survey_answers, etc.

# 4. Permisos Android
# ✅ AndroidManifest.xml: INTERNET, ACCESS_FINE_LOCATION
# ✅ iOS Info.plist: NSLocationWhenInUseUsageDescription
```

### Testear en Dispositivo Real (Recomendado)

```bash
# Obtener lista de dispositivos
flutter devices

# Ejecutar en un dispositivo específico
flutter run -d <device-id>

# O ejecutar en el emulador
flutter run -d emulator-5554
```

---

## ✅ Test Casos - Flujo Principal

### TC-01: Login y Acceso a Cliente

**Objetivo**: Verificar que la app permite login y acceso a clientes

**Pasos**:
1. Iniciar app
2. Login con vendedor (`maestro` / `1234`)
3. Ir a **Clientes**
4. Seleccionar un cliente de la lista

**Resultado Esperado**:
```
✅ Login exitoso
✅ Lista de clientes visible
✅ Detalles del cliente se cargan
✅ No hay errores en consola
```

**Logs Esperados** (console output):
```
🔐 [AuthService] Validando credenciales...
✅ [AuthService] Login exitoso: maestro
📋 [ClienteRepository] Obteniendo clientes...
✅ [ClienteRepository] Clientes obtenidos: N
```

---

### TC-02: Obtener Ficha 360 + Encuesta Recomendada

**Objetivo**: Verificar que se obtiene la ficha completa del cliente con encuesta

**Precondiciones**:
- ✅ Usuario logueado
- ✅ Cliente seleccionado
- ✅ Hay conexión a internet

**Pasos**:
1. Desde detalles de cliente, ir a **Detalles de Visita**
2. Esperar a que cargue ficha 360
3. Verificar que se muestra:
   - Avatar y nombre del cliente
   - Información de contacto (teléfono, email, dirección)
   - Estadísticas de visitas
   - Resumen de compras (últimos 30 días, total)
   - **Formulario de encuesta recomendada**

**Resultado Esperado**:
```
✅ Customer360Card se renderiza completa
✅ SurveyFormWidget se muestra si hay pack recomendado
✅ Todas las secciones tienen datos válidos
✅ Imágenes y avatares cargan correctamente
```

**Logs Esperados**:
```
📡 [SurveyRepository] Solicitando ficha 360 para <customerId>...
📡 [GenericRepository] POST /survey/auth/customers/<customerId>/360
✅ [SurveyRepository] Ficha 360 obtenida: <customer_name>
💾 [SurveyRepository] Pack <pack_id> cacheado
```

---

### TC-03: Responder Encuesta Completa (Online)

**Objetivo**: Verificar que se puede responder encuesta y sincronizar inmediatamente

**Precondiciones**:
- ✅ Ficha 360 cargada con encuesta
- ✅ Hay conexión a internet (indicador verde)
- ✅ Encuesta tiene 3-5 preguntas de diferentes tipos

**Pasos**:
1. Responder TODAS las preguntas:
   - **RATING**: Seleccionar estrella (1-5)
   - **BOOLEAN**: Seleccionar Sí/No
   - **MULTIPLE_CHOICE**: Seleccionar una opción
   - **TEXT**: Escribir texto
2. Verificar validación de preguntas requeridas
3. Hacer clic en **"Enviar Encuesta"**
4. Esperar confirmación

**Validación Intermedia**:
- ✅ Todas las preguntas requeridas tienen indicador `*`
- ✅ El botón "Enviar" está deshabilitado hasta responder todas requeridas
- ✅ Se muestra spinner mientras se envía

**Resultado Esperado**:
```
✅ Se muestra: "✅ Encuesta guardada localmente"
✅ Se muestra: "📤 Encuesta enviada al servidor"
✅ Formulario se limpia o desaparece
✅ SnackBar de éxito visible por 4 segundos
```

**Logs Esperados**:
```
📝 [SurveyRepository] Respuesta guardada: <customer_id> / <pack_id>
📝 [SurveyRepository] Encolando para sincronización...
📤 [SyncQueueService] Encolado: survey_answer / <id>
✅ [BackgroundSync] Encuesta sincronizada: <customer_id>
```

---

### TC-04: Responder Encuesta Incompleta (Validación)

**Objetivo**: Verificar que no permite enviar sin responder preguntas requeridas

**Pasos**:
1. Mostrar formulario con encuesta
2. Responder SOLO algunas preguntas (dejar algunas en blanco)
3. Hacer clic en **"Enviar Encuesta"**

**Resultado Esperado**:
```
❌ Se muestra error: "❌ Debes responder 2 pregunta(s) requerida(s)"
❌ Formulario NO se envía
❌ Datos NO se guardan
✅ Usuario puede corregir y reintentar
```

**Logs Esperados**:
```
⚠️  [SurveyFormWidget] Validación fallida: faltan respuestas requeridas
```

---

### TC-05: Responder Encuesta Offline

**Objetivo**: Verificar que se guarda localmente sin internet

**Precondiciones**:
- ✅ **Desactivar internet** (Wi-Fi + Datos móviles OFF)
- ✅ Ficha 360 ya cargada (de TC-02)

**Pasos**:
1. Responder encuesta completamente
2. Verificar indicador **"Sin conexión"** (banner naranja)
3. Botón muestra **"Guardar Encuesta"** (no "Enviar")
4. Hacer clic en enviar

**Resultado Esperado**:
```
⚠️  Se muestra: "Sin conexión: respuestas se guardarán localmente"
✅ Se muestra: "✅ Encuesta guardada localmente"
✅ Se muestra: "⏳ Se enviará cuando vuelva la conexión"
✅ Datos guardados en SQLite (tabla: pending_survey_answers)
❌ NO intenta POST al servidor
```

**Logs Esperados**:
```
📝 [SurveyRepository] Respuesta guardada: <customer_id> / <pack_id>
📝 [SurveyRepository] Encolando para sincronización...
⚠️  [ConnectivityService] Sin conexión, en queue
```

**Verificar en SQLite**:
```sql
-- Desde adb shell sqlite3
sqlite3 /data/data/com.gruposolsumed.app/databases/app_gs.db

SELECT * FROM pending_survey_answers WHERE status = 'PENDING';
-- ✅ Debe mostrar una fila con la respuesta guardada
```

---

## 🔄 Test Casos - Sincronización Background

### TC-06: Retry Automático (Offline → Online)

**Objetivo**: Verificar que se sincroniza automáticamente cuando vuelve conexión

**Precondiciones**:
- ✅ Encuesta guardada sin internet (TC-05)
- ✅ Respuesta en estado PENDING en DB

**Pasos**:
1. **Fase 1 (Offline)**: Responder encuesta sin internet
   - ✅ Se guarda en local: `pending_survey_answers.status = PENDING`
2. **Fase 2 (Trigger Manual)**: Abrir app y esperar al menos 30 segundos
   - O hacer: `flutter run -d <device>` nuevamente
3. **Fase 3 (Online)**: Reconectar internet
4. **Fase 4 (Sync)**: Esperar a que BackgroundSync se dispare (~15 min mín)
   - Atajos para testear:
     ```bash
     # Forzar reintento inmediato (requiere adb)
     adb shell am startservice -a com.solsumed.FORCE_SYNC
     ```

**Resultado Esperado**:
```
✅ Respuesta se sincroniza automáticamente
✅ Estado cambia: PENDING → SYNCED
✅ synced_at se llena con timestamp
✅ sync_attempts se incrementa en 1
```

**Logs Esperados**:
```
🌙 [BackgroundSync] tarea iniciada
📝 [BackgroundSync] procesando 1 respuestas...
📤 [SurveyRepository] Marcando asignación 123 como completada...
✅ [BackgroundSync] encuesta sincronizada: <customer_id>
✅ [BackgroundSync] sincronización de encuestas completada
```

---

### TC-07: Retry con Backoff Exponencial

**Objetivo**: Verificar que usa backoff exponencial en reintentos

**Precondiciones**:
- ✅ Servidor respondiendo con errores (simular con Fiddler/Charles)
- ✅ Respuesta en PENDING

**Pasos**:
1. Guardar encuesta offline
2. Reconectar internet pero **bloquear POST** al `/survey/auth/assignments/*/complete`
3. Esperar ciclos de BackgroundSync (cada 15 min)
4. Verificar delays entre reintentos

**Delays Esperados** (Backoff: [30s, 2m, 8m, 30m, 30m]):
```
Intento 1: Inmediato
Intento 2: 30 segundos después (sync_attempts = 1)
Intento 3: 2 minutos después (sync_attempts = 2)
Intento 4: 8 minutos después (sync_attempts = 3)
Intento 5: 30 minutos después (sync_attempts = 4)
Intento 6: 30 minutos después (sync_attempts = 5)
Intento 7+: NO INTENTA MÁS (máximo alcanzado)
```

**Verificar en DB**:
```sql
SELECT sync_attempts, last_sync_attempt FROM pending_survey_answers 
WHERE status = 'PENDING';
-- ✅ Debe incrementar sync_attempts hasta 5
-- ✅ last_sync_attempt debe actualizarse
```

**Logs Esperados**:
```
🔄 [BackgroundSync] reintento programado para <customer_id> en 30s (intento 1/5)
🔄 [BackgroundSync] reintento programado para <customer_id> en 120s (intento 2/5)
...
⚠️  [BackgroundSync] máximo intentos alcanzado para <customer_id>
```

---

### TC-08: Sincronización Periódica (WorkManager)

**Objetivo**: Verificar que BackgroundSync se ejecuta cada 15 minutos

**Precondiciones**:
- ✅ App en background (pantalla apagada)
- ✅ hay conexión a internet
- ✅ hay respuestas pendientes

**Pasos**:
1. Guardar encuesta
2. Cerrar app (NO kill, dejar en background)
3. Esperar ciclos de WorkManager (~15 min)
4. Monitorear logs

**Resultado Esperado**:
```
✅ BackgroundSync se dispara cada 15 minutos
✅ Procesa hasta 10 respuestas por ciclo
✅ Se sincroniza incluso con app cerrada
✅ No consume batería excesivamente
```

**Logs Esperados** (cada 15 min):
```
🌙 [BackgroundSync] tarea iniciada (app en 2do plano/cerrada)
✅ [BackgroundSync] sincronización en 2do plano completada
```

---

### TC-09: Manejo de Errores - Server Error

**Objetivo**: Verificar retry cuando servidor falla con 500

**Pasos**:
1. Guardar encuesta offline
2. Reconectar internet
3. Simular error 500 del servidor (bloquear con proxy)
4. Esperar BackgroundSync

**Resultado Esperado**:
```
❌ sync_attempts se incrementa
✅ Programa reintento con backoff
❌ NO marca como SYNCED
✅ Conserva respuesta intacta en DB
```

---

### TC-10: Manejo de Errores - Max Attempts

**Objetivo**: Verificar que abandona tras 5 intentos fallidos

**Pasos**:
1. Guardar encuesta
2. Bloquear servidor continuamente
3. Dejar que pase por todos los 5 intentos (~45 min con backoff)

**Resultado Esperado**:
```
⚠️  [BackgroundSync] máximo intentos alcanzado
❌ Estado sigue en PENDING (no se sincroniza)
✅ Respuesta está disponible para retry manual
```

---

## 📊 Checklist de Validación

### ✅ Compilación y Build

- [ ] `flutter analyze` sin errores (solo warnings esperados)
- [ ] `flutter pub get` exitoso
- [ ] Proyecto compila sin warnings críticos
- [ ] Versión de DatabaseHelper = 14
- [ ] Tablas de survey creadas en DB

### ✅ Modelos de Datos

- [ ] `SurveyPack` se deserializa correctamente desde JSON
- [ ] `SurveyQuestion` con tipos: RATING, BOOLEAN, TEXT, MULTIPLE_CHOICE
- [ ] `Customer360` incluye recommended_survey
- [ ] Todas las fechas en ISO8601 UTC
- [ ] IDs de pack son STRING (UUID)
- [ ] IDs de preguntas/respuestas son INTEGER

### ✅ Repositorio (SurveyRepository)

- [ ] `getCustomer360()` hace POST a `/survey/auth/customers/:id/360`
- [ ] Autentica con email + password (no JWT)
- [ ] Devuelve `Customer360` o null
- [ ] `cacheSurveyPack()` guarda en SQLite
- [ ] `savePendingAnswer()` encola en SyncQueueService
- [ ] `completeAssignment()` usa assignmentId correcto
- [ ] `getPendingAnswers()` filtra PENDING/FAILED
- [ ] `getCachedPacks()` respeta packType
- [ ] `purgeCachedPacks()` limpia >30 días

### ✅ UI - Widgets

**Customer360Card**:
- [ ] Renderiza avatar con inicial
- [ ] Muestra nombre completo
- [ ] Muestra código de cliente (profit)
- [ ] Sección de contacto: teléfono, email, dirección
- [ ] Sección de visitas: total y fecha última
- [ ] Sección de compras: total USD y últimos 30 días
- [ ] Formatea fechas: "Hoy", "Ayer", "dd/MM/yy"
- [ ] Respeta tema light/dark

**SurveyFormWidget**:
- [ ] Encabezado: nombre y descripción del pack
- [ ] Contador de preguntas
- [ ] **RATING**: 5 botones (1-5), etiquetas Mal/Muy bien
- [ ] **BOOLEAN**: 2 botones Sí/No
- [ ] **MULTIPLE_CHOICE**: Radio buttons con opciones
- [ ] **TEXT**: TextArea con hint
- [ ] Indicador de preguntas requeridas `*`
- [ ] Banner offline (naranja) cuando sin conexión
- [ ] Botón: "Enviar" (online) o "Guardar" (offline)
- [ ] Validación: no permite enviar sin requeridas
- [ ] SnackBar de éxito por 4 segundos
- [ ] Desactiva botón mientras procesa
- [ ] Convierte answer keys int → String

### ✅ Database

**Tablas Creadas**:
- [ ] `survey_packs` (id, name, pack_type, description, is_active, ...)
- [ ] `survey_pack_questions` (id, pack_id, question_id, sort_order, is_required)
- [ ] `survey_assignments` (id, customer_id, pack_id, status, ...)
- [ ] `cached_survey_packs` (id, name, pack_type, questions JSON, cached_at)
- [ ] `cached_customers` (id, name, contact fields, ...)
- [ ] `pending_survey_answers` (assignment_id, customer_id, pack_id, answers JSON, status, ...)
- [ ] `failed_survey_submissions` (id, assignment_id, attempt_count, next_retry_at, ...)

**Índices Creados**:
- [ ] `idx_survey_packs_active` (pack_type, is_active)
- [ ] `idx_survey_assignments_status` (customer_id, status)
- [ ] `idx_pending_answers_status` (status, created_at)
- [ ] `idx_failed_submissions_retry` (next_retry_at)
- [ ] `idx_cached_survey_packs_type` (pack_type, cached_at)

**Migraciones**:
- [ ] `version` actualizado a 14
- [ ] `onUpgrade` rama para `< 14`
- [ ] Crea todas las tablas si no existen

### ✅ BackgroundSync

- [ ] `_syncSurveyAnswers()` obtiene hasta 10 pendientes
- [ ] Extrae `assignment_id` correctamente desde DB ✅ (FIXED)
- [ ] Salta si `sync_attempts >= 5`
- [ ] Llama a `completeAssignment(assignmentId)` 
- [ ] Marca como SYNCED si éxito
- [ ] Programa retry si falla
- [ ] `_scheduleRetry()` aplica backoff: [30s, 2m, 8m, 30m, 30m]
- [ ] Incrementa `sync_attempts` en cada reintento
- [ ] Se ejecuta en `backgroundSyncCallbackDispatcher()`
- [ ] WorkManager configura periodicidad de 15 min
- [ ] Solo corre si hay conexión (NetworkType.connected)

### ✅ Integración E2E

- [ ] `DetalleVisitaPage` carga Customer360Card
- [ ] `DetalleVisitaPage` muestra SurveyFormWidget si hay pack
- [ ] Callback `onCompleted` se dispara después de enviar
- [ ] No rompe flujo existente de visitas
- [ ] Mensajes de sincronización visibles
- [ ] Logs con emojis y prefijos claros

### ✅ Manejo de Errores

- [ ] Null checks en todos los extracts de DB
- [ ] Try/catch en I/O operations
- [ ] No crash si servidor no responde
- [ ] No crash si DB está corrompida
- [ ] Mensajes de error útiles para usuarios
- [ ] Logs detallados para debugging

---

## 🚀 Procedimiento de Testing Recomendado

### Día 1: Validación Básica (1-2 horas)

```bash
1. flutter clean
2. flutter pub get
3. flutter analyze
   ✅ Verificar 0 errores
4. flutter run -d <device>
   ✅ Verifica compilación
5. Login + navegar a cliente
   ✅ TC-01
6. Abrir detalles de visita
   ✅ TC-02 (ficha 360)
7. Responder encuesta completa
   ✅ TC-03 (online)
```

### Día 2: Flujo Offline (2-3 horas)

```bash
1. Desactivar internet
2. Responder encuesta
   ✅ TC-05 (offline)
3. Verificar SQLite
   ✅ pending_survey_answers.status = PENDING
4. Reactivar internet
5. Esperar BackgroundSync o forzar
   ✅ TC-06 (retry)
6. Verificar status = SYNCED
```

### Día 3: Robustez (2-3 horas)

```bash
1. Simular fallos de red (Fiddler/Charles)
2. Probar backoff exponencial
   ✅ TC-07
3. Probar max attempts
   ✅ TC-10
4. Verificar no hay data loss
5. Verificar performance sin lag
```

---

## 📝 Notas Importantes

1. **Logs**: Todos los logs usan emojis para fácil filtrado:
   - 📡 = Network calls
   - 📝 = Local persistence
   - ✅ = Success
   - ❌ = Error
   - ⏳ = Pending/queued
   - 🌙 = Background
   - 🔄 = Retry

2. **SQLite**: Examinar DB en device:
   ```bash
   adb shell sqlite3 /data/data/com.gruposolsumed.app/databases/app_gs.db
   ```

3. **Filtrar Logs**:
   ```bash
   # Solo logs de Survey
   flutter logs | grep "Survey\|BackgroundSync"
   
   # Solo errores
   flutter logs | grep "❌"
   ```

4. **Permisos**: Garantizar en AndroidManifest.xml:
   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
   <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
   ```

---

## ✨ Estado Actual

```
Fase 1: DATOS            ████████████████████ 100% ✅
Fase 2: UI               ████████████████████ 100% ✅
Fase 3: SYNC             ████████████████████ 100% ✅
Fase 4: TESTING          ████████████░░░░░░░░  50% 🧪 (IN PROGRESS)

✅ Compilación: limpia (0 errores)
✅ Modelos: completos
✅ DB: migración v14 lista
✅ BackgroundSync: assignmentId bug fixed
⏳ Testing E2E: pendiente ejecución
```

---

## 📞 Soporte

Para preguntas o issues durante testing:

1. Revisar logs con filtros de emoji
2. Verificar tabla `pending_survey_answers` en SQLite
3. Confirmar permisos en AndroidManifest.xml
4. Asegurar versión DB = 14
5. Probar con `flutter clean` si hay comportamiento extraño

**¡Listo para Testing! 🚀**
