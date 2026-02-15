package com.rameshwx.palm_read_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "palm_detector"
    private val executor = Executors.newSingleThreadExecutor()
    private var detector: PalmDetector? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // The model is bundled as a Flutter asset (APK path: assets/flutter_assets/...).
        val modelAssetPath = "flutter_assets/assets/models/hand_landmarker.task"
        detector = PalmDetector(this, modelAssetPath)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "detectHand" -> {
                        val imagePath = call.argument<String>("imagePath")
                        if (imagePath.isNullOrBlank()) {
                            result.error("bad_args", "imagePath is required", null)
                            return@setMethodCallHandler
                        }

                        executor.execute {
                            try {
                                val ok = detector?.detectHand(imagePath) ?: false
                                runOnUiThread { result.success(ok) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error(
                                        "detect_failed",
                                        e.message ?: "detect_failed",
                                        null
                                    )
                                }
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        detector?.close()
        detector = null
        executor.shutdown()
        super.onDestroy()
    }
}
