package com.example.aigc_studio

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.net.URLConnection

class MainActivity : FlutterActivity() {
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestGalleryExportPermission" -> requestGalleryExportPermission(result)
                "saveImageToGallery" -> {
                    val imagePath = call.argument<String>("path")
                    if (imagePath.isNullOrBlank()) {
                        result.error("invalid_argument", "Image path is required.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(saveImageToGallery(imagePath))
                    } catch (error: Exception) {
                        result.error("gallery_export_failed", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (requestCode == WRITE_EXTERNAL_STORAGE_REQUEST_CODE) {
            val result = pendingPermissionResult
            pendingPermissionResult = null
            if (result == null) return

            val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
            if (granted) {
                result.success("granted")
                return
            }

            val permanentlyDenied =
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                    !shouldShowRequestPermissionRationale(
                        Manifest.permission.WRITE_EXTERNAL_STORAGE,
                    )
            result.success(if (permanentlyDenied) "permanently_denied" else "denied")
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun requestGalleryExportPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success("granted")
            return
        }

        if (checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED) {
            result.success("granted")
            return
        }

        if (pendingPermissionResult != null) {
            result.error("permission_request_active", "A gallery permission request is already active.", null)
            return
        }

        pendingPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
            WRITE_EXTERNAL_STORAGE_REQUEST_CODE,
        )
    }

    private fun saveImageToGallery(imagePath: String): String {
        val sourceFile = File(imagePath)
        if (!sourceFile.exists()) {
            throw IllegalArgumentException("Image file does not exist: $imagePath")
        }

        val mimeType = URLConnection.guessContentTypeFromName(sourceFile.name) ?: "image/png"
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveImageWithMediaStore(sourceFile, mimeType)
        } else {
            saveImageWithLegacyExternalStorage(sourceFile, mimeType)
        }
    }

    private fun saveImageWithMediaStore(
        sourceFile: File,
        mimeType: String,
    ): String {
        val resolver = applicationContext.contentResolver
        val values =
            ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, sourceFile.name)
                put(MediaStore.Images.Media.MIME_TYPE, mimeType)
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_PICTURES}/AIGC Studio",
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }

        val uri =
            resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Could not create gallery image entry.")

        try {
            resolver.openOutputStream(uri)?.use { output ->
                FileInputStream(sourceFile).use { input ->
                    input.copyTo(output)
                }
            } ?: throw IllegalStateException("Could not open gallery output stream.")

            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return uri.toString()
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    private fun saveImageWithLegacyExternalStorage(
        sourceFile: File,
        mimeType: String,
    ): String {
        val picturesDirectory =
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
        val appDirectory = File(picturesDirectory, "AIGC Studio")
        if (!appDirectory.exists() && !appDirectory.mkdirs()) {
            throw IllegalStateException("Could not create gallery directory.")
        }

        val destination = uniqueDestination(appDirectory, sourceFile.name)
        sourceFile.copyTo(destination, overwrite = false)
        MediaScannerConnection.scanFile(
            applicationContext,
            arrayOf(destination.absolutePath),
            arrayOf(mimeType),
            null,
        )
        return destination.absolutePath
    }

    private fun uniqueDestination(
        directory: File,
        fileName: String,
    ): File {
        val dotIndex = fileName.lastIndexOf('.')
        val baseName = if (dotIndex > 0) fileName.substring(0, dotIndex) else fileName
        val extension = if (dotIndex > 0) fileName.substring(dotIndex) else ""
        var candidate = File(directory, fileName)
        var index = 1
        while (candidate.exists()) {
            candidate = File(directory, "$baseName-$index$extension")
            index += 1
        }
        return candidate
    }

    companion object {
        private const val CHANNEL = "aigc_studio/media"
        private const val WRITE_EXTERNAL_STORAGE_REQUEST_CODE = 2401
    }
}
