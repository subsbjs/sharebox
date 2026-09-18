package com.sharebox.sharebox

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var directoryResult: MethodChannel.Result? = null
    private val storageWorker = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sharebox/storage")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "chooseDirectory" -> {
                        if (directoryResult != null) {
                            result.error("BUSY", "文件夹选择器已打开", null)
                        } else {
                            directoryResult = result
                            try {
                                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                        Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                                        Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                                }
                                startActivityForResult(intent, 7142)
                            } catch (e: Exception) {
                                directoryResult = null
                                result.error("PICK_FAILED", "无法打开系统文件夹选择器：${e.message}", null)
                            }
                        }
                    }
                    "saveFile" -> {
                        val uri = call.argument<String>("uri")
                        val name = call.argument<String>("name")
                        val mime = call.argument<String>("mimeType") ?: "application/octet-stream"
                        val bytes = call.argument<ByteArray>("bytes")
                        if (uri == null || name == null || bytes == null) {
                            result.error("INVALID", "缺少保存参数", null)
                        } else {
                            storageWorker.execute {
                                var created: Uri? = null
                                try {
                                    val tree = Uri.parse(uri)
                                    val granted = contentResolver.persistedUriPermissions.any {
                                        it.uri == tree && it.isWritePermission
                                    }
                                    if (!granted) throw SecurityException("文件夹授权已失效，请在设置中重新选择")
                                    val parent = DocumentsContract.buildDocumentUriUsingTree(
                                        tree, DocumentsContract.getTreeDocumentId(tree))
                                    val names = mutableSetOf<String>()
                                    val children = DocumentsContract.buildChildDocumentsUriUsingTree(
                                        tree, DocumentsContract.getTreeDocumentId(tree))
                                    contentResolver.query(children,
                                        arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                                        null, null, null)?.use { cursor ->
                                        while (cursor.moveToNext()) names.add(cursor.getString(0))
                                    }
                                    val dot = name.lastIndexOf('.')
                                    val base = if (dot > 0) name.substring(0, dot) else name
                                    val ext = if (dot > 0) name.substring(dot) else ""
                                    var candidate = name
                                    var suffix = 1
                                    while (names.contains(candidate)) {
                                        candidate = "$base (${suffix++})$ext"
                                    }
                                    val document = DocumentsContract.createDocument(
                                        contentResolver, parent, mime, candidate)
                                        ?: throw IllegalStateException("无法在此文件夹创建文件")
                                    created = document
                                    val stream = contentResolver.openOutputStream(document, "w")
                                        ?: throw IllegalStateException("无法写入此文件夹")
                                    stream.use { it.write(bytes); it.flush() }
                                    var actualName = candidate
                                    contentResolver.query(document,
                                        arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                                        null, null, null)?.use { cursor ->
                                        if (cursor.moveToFirst()) actualName = cursor.getString(0)
                                    }
                                    runOnUiThread { result.success(actualName) }
                                } catch (e: Exception) {
                                    created?.let {
                                        try { DocumentsContract.deleteDocument(contentResolver, it) }
                                        catch (_: Exception) { }
                                    }
                                    runOnUiThread {
                                        result.error("SAVE_FAILED",
                                            "保存失败，请检查空间和文件夹权限，必要时在设置中重新选择。${e.message}", null)
                                    }
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Activity result bridge for system document picker")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != 7142) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = directoryResult ?: return
        directoryResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            val flags = (data?.flags ?: 0) and (Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            if (flags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION == 0) {
                throw SecurityException("请选择允许写入的文件夹")
            }
            contentResolver.takePersistableUriPermission(uri, flags)
            result.success(mapOf("uri" to uri.toString(),
                "label" to DocumentsContract.getTreeDocumentId(uri)))
        } catch (e: Exception) {
            result.error("PERMISSION", "无法保留此文件夹的写入授权：${e.message}", null)
        }
    }

    override fun onDestroy() {
        directoryResult?.error("CANCELLED", "文件夹选择已取消", null)
        directoryResult = null
        storageWorker.shutdown()
        super.onDestroy()
    }
}
