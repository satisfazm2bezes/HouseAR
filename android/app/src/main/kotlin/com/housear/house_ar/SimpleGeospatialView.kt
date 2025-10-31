package com.housear.house_ar

import android.content.Context
import android.content.res.Configuration
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Surface
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import com.google.ar.core.*
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.common.MethodChannel
import io.github.sceneview.ar.ARSceneView
import io.github.sceneview.ar.arcore.getUpdatedPlanes
import io.github.sceneview.ar.node.AnchorNode
import io.github.sceneview.node.ModelNode
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONArray

/**
 * SimpleGeospatialView usando ARSceneView
 * 
 * ✅ ARSceneView gerencia:
 * - Rendering de câmera automático (sem shaders!)
 * - Orientação portrait/landscape
 * - Filament para modelos 3D
 * - ARCore session lifecycle
 */
class SimpleGeospatialView(
    private val context: Context,
    id: Int,
    creationParams: Map<String, Any>?
) : PlatformView {

    companion object {
        private const val TAG = "SimpleGeospatialView"
    }

    private val containerView: FrameLayout = FrameLayout(context)
    private val arSceneView: ARSceneView
    private var methodChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val mainScope = CoroutineScope(Dispatchers.Main)
    
    // Estado VPS
    private var lastGeospatialPose: GeospatialPose? = null
    private var isVpsReady = false
    
    // Modelos a colocar
    private data class ModelConfig(
        val modelPath: String,
        val latitude: Double,
        val longitude: Double,
        val altitude: Double,
        val scale: Float
    )
    
    private val modelsToPlace = mutableListOf<ModelConfig>()
    private val placedAnchors = mutableListOf<Anchor>()

    init {
        Log.d(TAG, "🚀 Inicializando SimpleGeospatialView com ARSceneView")
        
        // ✅ CRUCIAL: ARSceneView gerencia TUDO automaticamente!
        arSceneView = ARSceneView(context).apply {
            // Configurar session via configureSession
            configureSession { session, config ->
                // Geospatial API
                config.geospatialMode = Config.GeospatialMode.ENABLED
                config.updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                config.focusMode = Config.FocusMode.AUTO
                config.lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR
                
                // Selecionar câmera wide-angle
                val filter = CameraConfigFilter(session).apply {
                    setFacingDirection(CameraConfig.FacingDirection.BACK)
                }
                val cameras = session.getSupportedCameraConfigs(filter)
                if (cameras.isNotEmpty()) {
                    val wideCamera = cameras.first()
                    session.cameraConfig = wideCamera
                    Log.d(TAG, "✅ Câmera: ${wideCamera.imageSize.width}x${wideCamera.imageSize.height}")
                }
                
                // ✅ CRÍTICO: Configurar orientação da tela para ARCore
                val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                val displayRotation = windowManager.defaultDisplay.rotation
                session.setDisplayGeometry(displayRotation, arSceneView.width, arSceneView.height)
                Log.d(TAG, "✅ Display rotation configurado: $displayRotation (0=portrait, 1=landscape)")
            }
            
            // Callback de frame update - onFrame recebe frameTime (Long)
            onFrame = { frameTimeNanos ->
                // Obter frame do session
                this.session?.let { session ->
                    try {
                        val frame = session.update()
                        handleFrameUpdate(session, frame)
                    } catch (e: Exception) {
                        // Ignorar erros de session update
                    }
                }
            }
            
            // Listener para atualizar display geometry quando view muda de tamanho
            addOnLayoutChangeListener { _, left, top, right, bottom, _, _, _, _ ->
                val width = right - left
                val height = bottom - top
                if (width > 0 && height > 0) {
                    session?.let { session ->
                        val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                        val displayRotation = windowManager.defaultDisplay.rotation
                        session.setDisplayGeometry(displayRotation, width, height)
                        Log.d(TAG, "🔄 Display geometry atualizado: ${width}x${height}, rotation=$displayRotation")
                    }
                }
            }
        }
        
        // Adicionar ARSceneView ao container
        containerView.addView(arSceneView)
        
        Log.d(TAG, "✅ ARSceneView configurado e pronto")
    }

    private fun handleFrameUpdate(session: Session?, frame: Frame) {
        val camera = frame.camera
        
        if (session == null || camera.trackingState != TrackingState.TRACKING) {
            return
        }
        
        // Obter Earth (Geospatial)
        val earth = session.earth ?: return
        
        // Log periódico (a cada ~1 segundo = 60 frames)
        if (frame.timestamp % 60 == 0L) {
            val pose = earth.cameraGeospatialPose
            Log.d(TAG, "🌍 Earth state: ${earth.trackingState}")
            Log.d(TAG, "   📍 GPS: Lat=${String.format("%.6f", pose.latitude)}, Lon=${String.format("%.6f", pose.longitude)}")
            Log.d(TAG, "   📏 Precisão: H=${String.format("%.1f", pose.horizontalAccuracy)}m V=${String.format("%.1f", pose.verticalAccuracy)}m")
            
            // Notificar Flutter
            notifyVpsStatus(
                if (earth.trackingState == TrackingState.TRACKING) "TRACKING" else "PAUSED",
                pose.horizontalAccuracy,
                pose.verticalAccuracy
            )
        }
        
        if (earth.trackingState == TrackingState.TRACKING) {
            val geospatialPose = earth.cameraGeospatialPose
            lastGeospatialPose = geospatialPose
            
            // Verificar precisão VPS
            val horizontalAccuracy = geospatialPose.horizontalAccuracy
            val verticalAccuracy = geospatialPose.verticalAccuracy
            
            if (horizontalAccuracy < 10.0 && verticalAccuracy < 10.0) {
                if (!isVpsReady) {
                    isVpsReady = true
                    Log.d(TAG, "✅ VPS PRONTO! Precisão: H=${String.format("%.1f", horizontalAccuracy)}m V=${String.format("%.1f", verticalAccuracy)}m")
                    Log.d(TAG, "📍 Localização: Lat=${geospatialPose.latitude}, Lon=${geospatialPose.longitude}, Alt=${geospatialPose.altitude}")
                    
                    // Colocar modelos automaticamente
                    placeQueuedModels(earth)
                }
            }
        }
    }

    private fun placeQueuedModels(earth: Earth) {
        if (modelsToPlace.isEmpty()) {
            Log.d(TAG, "ℹ️ Nenhum modelo na fila para colocar")
            return
        }
        
        Log.d(TAG, "🏗️ Colocando ${modelsToPlace.size} modelos...")
        
        modelsToPlace.forEach { config ->
            try {
                // Criar Terrain Anchor (ancora no terreno real)
                val anchor = earth.createAnchor(
                    config.latitude,
                    config.longitude,
                    config.altitude.toFloat(),
                    0f, 0f, 0f, 1f // Quaternion identidade (sem rotação)
                )
                
                placedAnchors.add(anchor)
                
                // ✅ TODO: Criar ModelNode e adicionar à cena
                // val anchorNode = AnchorNode(arSceneView.engine, anchor)
                // val modelNode = ModelNode(...)
                // anchorNode.addChildNode(modelNode)
                // arSceneView.addChildNode(anchorNode)
                
                Log.d(TAG, "✅ Anchor criado: ${config.modelPath}")
                Log.d(TAG, "   📍 GPS: Lat=${config.latitude}, Lon=${config.longitude}, Alt=${config.altitude}m")
                Log.d(TAG, "   📏 Scale: ${config.scale}")
                
                // Notificar Flutter
                notifyModelPlaced(config.modelPath, config.latitude, config.longitude)
                
            } catch (e: Exception) {
                Log.e(TAG, "❌ Erro ao colocar modelo ${config.modelPath}: ${e.message}")
            }
        }
        
        modelsToPlace.clear()
    }

    fun loadModelsFromJson(jsonString: String) {
        try {
            val jsonArray = JSONArray(jsonString)
            modelsToPlace.clear()
            
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                
                val config = ModelConfig(
                    modelPath = obj.optString("model", "Duck.glb"),
                    latitude = obj.getDouble("latitude"),
                    longitude = obj.getDouble("longitude"),
                    altitude = obj.getDouble("altitude"),
                    scale = obj.optDouble("scale", 1.0).toFloat()
                )
                
                modelsToPlace.add(config)
                Log.d(TAG, "📦 Modelo carregado: ${config.modelPath} @ (${config.latitude}, ${config.longitude})")
            }
            
            Log.d(TAG, "✅ ${modelsToPlace.size} modelos prontos para colocar")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Erro ao parsear JSON: ${e.message}")
        }
    }

    private fun notifyVpsStatus(status: String, hAccuracy: Double, vAccuracy: Double) {
        val pose = lastGeospatialPose ?: return
        
        mainHandler.post {
            methodChannel?.invokeMethod("onVpsStatusChanged", mapOf(
                "status" to status,
                "latitude" to pose.latitude,
                "longitude" to pose.longitude,
                "altitude" to pose.altitude,
                "horizontalAccuracy" to hAccuracy,
                "verticalAccuracy" to vAccuracy,
                "heading" to pose.heading
            ))
        }
    }

    private fun notifyModelPlaced(modelPath: String, lat: Double, lon: Double) {
        mainHandler.post {
            methodChannel?.invokeMethod("onModelPlaced", mapOf(
                "model" to modelPath,
                "latitude" to lat,
                "longitude" to lon
            ))
        }
    }

    override fun getView(): View = containerView

    override fun dispose() {
        Log.d(TAG, "🛑 Disposing SimpleGeospatialView")
        
        // Limpar anchors
        placedAnchors.forEach { it.detach() }
        placedAnchors.clear()
        
        // ARSceneView gerencia o dispose automaticamente
        arSceneView.destroy()
        
        methodChannel = null
    }

    fun setMethodChannel(channel: MethodChannel) {
        this.methodChannel = channel
        Log.d(TAG, "✅ MethodChannel configurado")
    }
}
