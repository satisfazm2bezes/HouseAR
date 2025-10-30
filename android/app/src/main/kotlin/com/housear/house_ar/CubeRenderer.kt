package com.housear.house_ar

import android.content.Context
import android.opengl.GLES20
import android.opengl.Matrix
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * Simple cube renderer used as a generic placeholder for anchors.
 * Escala ajustável para representar modelos de diferentes tamanhos.
 */
class CubeRenderer {
    private val TAG = "CubeRenderer"

    // Tamanho GIGANTE para debug - 50 metros total (visível de muito longe!)
    private val BASE_SIZE = 25.0f // 25m = cubo de 50m total
    
    private val cubeCoords = floatArrayOf(
        // 12 triangles (36 vertices) for a cube
        -BASE_SIZE, -BASE_SIZE,  BASE_SIZE,
         BASE_SIZE, -BASE_SIZE,  BASE_SIZE,
        -BASE_SIZE,  BASE_SIZE,  BASE_SIZE,
         BASE_SIZE, -BASE_SIZE,  BASE_SIZE,
         BASE_SIZE,  BASE_SIZE,  BASE_SIZE,
        -BASE_SIZE,  BASE_SIZE,  BASE_SIZE,
        BASE_SIZE, -BASE_SIZE,  BASE_SIZE,
        BASE_SIZE, -BASE_SIZE, -BASE_SIZE,
        BASE_SIZE,  BASE_SIZE,  BASE_SIZE,
        BASE_SIZE, -BASE_SIZE, -BASE_SIZE,
        BASE_SIZE,  BASE_SIZE, -BASE_SIZE,
        BASE_SIZE,  BASE_SIZE,  BASE_SIZE,
        BASE_SIZE, -BASE_SIZE, -BASE_SIZE,
       -BASE_SIZE, -BASE_SIZE, -BASE_SIZE,
        BASE_SIZE,  BASE_SIZE, -BASE_SIZE,
       -BASE_SIZE, -BASE_SIZE, -BASE_SIZE,
       -BASE_SIZE,  BASE_SIZE, -BASE_SIZE,
        BASE_SIZE,  BASE_SIZE, -BASE_SIZE,
       -BASE_SIZE, -BASE_SIZE, -BASE_SIZE,
       -BASE_SIZE, -BASE_SIZE,  BASE_SIZE,
       -BASE_SIZE,  BASE_SIZE, -BASE_SIZE,
       -BASE_SIZE, -BASE_SIZE,  BASE_SIZE,
       -BASE_SIZE,  BASE_SIZE,  BASE_SIZE,
       -BASE_SIZE,  BASE_SIZE, -BASE_SIZE,
       -BASE_SIZE,  BASE_SIZE,  BASE_SIZE,
        BASE_SIZE,  BASE_SIZE,  BASE_SIZE,
       -BASE_SIZE,  BASE_SIZE, -BASE_SIZE,
        BASE_SIZE,  BASE_SIZE,  BASE_SIZE,
        BASE_SIZE,  BASE_SIZE, -BASE_SIZE,
       -BASE_SIZE,  BASE_SIZE, -BASE_SIZE,
       -BASE_SIZE, -BASE_SIZE, -BASE_SIZE,
        BASE_SIZE, -BASE_SIZE, -BASE_SIZE,
       -BASE_SIZE, -BASE_SIZE,  BASE_SIZE,
        BASE_SIZE, -BASE_SIZE, -BASE_SIZE,
        BASE_SIZE, -BASE_SIZE,  BASE_SIZE,
       -BASE_SIZE, -BASE_SIZE,  BASE_SIZE
    )

    private lateinit var vertexBuffer: FloatBuffer
    private var program = 0
    private var aPosition = 0
    private var uMvpMatrix = 0
    private var uColor = 0

    fun createOnGlThread(context: Context) {
        vertexBuffer = ByteBuffer.allocateDirect(cubeCoords.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
        vertexBuffer.put(cubeCoords)
        vertexBuffer.position(0)

        val vertexShaderCode = """
            attribute vec4 aPosition;
            uniform mat4 uMVP;
            void main() {
                gl_Position = uMVP * aPosition;
            }
        """.trimIndent()

        val fragmentShaderCode = """
            precision mediump float;
            uniform vec4 uColor;
            void main() {
                gl_FragColor = uColor;
            }
        """.trimIndent()

        val vert = loadShader(GLES20.GL_VERTEX_SHADER, vertexShaderCode)
        val frag = loadShader(GLES20.GL_FRAGMENT_SHADER, fragmentShaderCode)

        program = GLES20.glCreateProgram()
        GLES20.glAttachShader(program, vert)
        GLES20.glAttachShader(program, frag)
        GLES20.glLinkProgram(program)

        aPosition = GLES20.glGetAttribLocation(program, "aPosition")
        uMvpMatrix = GLES20.glGetUniformLocation(program, "uMVP")
        uColor = GLES20.glGetUniformLocation(program, "uColor")

        Log.d(TAG, "CubeRenderer created program=$program")
    }

    fun draw(modelMatrixIn: FloatArray, viewMatrix: FloatArray, projMatrix: FloatArray) {
        if (program == 0) {
            Log.e(TAG, "❌ CubeRenderer program não inicializado!")
            return
        }

        Log.d(TAG, "🎨 A desenhar cubo (BASE_SIZE=$BASE_SIZE)")

        val viewModel = FloatArray(16)
        val mvp = FloatArray(16)
        Matrix.multiplyMM(viewModel, 0, viewMatrix, 0, modelMatrixIn, 0)
        Matrix.multiplyMM(mvp, 0, projMatrix, 0, viewModel, 0)

        GLES20.glUseProgram(program)

        GLES20.glEnableVertexAttribArray(aPosition)
        GLES20.glVertexAttribPointer(aPosition, 3, GLES20.GL_FLOAT, false, 0, vertexBuffer)

        GLES20.glUniformMatrix4fv(uMvpMatrix, 1, false, mvp, 0)
        // Cor VERMELHO BRILHANTE para máxima visibilidade
        GLES20.glUniform4f(uColor, 1.0f, 0.0f, 0.0f, 1.0f)

        // Reativar depth test para rendering correto
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthFunc(GLES20.GL_LEQUAL)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLES, 0, cubeCoords.size / 3)
        
        val glError = GLES20.glGetError()
        if (glError != GLES20.GL_NO_ERROR) {
            Log.e(TAG, "❌ GL Error: $glError")
        }

        GLES20.glDisableVertexAttribArray(aPosition)
        GLES20.glUseProgram(0)
    }

    private fun loadShader(type: Int, shaderCode: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, shaderCode)
        GLES20.glCompileShader(shader)
        val compiled = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled, 0)
        if (compiled[0] == 0) {
            val info = GLES20.glGetShaderInfoLog(shader)
            GLES20.glDeleteShader(shader)
            throw RuntimeException("Could not compile shader: $info")
        }
        return shader
    }
}
