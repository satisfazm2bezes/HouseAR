package com.housear.house_ar

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class SimpleGeospatialViewFactory(
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<String, Any>
        
        val view = SimpleGeospatialView(context, viewId, creationParams)
        
        // Criar MethodChannel para comunicação com Flutter
        val channel = MethodChannel(messenger, "simple_geospatial_view_$viewId")
        view.setMethodChannel(channel)
        
        // Registar método para carregar modelos
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
                else -> result.notImplemented()
            }
        }
        
        return view
    }
}
