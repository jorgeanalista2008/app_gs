# Encuestas por visita — qué debe cambiar en la app

> **Para**: desarrollador de `app_gs` (Flutter)
> **Origen**: cambios en `gsolsumed_backend` y `gsolsumed_frontend`
> **Fecha**: 25/08/2026

---

## TL;DR

**La app ya está recibiendo del backend las preguntas asignadas a cada visita, y
las está descartando.** Hoy toda visita muestra el catálogo completo de preguntas
(`encuesta_general`), aunque el admin le haya asignado tres.

No hace falta ningún cambio en el backend. El endpoint que la app ya consume
(`POST /salesperson/auth/visits/list`) devuelve los campos nuevos desde que se
mergeó el módulo de encuestas. Lo que falta es persistirlos y usarlos.

**Nada de lo que cambió es breaking.** Todos los campos son aditivos.

---

## 1. El problema concreto

### Qué manda el backend

`POST /salesperson/auth/visits/list` → cada elemento de `schedules[]` trae ahora:

```json
{
  "id": 412,
  "customer_id": "...",
  "customer_name": "Clínica Central",
  "visit_date_from": "2026-08-26",
  "visit_date_to": "2026-08-29",
  "priority": 2,
  "status": "PENDING",

  "pack_id": "550e8400-e29b-41d4-a716-446655440000",
  "pack_name": "Encuesta Cliente Nuevo",
  "pack_type": "NEW_CUSTOMER",
  "question_ids": [1, 7, 9]
}
```

Verificado en `salesperson.service.ts`: `getMyScheduledVisitsFiltered()` hace
`LEFT JOIN dbo.survey_packs` para traer `pack_name`/`pack_type`, y después pasa
por `attachScheduleQuestionIds()`, que resuelve los `question_ids` desde
`visit_schedule_questions` **ordenados por `order_index`**.

### Dónde se pierden en la app

En `lib/services/database_helper.dart`, la tabla `visitas` no tiene columnas para
ellos:

```sql
CREATE TABLE IF NOT EXISTS visitas (
  id TEXT PRIMARY KEY,
  customer_id TEXT,
  ...
  server_updated_at TEXT
  -- faltan: pack_id, pack_name, pack_type, question_ids
)
```

`guardarVisitas()` inserta columna por columna, así que los campos nuevos se
caen ahí mismo.

### La consecuencia

En `sync_service.dart` la app baja **todo** `GET /visit/questions` y lo guarda
como una sola plantilla:

```dart
const plantillaId = 'encuesta_general';
```

Y `encuesta_repository.dart` siempre lee de `'encuesta_general'`. Resultado: el
vendedor ve las ~40 preguntas del catálogo en cada visita.

> Es exactamente el mismo bug que existía en el panel web. Allá el código hacía
> un fallback a "todas las preguntas" cuando `question_ids` venía vacío; ya se
> corrigió. La app nunca llegó a leer el campo.

---

## 2. Qué hay que hacer

### 2.1 Migración de la base local

Agregar cuatro columnas a `visitas`. La tabla ya existe en dispositivos en
producción, así que hay que tocar **las dos** rutas: el `CREATE TABLE` en
`_createTables()` y un tramo nuevo en `onUpgrade`. Hoy el esquema va en
`version: 15` (`database_helper.dart:23`), así que sube a **16** y agrega,
siguiendo el mismo estilo defensivo que usan los tramos anteriores:

```dart
if (oldVersion < 16) {
  for (final col in const [
    'pack_id TEXT',
    'pack_name TEXT',
    'pack_type TEXT',
    'question_ids TEXT',
  ]) {
    try {
      await db.execute('ALTER TABLE visitas ADD COLUMN $col');
    } catch (e) {
      print('Column $col already exists in visitas: $e');
    }
  }
}
```

`question_ids` va como JSON string (`"[1,7,9]"`) porque **el orden importa** y
hay que preservarlo tal cual llega.

### 2.2 Persistir en `guardarVisitas()`

```dart
'pack_id': visita['pack_id']?.toString(),
'pack_name': visita['pack_name']?.toString(),
'pack_type': visita['pack_type']?.toString(),
'question_ids': jsonEncode(visita['question_ids'] ?? const []),
```

### 2.3 Resolver las preguntas por visita

Al abrir una visita, en vez de leer `encuesta_general`, resolver por IDs
**respetando el orden del array** (no el `orden` local de la pregunta):

```dart
final ids = (jsonDecode(visita['question_ids'] ?? '[]') as List)
    .map((e) => int.parse(e.toString()))
    .toList();

final todas = await _db.getPreguntasByEncuestaId('encuesta_general');
final porServerId = { for (final p in todas) p['server_id'].toString(): p };

final preguntas = ids
    .map((id) => porServerId[id.toString()])
    .whereType<Map<String, dynamic>>()
    .toList();
```

> El catálogo local sigue sirviendo como diccionario de preguntas; lo que cambia
> es **qué subconjunto** se muestra en cada visita.

### 2.4 Estado vacío

`question_ids: []` significa **"visita sin formulario"**, no "faltan datos". No
volver a caer al catálogo completo — ese es justamente el bug. Mostrar algo como
*"Esta visita no tiene encuesta asignada"*.

Las visitas con `source: "AD_HOC"` (registradas sin agenda previa) siempre traen
`question_ids: []` y los campos de pack en `null`.

### 2.5 Mostrar de qué encuesta salen

```dart
final titulo = visita['pack_name'] != null
    ? 'Encuesta: ${visita['pack_name']}'
    : 'Formulario personalizado';
```

---

## 3. Regla importante: el pack es una foto, no un enlace

Cuando el admin agenda una visita con una encuesta, el backend **copia** las
preguntas a `visit_schedule_questions`. Si después edita la encuesta, **las
visitas ya agendadas no cambian**.

Para la app esto significa:

- Los `question_ids` que bajaste son estables; no hace falta revalidarlos contra
  el pack.
- `pack_id` sirve sólo como etiqueta de origen. **No** lo uses para ir a buscar
  las preguntas actuales del pack — te daría un formulario distinto al que el
  admin asignó.
- Las preguntas que el admin desactivó en el catálogo no se copian a visitas
  nuevas, pero siguen en las visitas viejas que ya las tenían.

---

## 4. Sobre el flujo `/survey/auth/*` que la app ya tiene

La app ya usa `/survey/auth/assignments/:id/complete` y
`/survey/auth/customers/:id/360`, y tiene tablas locales `survey_packs`.

Ese es un eje distinto: encuestas asignadas a un **cliente**. Lo que describe
este documento son las preguntas asignadas a una **visita programada**, que
viajan dentro de `schedules[]`.

Conviene que decidas si conviven o si uno absorbe al otro — desde el backend son
dos mecanismos separados y ninguno reemplaza al otro hoy.

---

## 5. Cambio en el backend que NO te afecta (por ahora)

Se agregó `iva_pct` a dos endpoints del portal de clientes:

- `GET /client-commerce/catalog`
- `GET /client-commerce/catalog/:coArt`

Devuelve `16` o `0` según `art.tipo_imp` de Profit (`'1'` = gravado, resto
exento). **Un tercio del catálogo es exento**: 255 de 791 artículos con stock.

La app no consume `client-commerce` hoy, así que no hay nada que hacer. Queda
documentado por si en algún momento le agregas catálogo con precios: aplicar
16% plano infla el total un 16% en los artículos exentos.

---

## 6. Cómo verificarlo sin la app

```bash
curl -s -X POST http://localhost:3000/salesperson/auth/visits/list \
  -H "Content-Type: application/json" \
  -d '{"email":"<vendedor>","password":"<clave>","page":1,"limit":5}' \
  | python -m json.tool | head -60
```

En `schedules[]` deben aparecer `pack_id`, `pack_name`, `pack_type` y
`question_ids`. Si `question_ids` viene siempre vacío en visitas que sí tienen
encuesta, revisa que el ambiente tenga corridas las migraciones
(`npm run db:migrate && npm run db:seed` en el backend).

---

## 7. Checklist

- [ ] Subir la versión del esquema SQLite y agregar `onUpgrade` con los cuatro `ALTER TABLE`
- [ ] Persistir `pack_id`, `pack_name`, `pack_type`, `question_ids` en `guardarVisitas()`
- [ ] Resolver las preguntas de cada visita por `question_ids`, en ese orden
- [ ] Quitar cualquier fallback a `encuesta_general` cuando la lista venga vacía
- [ ] Estado vacío para visitas sin encuesta
- [ ] Mostrar `pack_name` como título del formulario
- [ ] Probar con una visita sin encuesta, una con encuesta y una `AD_HOC`
- [ ] Decidir cómo convive con el flujo `/survey/auth/*` de asignaciones por cliente

---

## 8. Referencias

- Backend: `src/modules/salesperson/salesperson.service.ts`
  → `getMyScheduledVisitsFiltered()` y `attachScheduleQuestionIds()`
- Backend: `src/modules/salesperson/salesperson-public.controller.ts:109`
  → `POST visits/list`
- App: `lib/services/sync_service.dart` → descarga de visitas y preguntas
- App: `lib/services/database_helper.dart` → tabla `visitas`, `guardarVisitas()`
- App: `lib/repositories/encuesta_repository.dart` → uso de `encuesta_general`
