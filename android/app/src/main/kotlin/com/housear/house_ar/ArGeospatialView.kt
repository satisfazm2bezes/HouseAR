package com.housear.house_ar

import android.content.Context
import android.opengl.GLSurfaceView
import android.opengl.GLES20
import android.util.Log
import android.view.View
import com.google.ar.core.*
import com.google.ar.core.exceptions.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import kotlinx.coroutines.*
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

/**
 * PlatformView SIMPLES que mostra câmera AR
 */
class ArGeospatialView(
    context: Context,
    id: Int,
    messenger: BinaryMessenger
) : PlatformView, GLSurfaceView.Renderer {
    
    companion object {
        private const val TAG = "ArGeospatialView"
    }
    
    private val glSurfaceView: GLSurfaceView = GLSurfaceView(context).apply {
        preserveEGLContextOnPause = true
        setEGLContextClientVersion(2)
        setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        setRenderer(this@ArGeospatialView)
        renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
    }
    
    private var session: Session? = null
    private val channel = MethodChannel(messenger, "house_ar/geospatial_view_$id")
    private var textureId = -1
    
    init {
        Log.d(TAG, "🎬 ArGeospatialView criado")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "placeModel" -> {
                    val lat = call.argument<Double>("latitude") ?: 0.0
                    val lon = call.argument<Double>("longitude") ?: 0.0
                    val alt = call.argument<Double>("altitude") ?: 0.0
                    placeModel(lat, lon, alt)
                    result.success(true)
                }
                "getVPSStatus" -> {
                    result.success(getVPSStatus())
                }
                else -> result.notImplemented()
            }
        }
    }
    
    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        Log.d(TAG, "🖼️ Surface criada")
        
        try {
            // Criar textura para câmera
            val textures = IntArray(1)
            GLES20.glGenTextures(1, textures, 0)
            textureId = textures[0]
            
            // Criar session
            session = Session(glSurfaceView.context).apply {
                val arConfig = Config(this).apply {
                    geospatialMode = Config.GeospatialMode.ENABLED
                    planeFindingMode = Config.PlaneFindingMode.DISABLED
                }
                configure(arConfig)
                setCameraTextureName(textureId)
            }
            
            GLES20.glClearColor(0.1f, 0.1f, 0.1f, 1.0f)
            Log.d(TAG, "✅ ARCore + Geospatial inicializado!")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Erro: ${e.message}", e)
        }
    }
    
    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES20.glViewport(0, 0, width, height)
        session?.setDisplayGeometry(0, width, height)
    }
    
    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        
        session?.let { s ->
            try {
                s.resume()
                val frame = s.update()
                
                // Apenas processamento VPS - sem rendering visual por enquanto
                val earth = s.earth
                if (earth?.trackingState == TrackingState.TRACKING) {
                    // VPS funcionando!
                }
            } catch (e: CameraNotAvailableException) {
                Log.e(TAG, "❌ Câmera indisponível")
            } catch (e: Exception) {
                // Ignorar
            }
        }
    }
    
    private fun placeModel(lat: Double, lon: Double, alt: Double) {
        try {
            val earth = session?.earth
            if (earth?.trackingState == TrackingState.TRACKING) {
                val anchor = earth.createAnchor(lat, lon, alt, 0f, 0f, 0f, 1f)
                Log.d(TAG, "⚓ Anchor criado: $lat, $lon")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Erro criar anchor: ${e.message}")
        }
    }
    
    private fun getVPSStatus(): HashMap<String, Any> {
        val earth = session?.earth
        if (earth == null) {
            return hashMapOf("tracking" to false)
        }
        
        val pose = earth.cameraGeospatialPose
        
        return hashMapOf(
            "tracking" to (earth.trackingState == TrackingState.TRACKING),
            "latitude" to pose.latitude,
            "longitude" to pose.longitude,
            "altitude" to pose.altitude,
            "accuracy" to pose.horizontalAccuracy,
            "earthState" to earth.earthState.toString()
        )
    }
    
    override fun getView(): View = glSurfaceView
    
    override fun dispose() {
        Log.d(TAG, "🧹 Dispose")
        glSurfaceView.onPause()
        session?.pause()
        session?.close()
    }
}
