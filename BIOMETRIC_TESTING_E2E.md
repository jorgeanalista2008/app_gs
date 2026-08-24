# 🧪 Biometric Login - Testing E2E

**Procedimiento completo para validar autenticación biométrica**

---

## 🎯 Objetivo

Verificar que:
1. ✅ Biometría se detecta correctamente
2. ✅ LoginPage muestra botón biometric
3. ✅ BiometricLoginPage se abre y funciona
4. ✅ Autenticación biométrica completa
5. ✅ Username se guarda en DB
6. ✅ Fallback a login tradicional funciona
7. ✅ Logout + relogin con biometric

---

## 📋 Requisitos Previos

```bash
# 1. Compilación
✅ flutter analyze          → 0 errores
✅ flutter pub get          → dependencias OK
✅ local_auth instalado     → ✅

# 2. Device/Emulator
✅ Android 6.0+ con biometría registrada
   ○ O: Emulator con fingerprint API
✅ iOS 11+ con Face ID / Touch ID registrado

# 3. Base de datos
✅ DatabaseHelper v15
✅ Tabla biometric_settings creada
✅ Usuario maestro en usuarios table

# 4. Permisos
✅ AndroidManifest.xml:
   - android.permission.USE_BIOMETRIC
   - android.permission.USE_FINGERPRINT
✅ Info.plist:
   - NSFaceIDUsageDescription
   - NSBiometricsUsageDescription
```

---

## 🧪 Test Cases

### TC-BIO-01: Detectar Biometría Disponible

**Objetivo**: Verificar que la app detecta correctamente la biometría del device

**Precondiciones**:
- ✅ Device con biometría registrada
- ✅ Permisos configurados

**Pasos**:
1. Abrir app
2. LoginPage visible
3. Ver botón "LOGIN CON BIOMETRÍA"
4. Verificar en logs: `✅ [BiometricService] canUseBiometrics`

**Validación**:
```bash
# En logs
✅ Biometría disponible
✅ Métodos detectados (Huella, Cara, etc)

# En SQLite (opcional)
adb shell sqlite3 /data/data/.../app_gs.db
sqlite> SELECT * FROM biometric_settings;
```

**Resultado Esperado**:
```
✅ Botón "LOGIN CON BIOMETRÍA" visible
✅ Descripción muestra métodos (ej: "Huella dactilar")
✅ Log: "Biometría disponible"
✅ No hay errores de compilación
```

**Logs Esperados**:
```
🔐 [BiometricService] Autenticando con biometría...
✅ [BiometricService] canUseBiometrics = true
✅ [BiometricService] availableBiometrics = [fingerprint]
```

---

### TC-BIO-02: Navegar a BiometricLoginPage

**Objetivo**: Verificar que al tocar botón biometric, se abre la página correcta

**Precondiciones**:
- ✅ TC-BIO-01 pasado
- ✅ Biometría disponible

**Pasos**:
1. LoginPage visible
2. Toca botón "LOGIN CON BIOMETRÍA"
3. Espera 1 segundo

**Validación**:
- BiometricLoginPage se abre
- Muestra icono fingerprint (100x100)
- Muestra título "Autenticación Biométrica"
- Muestra descripción (ej: "Huella dactilar")
- Muestra botón "Autenticar con Biometría"
- Muestra info box educativa

**Resultado Esperado**:
```
✅ Navegación sin lag
✅ UI renderiza correctamente
✅ Todos los elementos visibles:
   - Icono fingerprint
   - Título
   - Descripción de biometría
   - Botón grande
   - Info box
```

**Logs Esperados**:
```
📱 [BiometricLoginPage] initState()
✅ [BiometricService] canUseBiometrics = true
📝 [BiometricService] Biometría disponible: Huella dactilar
```

---

### TC-BIO-03: Autenticación Biométrica Exitosa

**Objetivo**: Verificar flujo completo de autenticación biométrica

**Precondiciones**:
- ✅ TC-BIO-02 pasado
- ✅ BiometricLoginPage abierta
- ✅ Usuario maestro creado (auto en startup)
- ✅ Biometría registrada en device

**Pasos**:
1. BiometricLoginPage visible
2. Toca botón "Autenticar con Biometría"
3. SO solicita autenticación (dialogo del SO)
4. Usuario autentica (huella/cara/iris)
5. Espera validación

**Validación**:
- StatusMessage: "🔐 Autenticando..."
- SO abre dialogo de biometría
- Usuario completa autenticación
- StatusMessage: "✅ Login exitoso"
- Navega a HomePage

**Resultado Esperado**:
```
✅ Spinner aparece mientras autentica
✅ SO muestra dialogo biometric
✅ Message "✅ Login exitoso" por 0.5s
✅ Navega a /home
✅ HomePage visible
✅ Usuario logged in
```

**Logs Esperados**:
```
🔐 [BiometricService] Autenticando con biometría...
✅ [BiometricService] Autenticación biométrica exitosa: maestro
✅ [AuthService] Sesión biométrica establecida: maestro
✅ [BiometricLoginPage] Navegando a /home
```

**Verificación en DB**:
```bash
adb shell sqlite3 /data/data/.../app_gs.db
sqlite> SELECT username, role FROM usuarios WHERE id = 'maestro';
maestro | admin
```

---

### TC-BIO-04: Guardar Username en Database

**Objetivo**: Verificar que username se guarda en biometric_settings

**Precondiciones**:
- ✅ TC-BIO-03 pasado (login exitoso)
- ✅ Base de datos migrada a v15

**Pasos**:
1. Completar TC-BIO-03 (login exitoso)
2. Abrir terminal ADB
3. Conectar a SQLite DB
4. Consultar tabla biometric_settings

**Validación (SQL)**:
```sql
SELECT key, username, value, created_at 
FROM biometric_settings 
WHERE key = '_biometric_enabled';
```

**Resultado Esperado**:
```
key               | _biometric_enabled
username          | maestro
value             | 1
created_at        | 2026-08-24T14:35:42.123Z
```

**Si no ve resultados**:
```
❌ Tabla no existe → Verificar migration v15
❌ Columnas incorrectas → Leer database_helper.dart
❌ Value = 0 → Biometric deshabilitado
```

---

### TC-BIO-05: Logout + Relogin con Biometric

**Objetivo**: Verificar que próximo login puede usar biometric sin tocar login tradicional

**Precondiciones**:
- ✅ TC-BIO-04 pasado
- ✅ Usuario logged in a HomePage
- ✅ Username guardado en DB

**Pasos**:
1. HomePage → abrir menu
2. Toca "Logout" (o similar)
3. Espera regreso a LoginPage
4. Toca botón "LOGIN CON BIOMETRÍA"
5. BiometricLoginPage aparece
6. Toca "Autenticar"
7. Autentica con biometría
8. Navega a HomePage

**Validación**:
- LoginPage visible después de logout
- BiometricLoginPage se abre
- Username se obtiene de DB
- Autenticación exitosa
- Navega a HomePage sin pasar LoginPage tradicional

**Resultado Esperado**:
```
✅ Logout completado
✅ LoginPage visible
✅ Botón biometric funciona
✅ BiometricLoginPage obtiene username de DB
✅ Autenticación sin escribir password
✅ HomePage visible
✅ Sesión establecida
```

**Logs Esperados**:
```
🚪 [AuthService] Logout completado
📱 [BiometricService] getSavedBiometricUsername() → maestro
🔐 [BiometricService] Autenticando con biometría...
✅ [BiometricService] Login biométrico completado: maestro
```

---

### TC-BIO-06: Fallback a Login Tradicional (3 Fallos)

**Objetivo**: Verificar que después de 3 fallos biométricos, regresa a login tradicional

**Precondiciones**:
- ✅ BiometricLoginPage abierta
- ✅ Capacidad de rechazar biometría (device settings)

**Pasos**:
1. BiometricLoginPage visible
2. Toca "Autenticar con Biometría"
3. SO solicita autenticación
4. **Usuario RECHAZA** (o simula fallo)
5. StatusMessage muestra "❌ Intento 1/3"
6. Repite pasos 2-5 dos veces más
7. En intento 3:
   - StatusMessage: "❌ Máximo intentos (3/3)"
   - Espera 2 segundos
   - Regresa a LoginPage

**Validación**:
- Contador incrementa: 1/3 → 2/3 → 3/3
- Después de 3 fallos, regresa automáticamente
- LoginPage visible nuevamente
- Usuario puede loguear con password

**Resultado Esperado**:
```
Intento 1/3:
  ✅ StatusMessage: "❌ Intento 1/3"
  ✅ Botón habilitado para reintentar

Intento 2/3:
  ✅ StatusMessage: "❌ Intento 2/3"
  ✅ Botón habilitado

Intento 3/3:
  ✅ StatusMessage: "❌ Máximo intentos (3/3)"
  ✅ Espera 2s
  ✅ Navigator.pop() → LoginPage
  ✅ Usuario en LoginPage nuevamente

Post-Fallback:
  ✅ Usuario ingresa username + password
  ✅ Toca "INGRESAR"
  ✅ Login tradicional funciona
  ✅ Navega a HomePage
```

**Logs Esperados**:
```
❌ [BiometricService] Autenticación biométrica cancelada (intento 1)
❌ [BiometricService] Autenticación biométrica cancelada (intento 2)
❌ [BiometricService] Autenticación biométrica cancelada (intento 3)
⚠️  [BiometricLoginPage] Máximo de intentos fallidos (3/3)
🚪 [Navigator] Pop() → LoginPage
```

---

### TC-BIO-07: Device sin Biometría

**Objetivo**: Verificar UI cuando device NO tiene biometría

**Precondiciones**:
- ✅ Device/Emulator sin biometría registrada
- ✅ OR: Device con biometría deshabilitada

**Pasos**:
1. Abrir app en device sin biometría
2. LoginPage visible
3. Buscar botón "LOGIN CON BIOMETRÍA"
4. Toca botón (si existe)

**Validación**:
- Opción A: Botón deshabilitado o gris
- Opción B: SnackBar: "⚠️ Biometría no disponible"
- BiometricLoginPage NO se abre

**Resultado Esperado**:
```
✅ Botón visible pero deshabilitado
✅ SnackBar con mensaje claro
✅ No hay crash
✅ Usuario puede hacer login tradicional

Log:
  ⚠️  [BiometricService] Biometría no disponible en este dispositivo
```

---

### TC-BIO-08: Error Handling - Bloqueado

**Objetivo**: Verificar UI cuando biometría está bloqueada (demasiados intentos en SO)

**Precondiciones**:
- ✅ Device con biometría bloqueada (por SO)
- Ejemplo: Android settings → Biometrics → bloqueado por intentos fallidos

**Pasos**:
1. BiometricLoginPage abierta
2. Toca "Autenticar"
3. SO muestra mensaje de bloqueo

**Validación**:
- SO muestra: "Biometría bloqueada, intente más tarde"
- App muestra: StatusMessage con error
- Usuario puede volver atrás

**Resultado Esperado**:
```
✅ StatusMessage: "⚠️ Demasiados intentos fallidos"
✅ Botón "Atrás" funciona
✅ Regresa a LoginPage
✅ Usuario puede hacer login tradicional

Log:
  ⚠️  [BiometricService] Demasiados intentos fallidos
```

---

## 📊 Checklist de Testing

### Compilación
- [ ] `flutter analyze` → 0 errores
- [ ] `flutter pub get` → OK
- [ ] `pubspec.yaml` → local_auth presente
- [ ] No hay warnings críticos

### LoginPage
- [ ] Botón "LOGIN CON BIOMETRÍA" visible
- [ ] Botón funciona (navega a BiometricLoginPage)
- [ ] Divider con "O" visible
- [ ] Login tradicional sigue funcionando

### BiometricLoginPage
- [ ] Icono fingerprint (100x100) renderiza
- [ ] Título "Autenticación Biométrica" visible
- [ ] Descripción de biometría muestra tipos (Huella, Cara, etc)
- [ ] Botón grande "Autenticar" presente
- [ ] StatusMessage actualiza durante autenticación
- [ ] Info box educativa visible
- [ ] Botón "Atrás" (AppBar) funciona

### Autenticación
- [ ] SO solicita autenticación
- [ ] App responde a resultado
- [ ] Éxito: navega a /home
- [ ] Fallo: muestra error, permite reintentos
- [ ] Fallback: 3 fallos → LoginPage

### Database
- [ ] Tabla `biometric_settings` existe
- [ ] Username se guarda después de login
- [ ] Valores correctos (key, username, value, created_at)
- [ ] Próximo login obtiene username de DB

### Permisos
- [ ] AndroidManifest.xml tiene permisos
- [ ] Info.plist tiene descriptions
- [ ] Permisos se solicitan en primer uso
- [ ] App funciona con/sin permisos

### Logs
- [ ] Logs con emojis claros
- [ ] Éxito: ✅ messages
- [ ] Errores: ❌ messages
- [ ] Warnings: ⚠️ messages
- [ ] Info: 🔐 messages

### Fallbacks
- [ ] Device sin biometría: manejo correcto
- [ ] Biometría bloqueada: mensaje claro
- [ ] Login tradicional siempre disponible
- [ ] Logout + relogin funciona

---

## 🚀 Ejecución de Testing (Día 1-2)

### Día 1: Compilación + Básicos (1-2 horas)

```bash
1. Compilar
   flutter clean
   flutter pub get
   flutter analyze
   ✅ 0 errores

2. Ejecutar en device
   flutter run -d <device-id>
   ✅ App inicia
   ✅ LoginPage visible

3. Pruebas básicas (TC-BIO-01, 02)
   ✅ Botón biometric visible
   ✅ Navega a BiometricLoginPage
   ✅ Biometría detectada
```

### Día 2: Flujo Completo (2-3 horas)

```bash
1. TC-BIO-03: Autenticación exitosa
   ✅ Autentica con biometría
   ✅ HomePage visible
   ✅ Logs correctos

2. TC-BIO-04: Verificar DB
   adb shell sqlite3 .../app_gs.db
   sqlite> SELECT * FROM biometric_settings;
   ✅ Username guardado

3. TC-BIO-05: Logout + Relogin
   ✅ Logout funciona
   ✅ Relogin con biometric
   ✅ Sin tocar login tradicional

4. TC-BIO-06: Fallback (3 fallos)
   ✅ Contador incrementa
   ✅ Después de 3: regresa a LoginPage
   ✅ Login tradicional funciona
```

### Día 3: Edge Cases + Robustez (1-2 horas)

```bash
1. TC-BIO-07: Sin biometría
   ✅ Manejo correcto
   ✅ Login tradicional funciona

2. TC-BIO-08: Bloqueado
   ✅ Mensaje claro
   ✅ Fallback a password

3. Performance
   ✅ Sin lag en autenticación
   ✅ Animaciones suaves
   ✅ No hay memory leaks
```

---

## 🔧 Comandos Útiles

### Filtrar Logs
```bash
flutter logs | grep "BiometricService\|BiometricLoginPage"
flutter logs | grep "AuthService"
flutter logs | grep "❌\|⚠️\|✅"
```

### Verificar DB
```bash
# Conectar a SQLite
adb shell sqlite3 /data/data/com.gruposolsumed.app/databases/app_gs.db

# Ver tabla
sqlite> SELECT * FROM biometric_settings;
sqlite> SELECT * FROM usuarios;

# Ver versión DB
sqlite> PRAGMA user_version;
```

### Emular Biometría (Android Emulator)
```bash
# Abrir emulator console
telnet localhost 5554

# Simular huella
auth simulate

# O usar Android Studio Device Manager → Extended Controls
```

### Device Info
```bash
flutter devices
adb devices
adb shell getprop ro.product.model
```

---

## 📊 Métricas de Éxito

```
✅ Compilación:      0 errores, 0 warnings críticos
✅ UI:               Todos los elementos visibles
✅ Biometría:        Detecta correctamente
✅ Autenticación:    Exitosa en 100% casos exitosos
✅ Fallback:         Funciona después 3 fallos
✅ Database:         Username guardado correctamente
✅ Logs:             Claros, con información útil
✅ Performance:      Sin lag, responsive
✅ Seguridad:        Credenciales no expuestas
✅ Documentation:    Completa y clara
```

---

## 📝 Reportar Issues

Si encuentra issues durante testing:

1. **Compilación Error**
   - Verificar `flutter pub get`
   - Verificar permisos en AndroidManifest.xml + Info.plist
   - `flutter clean` y reintentar

2. **Biometría no se detecta**
   - Verificar que device/emulator tiene biometría registrada
   - Verificar permisos en OS settings
   - Ver logs: `BiometricService` messages

3. **NavigationError**
   - Verificar rutas en main.dart
   - Verificar imports en pages
   - Ver logs completos

4. **DB Issues**
   - Verificar migration v15
   - Verificar tabla existe: `adb shell sqlite3 .../app_gs.db`
   - Revisar database_helper.dart

---

**¡Listo para Testing E2E! 🧪**
