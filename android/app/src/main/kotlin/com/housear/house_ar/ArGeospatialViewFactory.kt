package com.housear.house_ar

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Factory para criar ArGeospatialView instances
 */
class ArGeospatialViewFactory(
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    
    companion object {
        // Referência ao último ArGeospatialView criado para acesso global
        var activeView: ArGeospatialView? = null
    }
    
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val view = ArGeospatialView(context, viewId, messenger)
        activeView = view
        return view
    }
}
