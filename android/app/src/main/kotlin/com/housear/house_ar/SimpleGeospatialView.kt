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
import androidx.lifecycle.LifecycleOwner
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
    private val lifecycle: androidx.lifecycle.Lifecycle,  // Adicionar lifecycle
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
        Log.d(TAG, "   Lifecycle state: ${lifecycle.currentState}")
        
        // ✅ ARSceneView COM lifecycle (padrão ar_flutter_plugin_2)
        arSceneView = ARSceneView(
            context = context,
            sharedLifecycle = lifecycle,
            sessionConfiguration = { session, config ->
                Log.d(TAG, "🔧 sessionConfiguration callback chamado!")
                config.apply {
                    // Geospatial API (principal feature)
                    geospatialMode = Config.GeospatialMode.ENABLED
                    
                    // Configurações adicionais
                    depthMode = when (session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
                        true -> Config.DepthMode.AUTOMATIC
                        else -> Config.DepthMode.DISABLED
                    }
                    updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                    focusMode = Config.FocusMode.AUTO
                    lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR
                    // Manter plane finding ativo mas não mostrar visualmente (ARCore precisa para funcionar)
                    planeFindingMode = Config.PlaneFindingMode.HORIZONTAL
                    
                    // Deixar ARCore escolher a melhor câmera automaticamente (sem zoom)
                    // Não configurar cameraConfig manualmente para FOV natural
                }
            }
        )
        
        // Adicionar ao container (como ar_flutter_plugin_2)
        containerView.addView(arSceneView)
        Log.d(TAG, "✅ ARSceneView adicionado ao layout")
        
        // PlaneRenderer INVISÍVEL (detecta mas não mostra - para Geospatial funcionar)
        arSceneView.planeRenderer.isEnabled = true
        arSceneView.planeRenderer.isVisible = false  // Não mostrar planos visualmente
        
        // onFrame callback (processar frames AR)
        arSceneView.onFrame = { frameTime ->
            arSceneView.session?.update()?.let { frame ->
                handleFrameUpdate(arSceneView.session!!, frame)
            }
        }
        
        Log.d(TAG, "✅ SimpleGeospatialView configurado")
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
                    
                    // ❌ NÃO colocar modelos automaticamente!
                    // Aguardar Flutter pressionar botão "Colocar Modelos"
                }
            }
        }
    }

    /**
     * Coloca modelos 3D nas coordenadas GPS usando Terrain Anchors.
     * Chamado quando VPS está pronto (accuracy < 10m).
     * 
     * NÃO é chamado automaticamente - apenas quando Flutter invocar placeModels().
     */
    fun placeQueuedModels(earth: Earth) {
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
                    config.altitude,
                    0f, 0f, 0f, 1f // Quaternion identidade (sem rotação)
                )
                
                placedAnchors.add(anchor)
                
                // ✅ Criar AnchorNode com o anchor GPS
                val anchorNode = AnchorNode(arSceneView.engine, anchor)
                
                // ✅ Carregar modelo .glb usando ARSceneView ModelNode
                // Se for URL (Duck.glb), usar direto. Se for asset local, usar "file:///android_asset/..."
                val modelUri = if (config.modelPath.startsWith("http")) {
                    config.modelPath
                } else {
                    "file:///android_asset/models/${config.modelPath}"
                }
                
                // Criar ModelNode com coroutine para carregamento assíncrono
                mainScope.launch {
                    try {
                        val modelNode = ModelNode(
                            modelInstance = arSceneView.modelLoader.createModelInstance(modelUri),
                            scaleToUnits = config.scale.toFloat()
                        )
                        
                        // Adicionar modelo ao anchor
                        anchorNode.addChildNode(modelNode)
                        
                        // Adicionar anchor à cena AR
                        arSceneView.addChildNode(anchorNode)
                        
                        Log.d(TAG, "✅ Modelo 3D renderizado: ${config.modelPath}")
                        Log.d(TAG, "   📍 GPS: Lat=${config.latitude}, Lon=${config.longitude}, Alt=${config.altitude}m")
                        Log.d(TAG, "   📏 Scale: ${config.scale}")
                        
                        // Notificar Flutter
                        notifyModelPlaced(config.modelPath, config.latitude, config.longitude)
                        
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Erro ao carregar modelo 3D ${config.modelPath}: ${e.message}")
                    }
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "❌ Erro ao criar anchor para ${config.modelPath}: ${e.message}")
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

    /**
     * Chamado pelo Flutter quando botão "Colocar Modelos" for pressionado.
     * Valida se VPS está pronto e coloca os modelos.
     */
    fun placeModelsNow() {
        arSceneView.session?.let { session ->
            val earth = session.earth
            
            if (earth == null) {
                Log.e(TAG, "❌ Earth não disponível!")
                throw IllegalStateException("Earth não disponível")
            }
            
            if (earth.trackingState != com.google.ar.core.TrackingState.TRACKING) {
                Log.e(TAG, "❌ Earth não está em TRACKING: ${earth.trackingState}")
                throw IllegalStateException("Earth não está em TRACKING")
            }
            
            val pose = earth.cameraGeospatialPose
            if (pose.horizontalAccuracy >= 10.0) {
                Log.e(TAG, "❌ Precisão GPS insuficiente: ${pose.horizontalAccuracy}m (precisa <10m)")
                throw IllegalStateException("Precisão GPS insuficiente: ${pose.horizontalAccuracy}m")
            }
            
            Log.d(TAG, "✅ Condições OK para colocar modelos!")
            Log.d(TAG, "   📍 GPS: Lat=${pose.latitude}, Lon=${pose.longitude}")
            Log.d(TAG, "   📏 Precisão: ${pose.horizontalAccuracy}m")
            Log.d(TAG, "   📦 Modelos na fila: ${modelsToPlace.size}")
            
            // Colocar modelos!
            placeQueuedModels(earth)
            
        } ?: throw IllegalStateException("ARCore session não disponível")
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
        Log.d(TAG, "📢 Notificando Flutter sobre modelo colocado: $modelPath")
        Log.d(TAG, "   MethodChannel: ${if (methodChannel != null) "✅ OK" else "❌ NULL"}")
        
        mainHandler.post {
            methodChannel?.invokeMethod("onModelPlaced", mapOf(
                "model" to modelPath,
                "latitude" to lat,
                "longitude" to lon
            ))
            Log.d(TAG, "✅ Notificação enviada para Flutter!")
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
