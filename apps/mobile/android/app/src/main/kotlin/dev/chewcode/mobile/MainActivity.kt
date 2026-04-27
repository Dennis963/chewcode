package dev.chewcode.mobile

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.chewcode.mobile/downloads",
        ).setMethodCallHandler { call, result ->
            if (call.method != "enqueueDownload") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val url = call.argument<String>("url")
            val token = call.argument<String>("token")
            val fileName = call.argument<String>("fileName")
            val mimeType = call.argument<String>("mimeType")

            if (url.isNullOrBlank() || token.isNullOrBlank() || fileName.isNullOrBlank()) {
                result.error("invalid_args", "url, token, and fileName are required", null)
                return@setMethodCallHandler
            }

            try {
                val request = DownloadManager.Request(Uri.parse(url))
                    .setTitle(fileName)
                    .setDescription("Downloading from ChewCode")
                    .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                    .setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName)
                    .addRequestHeader("Authorization", "Bearer $token")

                if (!mimeType.isNullOrBlank()) {
                    request.setMimeType(mimeType)
                }

                val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                val downloadId = manager.enqueue(request)
                result.success(downloadId)
            } catch (error: Exception) {
                result.error("download_failed", error.message, null)
            }
        }
    }
}
