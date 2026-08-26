# 🔴 Root Cause Analysis: 54 vs 324 Clientes

**¿Por qué el frontend muestra 54 clientes pero la app muestra 324?**

---

## 📊 El Problema

| Sistema | Clientes Mostrados | Endpoint |
|---------|------------------|----------|
| **Frontend** | 54 | `GET /salesperson/{userId}/my-customers` |
| **App** | 324 | `POST /salesperson/auth/customers` |

**Diferencia**: 324 - 54 = **270 clientes faltando en frontend**

---

## 🔍 Root Cause: TWO DIFFERENT LOGICS EN `getMyCustomers()`

El backend tiene **dos branches diferentes** basado en el ROLE del usuario:

### Branch 1: Si role == "Vendedor Foraneo" (Frontend muestra 54)

```sql
-- Línea 2459-2487 en salesperson.service.ts
-- Obtiene SOLO clientes de Profit cuyo co_cli está en el website del vendedor

SELECT DISTINCT c.id, c.name, c.tax_id, c.code_client_profit, ...
FROM dbo.customers c
WHERE c.deleted_at IS NULL
  AND c.code_client_profit IS NOT NULL
  AND c.code_client_profit IN (
    -- profitCodes = clientes Profit donde:
    --   website = foraneo_website_code (o profit_co_ven)
    --   O co_ven = foraneo_website_code (o profit_co_ven)
    SELECT DISTINCT co_cli FROM Profit.dbo.clientes
    WHERE website = @coVen OR co_ven = @coVen
  )
ORDER BY c.name ASC

-- RESULTADO: 54 clientes en dbo.customers que coinciden con Profit
```

### Branch 2: Si role != "Vendedor Foraneo" (App muestra 324)

```sql
-- Línea 2490-2535 en salesperson.service.ts
-- Obtiene UNION de 3 fuentes

SELECT DISTINCT c.id, c.name, c.tax_id, c.code_client_profit, ...
FROM dbo.customers c
WHERE c.deleted_at IS NULL AND (
  -- Fuente 1: Clientes en zonas asignadas
  c.zone_id IN (SELECT sz.zone_id FROM dbo.salesperson_zones sz
                WHERE sz.user_id = @userId AND sz.active = 1)
  -- Fuente 2: Clientes asignados directamente
  OR c.id IN (SELECT sc.customer_id FROM dbo.salesperson_customers sc
              WHERE sc.user_id = @userId AND sc.active = 1)
  -- Fuente 3: Clientes Profit del website del vendedor
  OR EXISTS (SELECT 1 FROM Profit.dbo.clientes p
             WHERE (p.website = @coVen OR p.co_ven = @coVen)
               AND c.code_client_profit = p.co_cli)
)
ORDER BY c.name ASC

-- RESULTADO: 324 clientes (UNION de las 3 fuentes)
```

---

## 🎯 Hipótesis del Problema

### Escenario A: El usuario "maestro" es VENDEDOR FORANEO

**En Backend** (estructura `dbo.users`):
```sql
SELECT id, role_id, profit_co_ven, foraneo_website_code
FROM dbo.users
WHERE username = 'maestro'
  AND role_id = (SELECT id FROM roles WHERE name = 'Vendedor Foraneo')
```

**Resultado**:
- Role: `Vendedor Foraneo` ← Este es el trigger
- `getSalespersonScope()` retorna: `mode: 'foraneo'`
- `getMyCustomers()` usa Branch 1 → **54 clientes**
- Frontend ve: **54 clientes**

Pero...

**En la App** (cliente_repository.dart):
- Usa `POST /salesperson/auth/customers`
- Que es endpoint "público" que requiere email+password
- Posiblemente se conecta diferente o el backend retorna diferente

---

## ✅ Cómo Verificar la Causa Real

### Verificación 1: ¿Cuál es el role de "maestro"?

```sql
SELECT u.id, u.username, r.name as role_name, 
       u.profit_co_ven, u.foraneo_website_code
FROM dbo.users u
INNER JOIN dbo.roles r ON r.id = u.role_id
WHERE u.username = 'maestro' AND u.deleted_at IS NULL
```

**Si retorna**:
- `role_name = 'Vendedor Foraneo'` → **CAUSA ENCONTRADA**
- `role_name = 'Vendedor'` → Otro problema

### Verificación 2: ¿Cuántos profit codes hay?

```sql
SELECT COUNT(DISTINCT co_cli) as count_profit_codes
FROM Profit.dbo.clientes
WHERE website = @foraneo_website_code 
   OR co_ven = @foraneo_website_code
```

**Si retorna 54** → Confirma que es la query foraneo

### Verificación 3: ¿Cuántos clientes hay en cada fuente?

```sql
-- Fuente 1: Zonas asignadas
SELECT COUNT(DISTINCT c.id) as zonas_count
FROM dbo.customers c
WHERE c.zone_id IN (
  SELECT sz.zone_id FROM dbo.salesperson_zones sz
  WHERE sz.user_id = @userId AND sz.active = 1
)

-- Fuente 2: Asignación directa
SELECT COUNT(*) as directos_count
FROM dbo.salesperson_customers
WHERE user_id = @userId AND active = 1

-- Fuente 3: Profit website
SELECT COUNT(DISTINCT c.id) as profit_count
FROM dbo.customers c
WHERE EXISTS (SELECT 1 FROM Profit.dbo.clientes p
              WHERE (p.website = @coVen OR p.co_ven = @coVen)
                AND c.code_client_profit = p.co_cli)
```

**Suma de 3 fuentes debería ser cercana a 324**

---

## 🔧 La Solución Depende de la Causa

### Si "maestro" es Vendedor Foraneo

**OPCIÓN A**: Cambiar el rol a "Vendedor Asignado"
- El usuario pasaría a usar la lógica UNION (324 clientes)
- Más trabajo en admin, menos filtrado

**OPCIÓN B**: Extender la lógica Foraneo
- Agregar más profit_codes al foraneo_website_code
- O agregar clientes directo a `salesperson_customers`

**OPCIÓN C**: Híbrida
- Cambiar role a "Vendedor Asignado"
- Configurar zonas o asignación directa para que tenga los 324

---

## 📋 Comparación: App vs Frontend

| Aspecto | App (324) | Frontend (54) |
|---------|----------|-----------|
| Endpoint | POST /salesperson/auth/customers | GET /salesperson/{userId}/my-customers |
| Autenticación | email+password | JWT Bearer |
| Servicio | getMyCustomers(userId) | getSalespersonCustomersForAdmin(userId) → getMyCustomers(userId) |
| Role Esperado | "Vendedor Asignado" | "Vendedor Foraneo" |
| Fuentes | UNION (3 fuentes) | SOLO Profit codes |
| Resultado | **324** | **54** |

---

## 🚨 CONCLUSIÓN

**La diferencia 54 vs 324 se debe a que el usuario "maestro" tiene UN ROLE DIFERENTE en contextos diferentes, O el backend está aplicando lógica foraneo cuando debería aplicar lógica assigned.**

**SIGUIENTE PASO INMEDIATO**: 
Ejecutar las verificaciones 1-3 arriba para confirmar:
1. ¿Es "maestro" Vendedor Foraneo?
2. ¿Cuántos profit_codes tiene asignados?
3. ¿De dónde vienen los 270 clientes faltantes? (¿zonas? ¿asignación directa? ¿profit website?)

---

**Investigación**: 2026-08-24
**Status**: Requiere verificación en base de datos para confirmar
**Impacto**: CRÍTICO - Afecta visibilidad de clientes en frontend
