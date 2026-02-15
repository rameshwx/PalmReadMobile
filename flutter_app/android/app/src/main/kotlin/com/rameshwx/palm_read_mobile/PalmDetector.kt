package com.rameshwx.palm_read_mobile

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import java.io.Closeable
import kotlin.math.max

class PalmDetector(
    private val context: Context,
    private val modelAssetPath: String,
) : Closeable {
    private var landmarker: HandLandmarker? = null

    @Synchronized
    private fun getLandmarker(): HandLandmarker {
        val existing = landmarker
        if (existing != null) return existing

        val baseOptions = BaseOptions.builder()
            .setModelAssetPath(modelAssetPath)
            .build()

        val options = HandLandmarker.HandLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setRunningMode(RunningMode.IMAGE)
            .setNumHands(1)
            // Keep these permissive to avoid blocking real palm photos.
            .setMinHandDetectionConfidence(0.50f)
            .setMinHandPresenceConfidence(0.50f)
            .setMinTrackingConfidence(0.50f)
            .build()

        val created = HandLandmarker.createFromOptions(context, options)
        landmarker = created
        return created
    }

    fun detectHand(imagePath: String): Boolean {
        val bitmap = loadBitmapWithExifRotation(imagePath, maxSide = 1024)
        val mpImage = BitmapImageBuilder(bitmap).build()
        val result = getLandmarker().detect(mpImage)
        return result.landmarks().isNotEmpty()
    }

    override fun close() {
        landmarker?.close()
        landmarker = null
    }

    private fun loadBitmapWithExifRotation(path: String, maxSide: Int): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)

        var sampleSize = 1
        val outW = bounds.outWidth
        val outH = bounds.outHeight
        if (outW > 0 && outH > 0) {
            while (max(outW / sampleSize, outH / sampleSize) > maxSide) {
                sampleSize *= 2
            }
        }

        val opts = BitmapFactory.Options().apply {
            inSampleSize = sampleSize
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val decoded = BitmapFactory.decodeFile(path, opts)
            ?: throw IllegalArgumentException("Failed to decode image.")

        val rotation = try {
            val exif = ExifInterface(path)
            when (
                exif.getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL
                )
            ) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90
                ExifInterface.ORIENTATION_ROTATE_180 -> 180
                ExifInterface.ORIENTATION_ROTATE_270 -> 270
                else -> 0
            }
        } catch (_: Exception) {
            0
        }

        if (rotation == 0) return decoded

        val m = Matrix().apply { postRotate(rotation.toFloat()) }
        val rotated = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, m, true)
        decoded.recycle()
        return rotated
    }
}

