package com.qlnext.android

import android.app.Activity
import android.content.Intent
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "qinglong/file_picker"
    private val pickerRequestCode = 2301
    private var pendingPickerResult: MethodChannel.Result? = null
    private var pendingOperation: String? = null
    private var pendingSaveBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (pendingPickerResult != null) {
                    result.error("picker_busy", "File picker is already open", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "pickFile" -> {
                        pendingOperation = "pickFile"
                        pendingPickerResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = call.argument<String>("mimeType") ?: "*/*"
                        }
                        startActivityForResult(intent, pickerRequestCode)
                    }
                    "saveFile" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null) {
                            result.error("invalid_bytes", "File contents are missing", null)
                            return@setMethodCallHandler
                        }
                        pendingOperation = "saveFile"
                        pendingSaveBytes = bytes
                        pendingPickerResult = result
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = call.argument<String>("mimeType") ?: "*/*"
                            putExtra(
                                Intent.EXTRA_TITLE,
                                call.argument<String>("fileName") ?: "download",
                            )
                        }
                        startActivityForResult(intent, pickerRequestCode)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickerRequestCode) return

        val result = pendingPickerResult
        pendingPickerResult = null
        val operation = pendingOperation
        pendingOperation = null
        if (result == null) return
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pendingSaveBytes = null
            result.success(null)
            return
        }

        try {
            val uri = data.data!!
            if (operation == "saveFile") {
                val bytes = pendingSaveBytes
                pendingSaveBytes = null
                if (bytes == null) {
                    result.error("invalid_bytes", "File contents are missing", null)
                } else {
                    contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                        ?: throw IllegalStateException("Unable to open destination")
                    result.success(uri.toString())
                }
                return
            }
            val name = contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    cursor.getString(cursor.getColumnIndexOrThrow(OpenableColumns.DISPLAY_NAME))
                } else {
                    null
                }
            } ?: "script"
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            if (bytes == null) {
                result.error("read_failed", "Unable to read selected file", null)
            } else {
                result.success(mapOf("name" to name, "bytes" to bytes))
            }
        } catch (error: Exception) {
            result.error("read_failed", error.message, null)
        }
    }
}
