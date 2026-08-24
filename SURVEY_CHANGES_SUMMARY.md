# RESUMEN: Cambios Necesarios para Survey Packs

## 📌 TL;DR (LO MÁS IMPORTANTE)

La app Flutter ya tiene encuestas locales funcionales. **Falta integrar Survey Packs del backend** para que:

1. ✅ El vendedor vea la ficha 360 completa del cliente (datos + historial)
2. ✅ La app reciba automáticamente el pack de encuesta recomendado
3. ✅ Las respuestas se sincronicen en background con retry automático
4. ✅ Todo funcione offline y se recupere online

---

## 🎯 CAMBIOS ESPECÍFICOS EN 10 PUNTOS

### 1. **4 NUEVOS MODELOS** (rápido crear)
- `SurveyPack` — Plantilla de encuesta con preguntas
- `SurveyQuestion` — Pregunta individual dentro de un pack
- `Customer360` — Ficha completa del cliente + encuesta recomendada
- `SurveyAssignment` — Asignación de pack a cliente

**Dónde**: `lib/models/survey_*.dart`  
**Tiempo**: ~30 minutos

---

### 2. **5 NUEVAS TABLAS SQLite** (crítica)
```
survey_packs
survey_pack_questions
survey_assignments
cached_survey_packs
pending_survey_answers
failed_survey_submissions
```

**Dónde**: `lib/services/database_helper.dart` (migración v10→v11)  
**Tiempo**: ~1 hora

---

### 3. **NUEVO: SurveyRepository** (corazón de la integración)
Métodos clave:
- `getCustomer360(customerId)` — Obtiene ficha 360 + pack recomendado del servidor
- `cacheSurveyPack(pack)` — Guarda pack en SQLite local
- `savePendingAnswer(...)` — Almacena respuestas para sincronizar
- `completeAssignment(id)` — Marca encuesta completada
- `getPendingAnswers()` — Para retry automático

**Dónde**: `lib/repositories/survey_repository.dart`  
**Tiempo**: ~1.5 horas

---

### 4. **MODIFICAR: EncuestaRepository** (métodos nuevos)
Agregar:
- `syncPendingAnswers()` — Sincroniza respuestas pendientes
- `getSurveyPacks()` — Obtiene packs disponibles
- `markAssignmentComplete()` — Marca como completada

**Dónde**: `lib/repositories/encuesta_repository.dart`  
**Tiempo**: ~30 minutos

---

### 5. **NUEVO: SurveyFormWidget** (UI dinámico)
- Renderiza preguntas según tipo (RATING, BOOLEAN, TEXT, etc)
- Captura respuestas del usuario
- Guarda localmente
- Intenta sincronizar si hay internet
- Muestra estado de sincronización

**Dónde**: `lib/organisms/survey_form_widget.dart`  
**Tiempo**: ~1 hora

---

### 6. **NUEVO: Customer360Card** (ficha del cliente)
- Nombre, contacto, dirección
- Stats de visitas (total, última)
- Resumen de compras (USD, últimos 30 días)
- Productos más comprados
- Encuesta recomendada (si la hay)

**Dónde**: `lib/molecules/customer_360_card.dart`  
**Tiempo**: ~45 minutos

---

### 7. **MODIFICAR: DetalleVisitaPage** (integración)
Cambios:
- Cargar ficha 360 al abrir
- Mostrar `Customer360Card`
- Integrar `SurveyFormWidget` si hay encuesta
- Capturar y guardar respuestas

**Dónde**: `lib/pages/detalle_visita_page.dart`  
**Tiempo**: ~1 hora

---

### 8. **MODIFICAR: BackgroundSyncService** (retry automático)
Agregar:
- `syncSurveyAnswers()` — Sincroniza respuestas cada 15 min
- Retry exponencial: [30s, 2m, 8m, 30m, 30m]
- Máximo 5 intentos por respuesta
- Marcar como completada en backend

**Dónde**: `lib/services/background_sync_service.dart`  
**Tiempo**: ~1.5 horas

---

### 9. **VALIDAR: Endpoints API Requeridos**
La app necesita acceso a estos endpoints (backend debe tenerlos):

```
POST /survey/auth/customers/:customerId/360
     ↳ Autenticación: email + password (NO JWT)
     ↳ Respuesta: { customer, contact, visitsStats, recommendedSurvey, timestamp }

POST /salesperson/auth/answers
     ↳ Ya existe, no cambios necesarios

POST /survey/auth/assignments/:assignmentId/complete
     ↳ Marca encuesta como completada
```

**Responsable**: Backend  
**Prioridad**: CRÍTICA (sin esto, la app no funciona)

---

### 10. **TESTING E INTEGRACIÓN**
- [ ] Test: Obtener ficha 360 offline
- [ ] Test: Responder encuesta offline
- [ ] Test: Sincronizar cuando vuelve internet
- [ ] Test: Retry automático funciona
- [ ] Test: DetalleVisitaPage muestra todo

**Tiempo**: ~1 hora

---

## 📊 RESUMEN DE IMPACTO

| Métrica | Antes | Después |
|---------|-------|---------|
| **Modelos** | 3 (Encuesta, Pregunta, Option) | 7 (+4 Survey) |
| **Tablas SQLite** | 7 | 12 (+5) |
| **Repositorios** | 5 | 6 (+1 Survey) |
| **Widgets de encuesta** | 1 (genérico) | 3 (+2 específicos) |
| **Endpoints usados** | 6 | 9 (+3 Survey) |
| **Líneas de código nuevas** | ~1500 | ~3000 (+1500) |
| **Complejidad de BD** | Media | Media-Alta |

---

## ⏱️ TIMELINE ESTIMADO

```
Fase 1 (Datos):         4 horas    ← Models + SQLite + SurveyRepository
Fase 2 (UI):            3 horas    ← Widgets + DetalleVisitaPage
Fase 3 (Sincronización): 2 horas    ← BackgroundSync + Retry
Fase 4 (Testing):       1 hora     ← E2E + QA
                        ──────────
TOTAL:                  10 horas   (1 day + 2 hours)
```

---

## 🚨 RIESGOS Y MITIGACIÓN

| Riesgo | Severidad | Mitigación |
|--------|-----------|-----------|
| Backend no tiene endpoints | 🔴 CRÍTICA | Coordinar con backend AHORA |
| Datos en caché desincronizados | 🟡 ALTA | Implementar soft-delete + timestamps |
| Battery drain por WorkManager | 🟡 MEDIA | Usar intervals de 15 min mínimo |
| Conflictos de UUID/Integer | 🟡 MEDIA | Usar tabla `id_mapping` |
| Credenciales en SQLite | 🔴 CRÍTICA | Encriptar con secure_storage |

---

## ✅ VALIDACIÓN PRE-IMPLEMENTACIÓN

Antes de empezar, verificar:

```
Backend:
  ☐ Endpoints /survey/auth/customers/:id/360 implementados
  ☐ Endpoints /survey/auth/assignments/:id/complete implementados
  ☐ Survey packs creados con preguntas asignadas
  ☐ Respuestas guardadas en endpoint /salesperson/auth/answers
  ☐ Documentación de respuesta actualizada

App (Flutter):
  ☐ Modelos actuales revisados y no conflictúan
  ☐ Tablas SQLite verificadas para migrations
  ☐ AuthService puede obtener credenciales para `/survey/auth/`
  ☐ GenericRepository soporta email+password (no solo JWT)

Equipo:
  ☐ Backend listo con endpoints
  ☐ Frontend entiende el flujo
  ☐ QA preparado para testing offline
  ☐ Documentación actualizada
```

---

## 📋 DECISIONES DE DISEÑO

### **1. Modelos Separados vs Extender Existentes**
**Decisión**: Crear nuevos modelos (`SurveyPack`, `Customer360`) en lugar de extender `EncuestaModel`

**Razón**: 
- Encuestas locales son offline-only, simples, sin dependencias
- Survey Packs son complejos, vienen del servidor, con versioning
- Separación permite evolucionar independientemente

### **2. Caché Local Separada**
**Decisión**: Tablas `cached_*` adicionales además de tablas principales

**Razón**:
- Datos del servidor en `survey_packs` (fuente de verdad)
- Caché en `cached_survey_packs` (copia local optimizada)
- Permite offline + sincronización bidireccional

### **3. Retry Exponencial en Tabla Separada**
**Decisión**: `failed_survey_submissions` en lugar de agregar columnas a `pending_survey_answers`

**Razón**:
- Respuestas pendientes vs. fallos son conceptos diferentes
- Histórico de intentos es útil para debugging
- Facilita limpieza (borrar después de X intentos)

### **4. Background Sync en WorkManager**
**Decisión**: Usar WorkManager existente (Android) + Background Task (iOS)

**Razón**:
- Ya está implementado en `LocationTrackingService`
- Respeta limitaciones de batería del sistema
- Escalable para futuras tareas en background

---

## 🔧 CONFIGURACIÓN RECOMENDADA

### Migración de BD
```dart
// En DatabaseHelper.onUpgrade()
if (oldVersion < 11) {
  await db.execute('''CREATE TABLE survey_packs...''');
  await db.execute('''CREATE TABLE survey_pack_questions...''');
  // etc
  version = 11;
}
```

### Environment Variables (si aplica)
```dart
// En env.dart, ya están definidas:
API_BASE_URL = 'https://clientes.grupo-solsumed.com'
// Sin cambios necesarios
```

### Permisos (si aplica)
```xml
<!-- AndroidManifest.xml - Ya tiene lo necesario -->
<!-- iOS - Verificar Info.plist -->
```

---

## 📞 PREGUNTAS PARA EL BACKEND

Antes de implementar, confirmar con backend:

1. ¿Endpoint `/survey/auth/customers/:customerId/360` está listo?
2. ¿Acepta email+password en el body?
3. ¿Qué estructura exacta tiene el response (campos adicionales)?
4. ¿Endpoint `/survey/auth/assignments/:assignmentId/complete` es idempotente?
5. ¿Qué pasa si se envía dos veces la misma respuesta?
6. ¿Hay rate limiting en `/survey/auth/*`?
7. ¿Los packs tienen una versión o fecha de cambio?
8. ¿Se pueden descargar todos los packs disponibles en una llamada?

---

## 🎬 SIGUIENTE PASO

**→ Revisar este documento con el equipo backend**

Una vez validado, iniciar con:

**Paso 1**: Crear modelos (`survey_pack_model.dart`, etc)  
**Paso 2**: Crear tablas SQLite en `database_helper.dart`  
**Paso 3**: Crear `SurveyRepository`

¿Empezamos?

