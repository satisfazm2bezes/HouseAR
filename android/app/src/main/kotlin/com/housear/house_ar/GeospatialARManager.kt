package com.housear.house_ar

import android.app.Activity
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.ar.core.*
import com.google.ar.core.exceptions.*
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Manager para ARCore Geospatial API
 * 
 * Permite colocar modelos 3D em coordenadas GPS exatas usando VPS (Visual Positioning System)
 * para precisão de 1-5 metros (vs 10-20m do GPS normal).
 * 
 * REUTILIZÁVEL: Pode ser facilmente portado para outros projetos Flutter.
 */
class GeospatialARManager(
    private val activity: Activity,
    private val result: MethodChannel.Result
) {
    companion object {
        private const val TAG = "GeospatialAR"
        private const val CAMERA_PERMISSION_CODE = 1001
        private const val LOCATION_PERMISSION_CODE = 1002
    }

    private var session: Session? = null
    private val scope = CoroutineScope(Dispatchers.Main + Job())
    private val isInitialized = AtomicBoolean(false)

    /**
     * Estrutura de dados para um objeto AR
     */
    data class ARObject(
        val id: String,
        val latitude: Double,
        val longitude: Double,
        val altitude: Double,
        val modelUri: String,
        val rotation: Float = 0f,
        val scale: Float = 1f,
        var anchor: Anchor? = null
    )

    private val objects = mutableMapOf<String, ARObject>()

    /**
     * Inicializa ARCore Session com Geospatial API
     */
    fun initialize() {
        scope.launch {
            try {
                Log.d(TAG, "🚀 Inicializando ARCore Geospatial...")

                // Verificar e pedir permissões
                if (!checkPermissions()) {
                    requestPermissions()
                    return@launch
                }

                // Verificar disponibilidade ARCore
                when (ArCoreApk.getInstance().checkAvailability(activity)) {
                    ArCoreApk.Availability.SUPPORTED_INSTALLED -> {
                        Log.d(TAG, "✅ ARCore instalado")
                    }
                    ArCoreApk.Availability.SUPPORTED_APK_TOO_OLD,
                    ArCoreApk.Availability.SUPPORTED_NOT_INSTALLED -> {
                        result.error(
                            "ARCORE_NOT_INSTALLED",
                            "ARCore precisa ser instalado/atualizado",
                            null
                        )
                        return@launch
                    }
                    else -> {
                        result.error(
                            "ARCORE_NOT_SUPPORTED",
                            "Dispositivo não suporta ARCore",
                            null
                        )
                        return@launch
                    }
                }

                // Criar Session
                session = Session(activity).apply {
                    val config = Config(this).apply {
                        // CRÍTICO: Ativar modo Geospatial
                        geospatialMode = Config.GeospatialMode.ENABLED
                        
                        // Configurações opcionais
                        planeFindingMode = Config.PlaneFindingMode.DISABLED
                        lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR
                        instantPlacementMode = Config.InstantPlacementMode.DISABLED
                        depthMode = Config.DepthMode.DISABLED
                    }
                    configure(config)
                    
                    // CRÍTICO: Resume session para ativar câmera
                    resume()
                }

                Log.d(TAG, "✅ Session criada com Geospatial ENABLED e RESUMED")

                // Aguardar Earth tracking
                waitForEarthTracking()

            } catch (e: UnavailableArcoreNotInstalledException) {
                result.error("ARCORE_NOT_INSTALLED", e.message, null)
            } catch (e: UnavailableApkTooOldException) {
                result.error("ARCORE_TOO_OLD", e.message, null)
            } catch (e: UnavailableSdkTooOldException) {
                result.error("SDK_TOO_OLD", e.message, null)
            } catch (e: UnavailableDeviceNotCompatibleException) {
                result.error("DEVICE_NOT_COMPATIBLE", e.message, null)
            } catch (e: Exception) {
                Log.e(TAG, "❌ Erro ao inicializar: ${e.message}", e)
                result.error("INIT_ERROR", e.message, null)
            }
        }
    }

    /**
     * Aguarda Earth tracking ficar TRACKING
     */
    private suspend fun waitForEarthTracking() = withContext(Dispatchers.Main) {
        Log.d(TAG, "⏳ Aguardando Earth tracking...")
        Log.d(TAG, "💡 DICA: Aponte câmera para edifícios/pontos de referência distantes")

        var attempts = 0
        val maxAttempts = 120 // 120 segundos (2 minutos) timeout para VPS

        while (attempts < maxAttempts) {
            delay(1000)
            attempts++

            val frame = try {
                // Garantir que session está resumed antes de update
                session?.resume()
                session?.update()
            } catch (e: CameraNotAvailableException) {
                Log.e(TAG, "❌ Câmera não disponível: ${e.message}")
                result.error("CAMERA_NOT_AVAILABLE", 
                    "Câmera não está disponível. Verifique se outra app não está usando.", null)
                return@withContext
            } catch (e: Exception) {
                Log.e(TAG, "❌ Erro no update (tentativa $attempts): ${e.message}")
                // Continuar tentando - pode ser erro temporário
                continue
            }

            // ARCore 1.45.0: earth é propriedade direto da Session, não do Frame
            val earth = session?.earth ?: continue

            val trackingState = earth.trackingState
            val earthState = earth.earthState

            // Log mais verboso a cada 5 segundos
            if (attempts % 5 == 0) {
                Log.d(TAG, "📡 $attempts s: Tracking=$trackingState, Earth=$earthState")
            }

            when {
                trackingState == TrackingState.TRACKING && earthState == Earth.EarthState.ENABLED -> {
                    Log.d(TAG, "🎉 Earth tracking ATIVO!")
                    isInitialized.set(true)
                    
                    val pose = earth.cameraGeospatialPose
                    result.success(mapOf(
                        "success" to true,
                        "latitude" to pose.latitude,
                        "longitude" to pose.longitude,
                        "altitude" to pose.altitude,
                        "accuracy" to pose.horizontalAccuracy
                    ))
                    return@withContext
                }
                earthState == Earth.EarthState.ERROR_INTERNAL -> {
                    result.error(
                        "EARTH_ERROR",
                        "Erro interno do Earth. Verifique API Key no AndroidManifest.xml",
                        null
                    )
                    return@withContext
                }
                earthState == Earth.EarthState.ERROR_RESOURCE_EXHAUSTED -> {
                    result.error(
                        "QUOTA_EXCEEDED",
                        "Quota da API excedida. Verifique Google Cloud Console",
                        null
                    )
                    return@withContext
                }
            }
        }

        Log.e(TAG, "⏱️ TIMEOUT após ${maxAttempts}s")
        result.error(
            "TIMEOUT",
            "VPS não conseguiu localizar após ${maxAttempts}s.\n\n" +
            "✅ SOLUÇÕES:\n" +
            "1. Vá para EXTERIOR (janela/varanda)\n" +
            "2. Aponte para edifícios distantes (>20m)\n" +
            "3. Gire lentamente 360° para mapear área\n" +
            "4. Evite: céu vazio, paredes lisas, vegetação\n\n" +
            "VPS precisa reconhecer landmarks visuais!",
            null
        )
    }

    /**
     * Adiciona objeto 3D em coordenadas GPS específicas
     */
    fun addObject(
        id: String,
        latitude: Double,
        longitude: Double,
        altitude: Double,
        modelUri: String,
        rotation: Float = 0f,
        scale: Float = 1f,
        result: MethodChannel.Result
    ) {
        if (!isInitialized.get()) {
            result.error("NOT_INITIALIZED", "GeospatialAR não inicializado", null)
            return
        }

        scope.launch {
            try {
                session?.update()
                val earth = session?.earth

                if (earth?.trackingState != TrackingState.TRACKING) {
                    result.error("NOT_TRACKING", "Earth não está tracking", null)
                    return@launch
                }

                // Criar Earth Anchor nas coordenadas GPS
                val quaternion = floatArrayOf(0f, 0f, 0f, 1f) // Sem rotação por padrão
                // Aplicar rotação Y se necessário
                if (rotation != 0f) {
                    val rad = Math.toRadians(rotation.toDouble()).toFloat()
                    quaternion[1] = kotlin.math.sin(rad / 2)
                    quaternion[3] = kotlin.math.cos(rad / 2)
                }

                val anchor = earth.createAnchor(
                    latitude,
                    longitude,
                    altitude,
                    quaternion
                )

                Log.d(TAG, "⚓ Anchor criado em: $latitude, $longitude, ${altitude}m")

                val obj = ARObject(
                    id = id,
                    latitude = latitude,
                    longitude = longitude,
                    altitude = altitude,
                    modelUri = modelUri,
                    rotation = rotation,
                    scale = scale,
                    anchor = anchor
                )

                objects[id] = obj

                // TODO: Carregar modelo 3D e anexar ao anchor
                // Isso requer integração com Sceneform ou Filament
                // Por agora, apenas criamos o anchor

                result.success(mapOf(
                    "success" to true,
                    "id" to id,
                    "message" to "Anchor criado com sucesso"
                ))

            } catch (e: Exception) {
                Log.e(TAG, "❌ Erro ao adicionar objeto: ${e.message}", e)
                result.error("ADD_OBJECT_ERROR", e.message, null)
            }
        }
    }

    /**
     * Remove objeto por ID
     */
    fun removeObject(id: String, result: MethodChannel.Result) {
        val obj = objects.remove(id)
        if (obj != null) {
            obj.anchor?.detach()
            result.success(mapOf("success" to true))
        } else {
            result.error("NOT_FOUND", "Objeto com ID $id não encontrado", null)
        }
    }

    /**
     * Retorna status atual do VPS/Geospatial
     */
    fun getStatus(result: MethodChannel.Result) {
        scope.launch {
            try {
                session?.update()
                val earth = session?.earth

                if (earth == null) {
                    result.success(mapOf(
                        "available" to false,
                        "trackingState" to "UNKNOWN",
                        "earthState" to "UNKNOWN"
                    ))
                    return@launch
                }

                val pose = earth.cameraGeospatialPose

                result.success(mapOf(
                    "available" to (earth.trackingState == TrackingState.TRACKING),
                    "trackingState" to earth.trackingState.name,
                    "earthState" to earth.earthState.name,
                    "latitude" to pose.latitude,
                    "longitude" to pose.longitude,
                    "altitude" to pose.altitude,
                    "horizontalAccuracy" to pose.horizontalAccuracy,
                    "verticalAccuracy" to pose.verticalAccuracy,
                    "heading" to pose.heading,
                    "headingAccuracy" to pose.headingAccuracy,
                    "objectCount" to objects.size
                ))

            } catch (e: Exception) {
                result.error("STATUS_ERROR", e.message, null)
            }
        }
    }

    /**
     * Limpa recursos
     */
    fun dispose() {
        objects.values.forEach { it.anchor?.detach() }
        objects.clear()
        session?.close()
        session = null
        scope.cancel()
        isInitialized.set(false)
        Log.d(TAG, "🧹 GeospatialARManager disposed")
    }

    /**
     * Verifica se permissões necessárias estão concedidas
     */
    private fun checkPermissions(): Boolean {
        val cameraGranted = ContextCompat.checkSelfPermission(
            activity,
            android.Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED

        val locationGranted = ContextCompat.checkSelfPermission(
            activity,
            android.Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        Log.d(TAG, "📷 Camera permission: $cameraGranted")
        Log.d(TAG, "📍 Location permission: $locationGranted")

        return cameraGranted && locationGranted
    }

    /**
     * Pede permissões ao utilizador
     */
    private fun requestPermissions() {
        Log.d(TAG, "🔐 Pedindo permissões...")
        
        val permissions = arrayOf(
            android.Manifest.permission.CAMERA,
            android.Manifest.permission.ACCESS_FINE_LOCATION
        )

        ActivityCompat.requestPermissions(
            activity,
            permissions,
            CAMERA_PERMISSION_CODE
        )

        result.error(
            "PERMISSION_REQUIRED",
            "Permissões de câmera e GPS são necessárias. Por favor conceda as permissões e tente novamente.",
            null
        )
    }
}
