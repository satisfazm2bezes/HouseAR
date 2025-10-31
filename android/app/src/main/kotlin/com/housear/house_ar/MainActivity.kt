package com.housear.house_ar

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
// Registrar plugins gerados para garantir que todos os plugins Flutter sejam registrados
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Registrar automaticamente plugins gerados (necessário ao sobrescrever configureFlutterEngine)
        try {
            GeneratedPluginRegistrant.registerWith(flutterEngine)
        } catch (e: Exception) {
            // Falha ao registrar plugins gerados não deve interromper inicialização — apenas log
            android.util.Log.w("MainActivity", "GeneratedPluginRegistrant registration failed: ${e.message}")
        }

        // Registar PlatformView SIMPLES para câmera AR com ARSceneView
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "simple_geospatial_view",
                SimpleGeospatialViewFactory(
                    flutterEngine.dartExecutor.binaryMessenger,
                    this  // Passar activity como LifecycleOwner
                )
            )
    }
}
