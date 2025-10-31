package com.housear.house_ar

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
// Registrar plugins gerados para garantir que todos os plugins Flutter sejam registrados
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    private val CHANNEL = "house_ar/geospatial"
    private var geospatialManager: GeospatialARManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Registrar automaticamente plugins gerados (necessário ao sobrescrever configureFlutterEngine)
        try {
            GeneratedPluginRegistrant.registerWith(flutterEngine)
        } catch (e: Exception) {
            // Falha ao registrar plugins gerados não deve interromper inicialização — apenas log
            android.util.Log.w("MainActivity", "GeneratedPluginRegistrant registration failed: ${e.message}")
        }

        // Registar PlatformView para câmera AR
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "ar_geospatial_view",
                ArGeospatialViewFactory(flutterEngine.dartExecutor.binaryMessenger)
            )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> {
                        geospatialManager?.dispose()
                        geospatialManager = GeospatialARManager(this, result)
                        geospatialManager?.initialize()
                    }
                    
                    "addObject" -> {
                        val lat = call.argument<Double>("latitude") ?: 0.0
                        val lon = call.argument<Double>("longitude") ?: 0.0
                        val alt = call.argument<Double>("altitude") ?: 0.0
                        
                        // Usar ArGeospatialView se disponível
                        val activeView = ArGeospatialViewFactory.activeView
                        if (activeView != null) {
                            activeView.placeModel(lat, lon, alt)
                            result.success(mapOf("success" to true))
                        } else {
                            val id = call.argument<String>("id") ?: ""
                            val modelUri = call.argument<String>("modelUri") ?: ""
                            val rotation = call.argument<Double>("rotation")?.toFloat() ?: 0f
                            val scale = call.argument<Double>("scale")?.toFloat() ?: 1f
                            geospatialManager?.addObject(
                                id, lat, lon, alt, modelUri, rotation, scale, result
                            )
                        }
                    }
                    
                    "removeObject" -> {
                        val id = call.argument<String>("id") ?: ""
                        geospatialManager?.removeObject(id, result)
                    }
                    
                    "getStatus" -> {
                        // Usar ArGeospatialView se disponível, caso contrário GeospatialARManager
                        val activeView = ArGeospatialViewFactory.activeView
                        if (activeView != null) {
                            result.success(activeView.getVPSStatus())
                        } else {
                            geospatialManager?.getStatus(result)
                        }
                    }
                    
                    "dispose" -> {
                        geospatialManager?.dispose()
                        geospatialManager = null
                        result.success(null)
                    }
                    
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        geospatialManager?.dispose()
        super.onDestroy()
    }
}
