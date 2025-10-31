package com.housear.house_ar

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log
import android.view.View
import android.view.TextureView
import android.widget.FrameLayout
import androidx.core.content.ContextCompat
import com.google.ar.core.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

/**
 * ARCore Geospatial View usando Session direta (sem ARSceneView)
 * Compatível com Flutter PlatformView
 * IMPORTANTE: Usa Singleton para evitar múltiplas Sessions simultâneas
 */
class ArGeospatialView(
    private val context: Context,
    id: Int,
    messenger: BinaryMessenger
) : PlatformView {
    
    companion object {
        private const val TAG = "ArGeospatialView"
        
        // SINGLETON: Apenas UMA Session ARCore por app
        @Volatile
        private var sharedSession: Session? = null
        private var sessionRefCount = 0
        
        @Synchronized
        fun getOrCreateSession(activity: Activity): Session? {
            if (sharedSession == null) {
                Log.d(TAG, "📲 Criando PRIMEIRA Session ARCore (Singleton)")
                try {
                    sharedSession = Session(activity)
                    sessionRefCount = 1
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Erro ao criar Session Singleton: ${e.message}", e)
                    return null
                }
            } else {
                sessionRefCount++
                Log.d(TAG, "♻️ Reutilizando Session existente (refs=$sessionRefCount)")
            }
            return sharedSession
        }
        
        @Synchronized
        fun releaseSession() {
            sessionRefCount--
            Log.d(TAG, "🔻 releaseSession chamado (refs=$sessionRefCount)")
            
            // Só destruir quando NENHUM view usar mais
            if (sessionRefCount <= 0) {
                Log.d(TAG, "🗑️ Destruindo Session Singleton (sem mais refs)")
                sharedSession?.pause()
                sharedSession?.close()
                sharedSession = null
                sessionRefCount = 0
            }
        }
    }
    
    private val containerView: FrameLayout = FrameLayout(context)
    private var textureView: TextureView? = null
    private var arSession: Session? = null  // Referência local à Session singleton
    private val channel = MethodChannel(messenger, "house_ar/geospatial_view_$id")
    private val anchors: MutableList<Anchor> = mutableListOf()
    private var isSessionResumed = false

    init {
        Log.d(TAG, "🚀 Criando ARCore Geospatial View (Session direta)")
        setupTextureView()
        checkSystemRequirements()  // NOVO: Diagnóstico completo
        setupARSession()
        setupMethodChannel()
    }
    
    private fun setupTextureView() {
        // ARCore REQUER GLSurfaceView para renderização OpenGL
        val glView = android.opengl.GLSurfaceView(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            preserveEGLContextOnPause = true
            setEGLContextClientVersion(2)
            setEGLConfigChooser(8, 8, 8, 8, 16, 0)
            
            setRenderer(object : android.opengl.GLSurfaceView.Renderer {
                override fun onSurfaceCreated(gl: javax.microedition.khronos.opengles.GL10?, config: javax.microedition.khronos.egl.EGLConfig?) {
                    Log.d(TAG, "📺 GLSurface CREATED")
                }
                
                override fun onSurfaceChanged(gl: javax.microedition.khronos.opengles.GL10?, width: Int, height: Int) {
                    Log.d(TAG, "📺 GLSurface ${width}x${height}")
                    android.opengl.GLES20.glViewport(0, 0, width, height)
                }
                
                override fun onDrawFrame(gl: javax.microedition.khronos.opengles.GL10?) {
                    android.opengl.GLES20.glClear(android.opengl.GLES20.GL_COLOR_BUFFER_BIT or android.opengl.GLES20.GL_DEPTH_BUFFER_BIT)
                    try {
                        arSession?.update()
                    } catch (e: Exception) {
                        // Ignore
                    }
                }
            })
            renderMode = android.opengl.GLSurfaceView.RENDERMODE_CONTINUOUSLY
        }
        
        containerView.addView(glView)
        textureView = null
        Log.d(TAG, "✅ GLSurfaceView criado")
    }
    
    private fun checkSystemRequirements() {
        val activity = getActivity(context) ?: return
        
        Log.d(TAG, "")
        Log.d(TAG, "═══════════════════════════════════════════════════════")
        Log.d(TAG, "🔍 DIAGNÓSTICO VPS - Verificando Requisitos")
        Log.d(TAG, "═══════════════════════════════════════════════════════")
        
        // 1. Verificar permissões
        Log.d(TAG, "📋 1. PERMISSÕES:")
        val hasCamera = ContextCompat.checkSelfPermission(
            activity, Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
        Log.d(TAG, "   ${if (hasCamera) "✅" else "❌"} CAMERA: ${if (hasCamera) "CONCEDIDA" else "NEGADA"}")
        
        val hasFineLocation = ContextCompat.checkSelfPermission(
            activity, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        Log.d(TAG, "   ${if (hasFineLocation) "✅" else "❌"} ACCESS_FINE_LOCATION: ${if (hasFineLocation) "CONCEDIDA" else "NEGADA"}")
        
        val hasCoarseLocation = ContextCompat.checkSelfPermission(
            activity, Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        Log.d(TAG, "   ${if (hasCoarseLocation) "✅" else "❌"} ACCESS_COARSE_LOCATION: ${if (hasCoarseLocation) "CONCEDIDA" else "NEGADA"}")
        
        // 2. Verificar GPS e última localização conhecida
        Log.d(TAG, "📡 2. GPS/LOCALIZAÇÃO:")
        val locationManager = activity.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        val isGpsEnabled = locationManager?.isProviderEnabled(LocationManager.GPS_PROVIDER) == true
        val isNetworkEnabled = locationManager?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) == true
        
        Log.d(TAG, "   ${if (isGpsEnabled) "✅" else "❌"} GPS Provider: ${if (isGpsEnabled) "ATIVO" else "DESATIVADO"}")
        Log.d(TAG, "   ${if (isNetworkEnabled) "✅" else "❌"} Network Provider: ${if (isNetworkEnabled) "ATIVO" else "DESATIVADO"}")
        
        // NOVO: Verificar última localização conhecida (como Google Maps faz)
        if (hasFineLocation) {
            try {
                val lastGpsLocation = locationManager?.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                val lastNetworkLocation = locationManager?.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                
                Log.d(TAG, "   📍 ÚLTIMA LOCALIZAÇÃO CONHECIDA:")
                if (lastGpsLocation != null) {
                    val age = (System.currentTimeMillis() - lastGpsLocation.time) / 1000
                    Log.d(TAG, "      GPS: Lat=${String.format("%.6f", lastGpsLocation.latitude)}, " +
                              "Lon=${String.format("%.6f", lastGpsLocation.longitude)}, " +
                              "Acc=${String.format("%.1f", lastGpsLocation.accuracy)}m, " +
                              "Idade=${age}s")
                } else {
                    Log.w(TAG, "      GPS: Nenhuma localização armazenada")
                }
                
                if (lastNetworkLocation != null) {
                    val age = (System.currentTimeMillis() - lastNetworkLocation.time) / 1000
                    Log.d(TAG, "      Network: Lat=${String.format("%.6f", lastNetworkLocation.latitude)}, " +
                              "Lon=${String.format("%.6f", lastNetworkLocation.longitude)}, " +
                              "Acc=${String.format("%.1f", lastNetworkLocation.accuracy)}m, " +
                              "Idade=${age}s")
                } else {
                    Log.w(TAG, "      Network: Nenhuma localização armazenada")
                }
            } catch (e: SecurityException) {
                Log.e(TAG, "   ❌ Erro ao acessar localização: ${e.message}")
            }
        }
        
        if (!isGpsEnabled && !isNetworkEnabled) {
            Log.e(TAG, "   ⚠️ AVISO: Nenhum provedor de localização ativo!")
            Log.e(TAG, "   📍 Ativar GPS nas configurações do dispositivo")
        }
        
        // 3. Verificar conexão Internet
        Log.d(TAG, "🌐 3. CONEXÃO INTERNET:")
        val connectivityManager = activity.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        val network = connectivityManager?.activeNetwork
        val capabilities = connectivityManager?.getNetworkCapabilities(network)
        
        val hasInternet = capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
        val hasValidated = capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
        
        Log.d(TAG, "   ${if (hasInternet) "✅" else "❌"} Internet disponível: ${if (hasInternet) "SIM" else "NÃO"}")
        Log.d(TAG, "   ${if (hasValidated) "✅" else "❌"} Conexão validada: ${if (hasValidated) "SIM" else "NÃO"}")
        
        if (capabilities != null) {
            val hasWifi = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
            val hasCellular = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
            Log.d(TAG, "   📶 Tipo: ${when {
                hasWifi -> "WiFi"
                hasCellular -> "Dados móveis"
                else -> "Desconhecido"
            }}")
        } else {
            Log.e(TAG, "   ⚠️ AVISO: Sem conexão de rede ativa!")
            Log.e(TAG, "   📡 VPS requer internet para baixar dados de mapeamento")
        }
        
        // 4. Resumo para VPS
        Log.d(TAG, "📊 4. RESUMO PARA VPS:")
        val vpsReady = hasCamera && hasFineLocation && (isGpsEnabled || isNetworkEnabled) && hasInternet && hasValidated
        
        if (vpsReady) {
            Log.d(TAG, "   ✅ Sistema PRONTO para ARCore Geospatial API")
            Log.d(TAG, "   💡 Se VPS ficar em PAUSED:")
            Log.d(TAG, "      - Vá para EXTERIOR (rua, praça pública)")
            Log.d(TAG, "      - Aponte para EDIFÍCIOS/LANDMARKS reconhecíveis")
            Log.d(TAG, "      - Mova o celular LENTAMENTE em várias direções")
            Log.d(TAG, "      - Área deve ter cobertura VPS do Google")
        } else {
            Log.e(TAG, "   ❌ Sistema NÃO PRONTO - Corrigir itens acima!")
            if (!hasCamera || !hasFineLocation) {
                Log.e(TAG, "      → Conceder permissões no Android Settings")
            }
            if (!isGpsEnabled && !isNetworkEnabled) {
                Log.e(TAG, "      → Ativar GPS/Localização no dispositivo")
            }
            if (!hasInternet || !hasValidated) {
                Log.e(TAG, "      → Conectar a WiFi ou ativar dados móveis")
            }
        }
        
        Log.d(TAG, "═══════════════════════════════════════════════════════")
        Log.d(TAG, "")
    }
    
    private fun setupARSession() {
        try {
            val activity = getActivity(context)
            if (activity == null) {
                Log.e(TAG, "❌ Activity não encontrada")
                return
            }
            
            // Verificar permissão de câmera
            val hasCameraPermission = ContextCompat.checkSelfPermission(
                activity, 
                Manifest.permission.CAMERA
            ) == PackageManager.PERMISSION_GRANTED
            
            if (!hasCameraPermission) {
                Log.e(TAG, "❌ PERMISSÃO DE CÂMERA NÃO CONCEDIDA!")
                Log.e(TAG, "   Por favor, conceda permissão de câmera nas configurações do app.")
                return
            }
            
            Log.d(TAG, "✅ Permissão de câmera: OK")
            
            // OBTER Session Singleton (compartilhada)
            arSession = getOrCreateSession(activity)
            if (arSession == null) {
                Log.e(TAG, "❌ Falha ao obter Session")
                return
            }
            
            // Se Session acabou de ser criada, configurar câmera + Geospatial
            if (sessionRefCount == 1) {
                Log.d(TAG, "🔧 Configurando Session pela primeira vez")
                
                // PRIMEIRO: Obter e selecionar câmera ANTES de configurar
                try {
                    val session = arSession!!
                    
                    // Criar filtro para câmera traseira
                    val filter = CameraConfigFilter(session).apply {
                        facingDirection = CameraConfig.FacingDirection.BACK
                    }
                    
                    val cameras = session.getSupportedCameraConfigs(filter)
                    Log.d(TAG, "📷 Câmeras disponíveis: ${cameras.size}")
                    
                    if (cameras.isEmpty()) {
                        Log.e(TAG, "❌ NENHUMA câmera encontrada! Verifique permissões.")
                    } else {
                        // Escolher câmera com maior resolução (tipicamente wide angle)
                        val wideCamera = cameras.maxByOrNull { cameraConfig: CameraConfig ->
                            val size = cameraConfig.imageSize
                            val pixels = size.width * size.height
                            Log.d(TAG, "   - Câmera: ${size.width}x${size.height} = $pixels pixels")
                            pixels
                        }
                        
                        wideCamera?.let { selectedConfig ->
                            session.cameraConfig = selectedConfig
                            val size = selectedConfig.imageSize
                            Log.d(TAG, "✅ Câmera selecionada: ${size.width}x${size.height}")
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Erro ao selecionar câmera: ${e.message}", e)
                }
                
                // DEPOIS: Configurar com Geospatial mode
                val config = Config(arSession).apply {
                    geospatialMode = Config.GeospatialMode.ENABLED
                    planeFindingMode = Config.PlaneFindingMode.DISABLED
                    focusMode = Config.FocusMode.AUTO
                }
                
                arSession?.configure(config)
                Log.d(TAG, "⚙️ Config: Geospatial=ENABLED, PlaneDetection=DISABLED")
            } else {
                Log.d(TAG, "⏩ Session já configurada, pulando setup de câmera")
            }
            
            // Resumir sessão (pode ser chamado múltiplas vezes, ARCore ignora se já resumida)
            if (!isSessionResumed) {
                arSession?.resume()
                isSessionResumed = true
                Log.d(TAG, "✅ ARCore Session resumida")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Erro ao configurar ARCore Session: ${e.message}", e)
        }
    }
    
    private fun getActivity(context: Context?): Activity? {
        var ctx = context
        while (ctx is ContextWrapper) {
            if (ctx is Activity) return ctx
            ctx = ctx.baseContext
        }
        return null
    }
    
    private fun setupMethodChannel() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "placeModel" -> {
                    val latitude = call.argument<Double>("latitude") ?: 0.0
                    val longitude = call.argument<Double>("longitude") ?: 0.0
                    val altitude = call.argument<Double>("altitude") ?: 0.0
                    placeModel(latitude, longitude, altitude)
                    result.success(null)
                }
                "getStatus" -> {
                    result.success(getVPSStatus())
                }
                "getVPSStatus" -> {  // Alias para compatibilidade
                    result.success(getVPSStatus())
                }
                "getCameraInfo" -> {
                    result.success(getCameraInfo())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getCameraInfo(): HashMap<String, Any> {
        val cameraConfig = arSession?.cameraConfig
        
        return if (cameraConfig != null) {
            val size = cameraConfig.imageSize
            hashMapOf(
                "width" to size.width,
                "height" to size.height,
                "resolution" to "${size.width}x${size.height}",
                "configured" to true
            )
        } else {
            hashMapOf(
                "width" to 0,
                "height" to 0,
                "resolution" to "not configured",
                "configured" to false
            )
        }
    }

    fun placeModel(latitude: Double, longitude: Double, altitude: Double) {
        try {
            val earth = arSession?.earth
            
            if (earth == null || earth.trackingState != TrackingState.TRACKING) {
                Log.w(TAG, "⚠️ Earth não está tracking. State: ${earth?.trackingState}")
                return
            }
            
            // Criar anchor geoespacial
            val anchor = earth.createAnchor(latitude, longitude, altitude, 0f, 0f, 0f, 1f)
            anchors.add(anchor)
            
            Log.d(TAG, "✅ Anchor criado em lat=$latitude, lon=$longitude, alt=$altitude")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Erro ao criar anchor: ${e.message}", e)
        }
    }

    fun getVPSStatus(): HashMap<String, Any> {
        val earth = arSession?.earth
        val cameraConfig = arSession?.cameraConfig
        
        if (earth == null) {
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
                "objectCount" to 0,
                "cameraInfo" to "session not initialized",
                "gpsDiscrepancy" to false,
                "indoorDetected" to false,
                "indoorMessage" to ""
            )
        }
        
        val pose = earth.cameraGeospatialPose
        val isTracking = earth.trackingState == TrackingState.TRACKING
        
        val cameraInfo = if (cameraConfig != null) {
            val size = cameraConfig.imageSize
            "${size.width}x${size.height}"
        } else {
            "camera not configured"
        }
        
        // NOVO: Detectar discrepância GPS (Android tem, ARCore não)
        var gpsDiscrepancy = false
        var indoorDetected = false
        var indoorMessage = ""
        
        val activity = getActivity(context)
        if (activity != null && ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
            try {
                val locationManager = activity.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                val lastGps = locationManager?.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                
                if (lastGps != null && pose.latitude == 0.0 && pose.longitude == 0.0 && lastGps.latitude != 0.0) {
                    gpsDiscrepancy = true
                    
                    // Verificar IDADE do GPS (cache vs. ativo)
                    val ageSeconds = (System.currentTimeMillis() - lastGps.time) / 1000
                    val isOldCache = ageSeconds > 60  // Cache com mais de 1 minuto
                    
                    indoorDetected = true
                    
                    // Mensagem adaptada com idade do GPS
                    indoorMessage = if (isOldCache) {
                        "🚨 PROBLEMA CRÍTICO: GPS NÃO ESTÁ ATUALIZANDO!\n\n" +
                        "⏰ GPS Android: CACHE ANTIGO (${ageSeconds}s = ${ageSeconds/60}min)\n" +
                        "   Lat=${String.format("%.6f", lastGps.latitude)}, Lon=${String.format("%.6f", lastGps.longitude)}\n" +
                        "❌ ARCore: REJEITOU cache antigo (correto!)\n" +
                        "   Lat=0.000000, Lon=0.000000\n\n" +
                        "📡 CAUSA:\n" +
                        "GPS não consegue FIXAR satélites (sinal bloqueado).\n" +
                        "Janela/varanda NÃO é suficiente - precisa sky view DIRETO.\n\n" +
                        "✅ SOLUÇÃO (ordem de prioridade):\n" +
                        "1️⃣ Ir para RUA/EXTERIOR (fora do prédio)\n" +
                        "2️⃣ Telhado/terraço com céu aberto\n" +
                        "3️⃣ Campo aberto/praça\n" +
                        "4️⃣ Aguardar 30-60s para GPS fixar satélites\n" +
                        "5️⃣ Apontar para EDIFÍCIOS (VPS precisa landmarks)\n\n" +
                        "❌ NÃO FUNCIONA:\n" +
                        "• Perto de janela (vidro bloqueia)\n" +
                        "• Varanda com cobertura\n" +
                        "• Interior de qualquer tipo\n\n" +
                        "💡 TESTE RÁPIDO:\n" +
                        "Abra Google Maps e veja se localização ATUALIZA.\n" +
                        "Se Maps mostrar localização parada = GPS bloqueado."
                    } else {
                        "🏠 PROBLEMA: GPS recente mas ARCore não aceita\n\n" +
                        "✅ Android GPS: ${String.format("%.6f", lastGps.latitude)}, ${String.format("%.6f", lastGps.longitude)} (${ageSeconds}s)\n" +
                        "❌ ARCore: 0.000000, 0.000000\n\n" +
                        "📡 CAUSA:\n" +
                        "ARCore precisa GPS ATIVO (streaming), não snapshot.\n\n" +
                        "✅ SOLUÇÃO:\n" +
                        "• Sair para RUA (exterior completo)\n" +
                        "• Aguardar GPS estabilizar (30s)\n" +
                        "• Apontar para edifícios/landmarks"
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Erro ao verificar GPS discrepancy: ${e.message}")
            }
        }
        
        val status: HashMap<String, Any> = hashMapOf(
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
            "objectCount" to anchors.size,
            "cameraInfo" to cameraInfo,
            "gpsDiscrepancy" to gpsDiscrepancy,
            "indoorDetected" to indoorDetected,
            "indoorMessage" to indoorMessage
        )
        
        // Log detalhado a cada 2 segundos (para não poluir muito)
        val currentTime = System.currentTimeMillis()
        if (currentTime - lastLogTime > 2000) {
            lastLogTime = currentTime
            
            val emoji = when {
                isTracking && pose.horizontalAccuracy < 10 -> "✅"
                earth.trackingState == TrackingState.PAUSED -> "⏸️"
                earth.trackingState == TrackingState.STOPPED -> "⏹️"
                else -> "🔄"
            }
            
            Log.d(TAG, "$emoji VPS Status: ${earth.earthState} / ${earth.trackingState}")
            Log.d(TAG, "   📍 ARCore Earth: Lat=${String.format("%.6f", pose.latitude)}, Lon=${String.format("%.6f", pose.longitude)}, Alt=${String.format("%.1f", pose.altitude)}m")
            Log.d(TAG, "   🎯 Precisão: H=${String.format("%.1f", pose.horizontalAccuracy)}m, V=${String.format("%.1f", pose.verticalAccuracy)}m")
            
            // NOVO: Comparar com LocationManager
            val activity = getActivity(context)
            if (activity != null && ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                try {
                    val locationManager = activity.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                    val lastGps = locationManager?.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                    if (lastGps != null) {
                        val ageSeconds = (System.currentTimeMillis() - lastGps.time) / 1000
                        val ageMinutes = ageSeconds / 60
                        val ageColor = if (ageSeconds < 5) "🟢" else if (ageSeconds < 60) "🟡" else "🔴"
                        
                        Log.d(TAG, "   🗺️ Android GPS: Lat=${String.format("%.6f", lastGps.latitude)}, " +
                                  "Lon=${String.format("%.6f", lastGps.longitude)}, " +
                                  "Acc=${String.format("%.1f", lastGps.accuracy)}m, " +
                                  "$ageColor Idade=${ageSeconds}s (${ageMinutes}min)")
                        
                        // Detectar se ARCore não está vendo o GPS do Android
                        if (pose.latitude == 0.0 && pose.longitude == 0.0 && lastGps.latitude != 0.0) {
                            if (ageSeconds > 60) {
                                Log.e(TAG, "   🚨 GPS CACHE ANTIGO! ARCore correto em rejeitar (>60s)")
                                Log.e(TAG, "      → GPS não está FIXANDO satélites novos")
                                Log.e(TAG, "      → Precisa sair para EXTERIOR COMPLETO (não janela)")
                            } else {
                                Log.e(TAG, "   🚨 GPS recente mas ARCore não aceita")
                                Log.e(TAG, "      → ARCore precisa GPS stream ativo, não snapshot")
                            }
                        }
                    } else {
                        Log.w(TAG, "   🗺️ Android GPS: Sem última localização conhecida")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "   ❌ Erro ao ler GPS do Android: ${e.message}")
                }
            }
            
            // Diagnóstico específico quando PAUSED
            if (earth.trackingState == TrackingState.PAUSED) {
                when (earth.earthState) {
                    Earth.EarthState.ENABLED -> {
                        Log.w(TAG, "   ⚠️ VPS HABILITADO mas NÃO consegue tracking")
                        Log.w(TAG, "   💡 Possíveis causas:")
                        Log.w(TAG, "      1️⃣ Área SEM cobertura VPS do Google")
                        Log.w(TAG, "      2️⃣ Está em INTERIOR (VPS funciona melhor FORA)")
                        Log.w(TAG, "      3️⃣ Sem features reconhecíveis (edifícios, landmarks)")
                        Log.w(TAG, "      4️⃣ GPS com sinal fraco (precisão=${String.format("%.1f", pose.horizontalAccuracy)}m)")
                        Log.w(TAG, "   🔧 Soluções:")
                        Log.w(TAG, "      → Sair PARA RUA/área aberta")
                        Log.w(TAG, "      → Apontar para EDIFÍCIOS/estruturas")
                        Log.w(TAG, "      → Mover celular LENTAMENTE")
                        Log.w(TAG, "      → Aguardar GPS melhorar")
                    }
                    Earth.EarthState.ERROR_RESOURCE_EXHAUSTED -> {
                        Log.e(TAG, "   ❌ ERRO: Recursos esgotados (muitas sessions ativas?)")
                    }
                    Earth.EarthState.ERROR_NOT_AUTHORIZED -> {
                        Log.e(TAG, "   ❌ ERRO: API Key inválida ou sem autorização")
                        Log.e(TAG, "   🔑 Verificar chave em AndroidManifest.xml")
                    }
                    Earth.EarthState.ERROR_INTERNAL -> {
                        Log.e(TAG, "   ❌ ERRO: Erro interno do ARCore")
                    }
                    else -> {
                        Log.w(TAG, "   ⚠️ Estado: ${earth.earthState}")
                    }
                }
            } else if (isTracking) {
                if (pose.horizontalAccuracy < 5) {
                    Log.d(TAG, "   ✅ EXCELENTE precisão - pronto para placement!")
                } else if (pose.horizontalAccuracy < 10) {
                    Log.d(TAG, "   ✅ BOA precisão - pode fazer placement")
                } else {
                    Log.w(TAG, "   ⚠️ Precisão BAIXA - mover mais para melhorar")
                }
            }
        }
        
        return status
    }
    
    private var lastLogTime: Long = 0  // Para throttling de logs

    override fun getView(): View = containerView

    override fun dispose() {
        Log.d(TAG, "🧹 Dispose (PlatformView)")
        try {
            // Detach anchors
            anchors.forEach { it.detach() }
            anchors.clear()
            
            // IMPORTANTE: Usar Singleton release em vez de pause direto
            isSessionResumed = false
            arSession = null  // Soltar referência local
            
            releaseSession()  // Decrementar contador + destruir se necessário
            
            textureView = null
        } catch (e: Exception) {
            Log.w(TAG, "Erro ao dispose: ${e.message}", e)
        }
    }
}