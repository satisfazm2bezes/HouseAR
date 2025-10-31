package com.housear.house_ar

import android.content.Context
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class SimpleGeospatialViewFactory(
    private val messenger: BinaryMessenger,
    private val activity: FlutterActivity  // Receber activity
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<String, Any>
        
        // Passar activity ao SimpleGeospatialView
        val view = SimpleGeospatialView(context, activity.lifecycle, viewId, creationParams)
        
        // Criar MethodChannel para comunicação com Flutter
        val channel = MethodChannel(messenger, "simple_geospatial_view_$viewId")
        view.setMethodChannel(channel)
        
        // Registar métodos para comunicação com Flutter
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModels" -> {
                    val jsonString = call.argument<String>("json")
                    if (jsonString != null) {
                        view.loadModelsFromJson(jsonString)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "JSON string required", null)
                    }
                }
                "placeModels" -> {
                    // Flutter chamou para colocar modelos!
                    try {
                        view.placeModelsNow()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PLACE_ERROR", "Erro ao colocar modelos: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        return view
    }
}
