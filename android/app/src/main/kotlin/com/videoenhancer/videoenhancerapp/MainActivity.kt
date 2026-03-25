package com.videoenhancer.videoenhancerapp

import android.media.MediaScannerConnection
import com.mr.flutter.plugin.filepicker.FilePickerPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.flutter_plugin_android_lifecycle.FlutterAndroidLifecyclePlugin
import io.flutter.plugins.videoplayer.VideoPlayerPlugin
import xyz.justsoft.video_thumbnail.VideoThumbnailPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (!flutterEngine.plugins.has(FilePickerPlugin::class.java)) {
            flutterEngine.plugins.add(FilePickerPlugin())
        }
        if (!flutterEngine.plugins.has(FlutterAndroidLifecyclePlugin::class.java)) {
            flutterEngine.plugins.add(FlutterAndroidLifecyclePlugin())
        }
        if (!flutterEngine.plugins.has(VideoPlayerPlugin::class.java)) {
            flutterEngine.plugins.add(VideoPlayerPlugin())
        }
        if (!flutterEngine.plugins.has(VideoThumbnailPlugin::class.java)) {
            flutterEngine.plugins.add(VideoThumbnailPlugin())
        }

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
