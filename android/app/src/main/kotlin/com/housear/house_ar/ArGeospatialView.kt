package com.housear.house_ar

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
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
    private val context: Context,
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
    private var backgroundRenderer: BackgroundRenderer? = null
    private var cubeRenderer: CubeRenderer? = null
    private val anchors: MutableList<Anchor> = mutableListOf()
    private var modelPlaced = false
    
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
                "getVPSStatus", "getStatus" -> {
                    result.success(getVPSStatus())
                }
                else -> result.notImplemented()
            }
        }
    }
    
    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        Log.d(TAG, "🖼️ Surface criada")
        
        try {
            // Inicializar renderer de background para desenhar a câmera
            backgroundRenderer = BackgroundRenderer().also { it.createOnGlThread(glSurfaceView.context) }
            textureId = backgroundRenderer?.textureId ?: -1

            // Inicializar renderer do cubo
            cubeRenderer = CubeRenderer().also { it.createOnGlThread(glSurfaceView.context) }
            
            // Criar session
            session = Session(glSurfaceView.context).apply {
                val arConfig = Config(this).apply {
                    geospatialMode = Config.GeospatialMode.ENABLED
                    planeFindingMode = Config.PlaneFindingMode.DISABLED
                }
                configure(arConfig)
                setCameraTextureName(textureId)
            }
            
            // Resume session
            session?.resume()
            
            // Limpar anchors
            anchors.clear()
            modelPlaced = false
            
            GLES20.glClearColor(0.0f, 0.0f, 0.0f, 1.0f)
            Log.d(TAG, "✅ ARCore + Geospatial inicializado!")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Erro: ${e.message}", e)
        }
    }
    
    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES20.glViewport(0, 0, width, height)
        
        // Obter rotação real do dispositivo
        val activity = getActivity(context)
        val display = activity?.windowManager?.defaultDisplay
        val rotation = display?.rotation ?: android.view.Surface.ROTATION_0
        
        val rotationName = when(rotation) {
            android.view.Surface.ROTATION_0 -> "PORTRAIT (0°)"
            android.view.Surface.ROTATION_90 -> "LANDSCAPE (90°)"
            android.view.Surface.ROTATION_180 -> "PORTRAIT_INVERTED (180°)"
            android.view.Surface.ROTATION_270 -> "LANDSCAPE_INVERTED (270°)"
            else -> "UNKNOWN"
        }
        
        // IMPORTANTE: ARCore precisa de width/height DEPOIS de aplicar rotação
        // Se rotation=90 ou 270, width e height podem estar invertidos
        val displayWidth: Int
        val displayHeight: Int
        
        if (rotation == android.view.Surface.ROTATION_90 || rotation == android.view.Surface.ROTATION_270) {
            // Landscape - inverter dimensões
            displayWidth = height
            displayHeight = width
            Log.d(TAG, "📐 Surface LANDSCAPE - invertendo: $displayWidth x $displayHeight")
        } else {
            // Portrait - usar dimensões normais
            displayWidth = width
            displayHeight = height
        }
        
        session?.setDisplayGeometry(rotation, displayWidth, displayHeight)
        Log.d(TAG, "📐 Surface changed: ${width}x${height} → ${displayWidth}x${displayHeight}, rotation=$rotation ($rotationName)")
    }
    
    private fun getActivity(context: Context?): Activity? {
        var ctx = context
        while (ctx is ContextWrapper) {
            if (ctx is Activity) return ctx
            ctx = ctx.baseContext
        }
        return null
    }
    
    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        
        session?.let { s ->
            try {
                val frame = s.update()
                
                // Desenhar fundo da câmera
                backgroundRenderer?.draw(frame)
                
                // Processar Earth e tentar colocar modelo
                val earth = s.earth
                if (earth != null) {
                    // Desenhar anchors
                    if (anchors.isNotEmpty()) {
                        val viewMatrix = FloatArray(16)
                        val projMatrix = FloatArray(16)
                        frame.camera.getViewMatrix(viewMatrix, 0)
                        // Ajustar near/far para outdoor AR (objetos podem estar longe)
                        frame.camera.getProjectionMatrix(projMatrix, 0, 0.1f, 500.0f)
                        
                        val it = anchors.iterator()
                        while (it.hasNext()) {
                            val anchor = it.next()
                            when (anchor.trackingState) {
                                TrackingState.TRACKING -> {
                                    val modelMatrix = FloatArray(16)
                                    anchor.pose.toMatrix(modelMatrix, 0)
                                    cubeRenderer?.draw(modelMatrix, viewMatrix, projMatrix)
                                }
                                TrackingState.STOPPED -> {
                                    it.remove()
                                    anchor.detach()
                                }
                                else -> {} // PAUSED
                            }
                        }
                    }
                }
            } catch (e: CameraNotAvailableException) {
                Log.e(TAG, "❌ Câmera indisponível")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Erro: ${e.message}", e)
            }
        }
    }
    
    fun placeModel(lat: Double, lon: Double, alt: Double) {
        try {
            val earth = session?.earth
            if (earth != null && earth.earthState == Earth.EarthState.ENABLED) {
                try {
                    val anchor = earth.createAnchor(lat, lon, alt, 0f, 0f, 0f, 1f)
                    anchors.add(anchor)
                    modelPlaced = true
                    Log.d(TAG, "⚓ Anchor criado na posição GPS: lat=$lat, lon=$lon, alt=$alt")
                } catch (inner: Exception) {
                    Log.e(TAG, "❌ Falha ao criar anchor: ${inner.message}", inner)
                }
            } else {
                Log.w(TAG, "⚠️ Earth não habilitado - não é possível criar anchor")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Erro criar anchor: ${e.message}", e)
        }
    }
    
    fun getVPSStatus(): HashMap<String, Any> {
        Log.d(TAG, "📊 getVPSStatus chamado")
        try {
            session?.update()
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ Erro ao update session: ${e.message}")
        }
        
        val earth = session?.earth
        if (earth == null) {
            Log.w(TAG, "⚠️ Earth é null - retornando status padrão")
            return hashMapOf(
                "available" to false,
                "tracking" to false,
                "trackingState" to "UNKNOWN",
                "earthState" to "UNKNOWN",
                "latitude" to 0.0,
                "longitude" to 0.0,
                "altitude" to 0.0,
                "horizontalAccuracy" to 999.0,
                "verticalAccuracy" to 999.0,
                "heading" to 0.0,
                "headingAccuracy" to 999.0,
                "objectCount" to 0
            )
        }
        
        val pose = earth.cameraGeospatialPose
        val isTracking = earth.trackingState == TrackingState.TRACKING
        
        Log.d(TAG, "📍 Status: earthState=${earth.earthState}, trackingState=${earth.trackingState}, accuracy=${pose.horizontalAccuracy}m")
        
        return hashMapOf(
            "available" to isTracking,
            "tracking" to isTracking,
            "latitude" to pose.latitude,
            "longitude" to pose.longitude,
            "altitude" to pose.altitude,
            "horizontalAccuracy" to pose.horizontalAccuracy.toDouble(),
            "verticalAccuracy" to pose.verticalAccuracy.toDouble(),
            "heading" to pose.heading.toDouble(),
            "headingAccuracy" to pose.headingAccuracy.toDouble(),
            "earthState" to earth.earthState.toString(),
            "trackingState" to earth.trackingState.toString(),
            "objectCount" to anchors.size
        )
    }
    
    override fun getView(): View = glSurfaceView
    
    override fun dispose() {
        Log.d(TAG, "🧹 Dispose")
        glSurfaceView.onPause()
        try {
            anchors.forEach { it.detach() }
            anchors.clear()
        } catch (e: Exception) {
            Log.w(TAG, "Erro ao detach anchors: ${e.message}")
        }
        session?.pause()
        session?.close()
        cubeRenderer = null
        backgroundRenderer = null
    }
}
