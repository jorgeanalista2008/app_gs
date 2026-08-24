# Setup Encuestas - Guía Rápida

## ✅ Migración Ejecutada

```
Ya aplicada: [20260824_001] Survey packs para encuestas multi-plantilla
```

Tablas creadas:
- `survey_packs` (UUID, name, pack_type, is_active)
- `survey_pack_questions` (pack_id → question_id)
- `survey_assignments` (customer_id, pack_id, status)

Packs predeterminados insertados:
- `NEW_CUSTOMER` (clientes ≤ 30 días)
- `EXISTING_CUSTOMER` (clientes > 30 días)

## 📍 Ubicaciones

| Item | Ubicación |
|------|-----------|
| **Módulo** | `src/modules/survey/` |
| **Documentación técnica** | `src/modules/survey/CLAUDE.md` |
| **API pública** | `SURVEY_MOBILE_INTEGRATION.md` |
| **Migración SQL** | `db/migrations/20260824_001_survey_packs.sql` |

## 🚀 Próximos Pasos

### 1. Agregar preguntas a packs

```sql
-- Ver qué preguntas existen
SELECT id, code, description FROM dbo.visit_questions WHERE is_active = 1;

-- Agregar preguntas a NEW_CUSTOMER pack
INSERT INTO survey_pack_questions (pack_id, question_id, sort_order)
SELECT sp.id, 1, 0 FROM survey_packs sp WHERE sp.pack_type = 'NEW_CUSTOMER'
UNION ALL
SELECT sp.id, 2, 1 FROM survey_packs sp WHERE sp.pack_type = 'NEW_CUSTOMER'
UNION ALL
SELECT sp.id, 3, 2 FROM survey_packs sp WHERE sp.pack_type = 'NEW_CUSTOMER';
```

### 2. Crear packs adicionales (si necesita)

```bash
curl -X POST http://localhost:3000/survey/packs \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Mi encuesta personalizada",
    "pack_type": "CUSTOM",
    "description": "Preguntas específicas",
    "question_ids": [4, 5, 6]
  }'
```

### 3. Integrar en frontend

Ver: `../gsolsumed_frontend/SURVEY_INTEGRATION.md`

Componentes listos:
- `SurveyPackList` (listar packs admin)
- `Customer360Card` (ficha cliente app)
- `SurveyForm` (formulario responder)

Hook: `useSurvey()` (state + handlers)

## 📊 Verificar Instalación

```sql
-- Verificar tablas existen
SELECT COUNT(*) FROM survey_packs;
SELECT COUNT(*) FROM survey_pack_questions;
SELECT COUNT(*) FROM survey_assignments;

-- Verificar packs predeterminados
SELECT id, name, pack_type FROM survey_packs WHERE deleted_at IS NULL;

-- Verificar migración registrada
SELECT version FROM dbo.schema_migrations WHERE version = '20260824_001';
```

## 🔗 Endpoints Principales

| Método | Ruta | Acceso | Descripción |
|--------|------|--------|-------------|
| POST | `/survey/packs` | Admin | Crear pack |
| GET | `/survey/packs` | Admin | Listar packs |
| GET | `/survey/packs/:id` | Admin | Detalle pack |
| POST | `/survey/assignments` | Admin | Asignar cliente |
| GET | `/survey/assignments/:customerId` | Admin | Historial |
| POST | `/survey/auth/customers/:id/360` | App | Ficha 360 + encuesta |
| POST | `/survey/auth/assignments/:id/complete` | App | Marcar completada |

## 💡 Ejemplos

### Obtener ficha 360 (App)

```bash
curl -X POST http://localhost:3000/survey/auth/customers/client-uuid/360 \
  -H "Content-Type: application/json" \
  -d '{
    "email": "vendedor@example.com",
    "password": "password"
  }'
```

Retorna:
```json
{
  "customer": { ... datos cliente ... },
  "recommended_survey": { ... pack recomendado ... },
  "timestamp": "2026-08-24T..."
}
```

### Asignar encuesta (Admin)

```bash
curl -X POST http://localhost:3000/survey/assignments \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "uuid",
    "pack_id": "uuid",
    "notes": "Encuesta de seguimiento"
  }'
```

## ⚠️ Troubleshooting

**Migración no ejecuta:**
- Verifica conexión BD: `npm run db:migrate`
- Revisa logs de SQL Server

**Endpoints 404:**
- Verifica que `SurveyModule` está en `app.module.ts` ✓
- Compila: `npm run build`

**Pack no se asigna:**
- Verifica `pack.is_active = 1`
- Verifica permisos usuario: `permissions` debe incluir `surveys:write`

**Ficha 360 trae NULL survey:**
- Verifica que existen packs de tipo correspondiente
- Verifica que pack tiene `questions` agregadas

## 📚 Documentación Completa

- **Técnica**: `src/modules/survey/CLAUDE.md` (estructuras, métodos, ejemplos)
- **API**: `SURVEY_MOBILE_INTEGRATION.md` (endpoints, flujos, sync)
- **Frontend**: `../gsolsumed_frontend/SURVEY_INTEGRATION.md` (UI, hooks, consumo)

