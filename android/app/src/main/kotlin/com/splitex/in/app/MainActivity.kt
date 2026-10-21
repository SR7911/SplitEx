package com.splitex.`in`.app

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        BankSmsStore.foregroundChannel = BankSmsStore.attach(this, flutterEngine, this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.splitex.in.app/install")
            .setMethodCallHandler { call, result ->
                if (call.method == "installApk") {
                    val filePath = call.argument<String>("filePath")!!
                    try {
                        val file = File(filePath)
                        val uri = FileProvider.getUriForFile(this, "${applicationContext.packageName}.fileProvider", file)
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == BankSmsStore.PERMISSION_REQUEST) {
            BankSmsStore.pendingPermission?.success(BankSmsStore.hasPermission(this))
            BankSmsStore.pendingPermission = null
            BankSmsStore.foregroundChannel?.invokeMethod("permissionChanged", null)
        }
    }

    override fun onDestroy() {
        BankSmsStore.pendingPermission?.error("CANCELLED", "Permission request was cancelled.", null)
        BankSmsStore.pendingPermission = null
        BankSmsStore.foregroundChannel = null
        super.onDestroy()
    }
}
