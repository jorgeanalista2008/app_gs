package com.example.app_gs

import io.flutter.embedding.android.FlutterFragmentActivity

// El plugin local_auth requiere que la Activity sea una FragmentActivity
// (usa androidx.biometric.BiometricPrompt internamente) — con
// FlutterActivity normal, authenticate() siempre falla, sin importar que
// el resto de la lógica de login biométrico esté correcta.
class MainActivity : FlutterFragmentActivity()
