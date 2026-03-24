package com.videoenhancer.videoenhancerapp

import android.media.MediaScannerConnection
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "videoenhancerapp/media_scanner"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanFile" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("missing_path", "No media path provided.", null)
                        return@setMethodCallHandler
                    }

                    MediaScannerConnection.scanFile(
                        applicationContext,
                        arrayOf(path),
                        null,
                    ) { _, _ -> }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
