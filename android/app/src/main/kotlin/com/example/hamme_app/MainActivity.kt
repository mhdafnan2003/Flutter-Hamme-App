package com.example.hamme_app

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "hamme/share_story"
        private const val INSTAGRAM_PACKAGE = "com.instagram.android"
        private const val TAG = "HammeStoryShare"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        Log.d(TAG, "configureFlutterEngine called; initializing channel: $CHANNEL")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            Log.d(TAG, "Received method call: ${call.method}")
            when (call.method) {
                "shareToInstagramStory" -> {
                    val path = call.argument<String>("imagePath")
                    val link = call.argument<String>("attributionUrl")
                    if (path.isNullOrBlank()) {
                        result.error("INVALID_PATH", "imagePath is required", null)
                        return@setMethodCallHandler
                    }
                    shareToSocialStory(path, link, "com.instagram.android", "com.instagram.share.ADD_TO_STORY", "content_url", result)
                }
                "shareToSnapchatStory" -> {
                    val path = call.argument<String>("imagePath")
                    val link = call.argument<String>("attributionUrl")
                    if (path.isNullOrBlank()) {
                        result.error("INVALID_PATH", "imagePath is required", null)
                        return@setMethodCallHandler
                    }
                    shareToSocialStory(path, link, "com.snapchat.android", "com.snapchat.android.intent.action.ADD_STORY_CONTENT", "attachmentUrl", result)
                }
                "isInstagramInstalled" -> {
                    result.success(isPackageInstalled("com.instagram.android"))
                }
                "isSnapchatInstalled" -> {
                    result.success(isPackageInstalled("com.snapchat.android"))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun shareToSocialStory(imagePath: String, attributionUrl: String?, packageName: String, action: String, urlKey: String, result: MethodChannel.Result) {
        try {
            Log.d(TAG, "shareToSocialStory called for $packageName")
            val imageFile = File(imagePath)
            if (!imageFile.exists()) {
                result.error("FILE_NOT_FOUND", "PNG file does not exist at path: $imagePath", null)
                return
            }

            val authority = "${applicationContext.packageName}.fileprovider"
            val contentUri: Uri = FileProvider.getUriForFile(applicationContext, authority, imageFile)

            val intent = Intent(action).apply {
                setDataAndType(contentUri, "image/png")
                flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
                setPackage(packageName)
                if (!attributionUrl.isNullOrBlank()) {
                    putExtra(urlKey, attributionUrl)
                }
            }

            val canHandle = intent.resolveActivity(packageManager) != null
            if (!canHandle) {
                result.success("${packageName.uppercase()}_INTENT_NOT_RESOLVED")
                return
            }

            grantUriPermission(
                packageName,
                contentUri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )

            startActivity(intent)
            result.success("SUCCESS")
        } catch (e: Exception) {
            Log.e(TAG, "Exception while launching social story share", e)
            result.error("LAUNCH_FAILED", e.message, e.stackTraceToString())
        }
    }
}
