package com.housear.house_ar

import android.content.Context
import android.opengl.GLES20
import android.opengl.Matrix
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * Renderer genérico para modelos 3D.
 * Por agora usa formas geométricas simples (cube, sphere placeholder).
 * TODO: Adicionar suporte para carregar glTF/glb real quando necessário.
 */
class ModelRenderer(private val context: Context) {
    private val TAG = "ModelRenderer"
    
    // Por agora, delega para CubeRenderer como placeholder
    private val cubeRenderer = CubeRenderer()
    
    fun createOnGlThread() {
        cubeRenderer.createOnGlThread(context)
        Log.d(TAG, "ModelRenderer criado (usando placeholder geométrico)")
    }
    
    /**
     * Desenha o modelo na pose especificada.
     * @param modelType Tipo de modelo ("cube", "duck", "house", etc.) - por agora todos usam cube
     * @param modelMatrix Matriz de transformação do modelo (do anchor)
     * @param viewMatrix Matriz view da câmera
     * @param projMatrix Matriz de projeção da câmera
     */
    fun draw(
        modelType: String,
        modelMatrix: FloatArray,
        viewMatrix: FloatArray,
        projMatrix: FloatArray
    ) {
        // Por agora, todos os tipos usam o cube placeholder
        // TODO: Quando implementarmos glTF loader, switch baseado em modelType ou URI
        cubeRenderer.draw(modelMatrix, viewMatrix, projMatrix)
    }
    
    /**
     * Carrega modelo de URI (glTF/glb).
     * TODO: Implementar download + parse assíncrono.
     */
    fun loadModelFromUri(uri: String) {
        Log.d(TAG, "📦 ModelRenderer.loadModelFromUri($uri) — placeholder por agora")
        // TODO: Download glTF, parse com biblioteca leve (tinyglTF ou manual)
        // e criar buffers OpenGL para rendering
    }
}
