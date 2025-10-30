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
        session?.setDisplayGeometry(android.view.Surface.ROTATION_0, width, height)
        Log.d(TAG, "📐 Surface changed: ${width}x${height}")
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
                    // Tentar colocar modelo automaticamente
                    tryAutoPlaceModel()
                    
                    // Desenhar anchors
                    if (anchors.isNotEmpty()) {
                        val viewMatrix = FloatArray(16)
                        val projMatrix = FloatArray(16)
                        frame.camera.getViewMatrix(viewMatrix, 0)
                        frame.camera.getProjectionMatrix(projMatrix, 0, 0.01f, 1000.0f)
                        
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
    
    private fun tryAutoPlaceModel() {
        if (modelPlaced) return
        if (anchors.isNotEmpty()) return
        
        val earth = session?.earth ?: return
        if (earth.earthState != Earth.EarthState.ENABLED) return
        if (earth.trackingState != TrackingState.TRACKING) return
        
        try {
            // Coordenadas do house_config.json
            val lat = 38.758253710138824
            val lon = -9.272492890642507
            val alt = 170.0
            
            placeModel(lat, lon, alt)
            Log.d(TAG, "✅ Modelo colocado nas coordenadas GPS")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Erro ao criar anchor GPS: ${e.message}", e)
        }
    }
    
    private fun placeModel(lat: Double, lon: Double, alt: Double) {
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
