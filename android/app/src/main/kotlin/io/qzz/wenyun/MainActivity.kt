package io.qzz.wenyun

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "io.qzz.wenyun/mihomo"
        private const val VPN_REQUEST_CODE = 1001
        private const val NOTIFICATION_REQUEST_CODE = 1002
    }

    private var pendingVpnResult: MethodChannel.Result? = null
    private var methodChannel: MethodChannel? = null
    private var initialUrlConsumed = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MihomoCore.ensureLoaded(this)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler {
                call,
                result,
            ->
            try {
                when (call.method) {
                    "startVpn" -> requestVpn(result)
                    "stopVpn" -> {
                        stopVpn()
                        result.success(true)
                    }
                    "isVpnRunning" -> result.success(ClashService.isRunning)
                    "startService" -> {
                        MihomoCore.start(this) { success, error ->
                            runOnUiThread {
                                if (success) {
                                    result.success(true)
                                } else {
                                    result.error("MIHOMO_START_FAILED", error ?: "Unknown Mihomo error", null)
                                }
                            }
                        }
                    }
                    "setConfig" -> {
                        val path = call.argument<String>("config").orEmpty()
                        result.success(path.isNotBlank() && File(path).isFile)
                    }
                    "setHomeDir" -> {
                        result.success(MihomoCore.setHomeDir(call.argument<String>("dir").orEmpty()))
                    }
                    "startRust" -> {
                        // Mihomo exposes its Clash-compatible controller directly.
                        result.success(
                            MihomoCore.resolveController(call.argument<String>("addr").orEmpty()),
                        )
                    }
                    "invokeAction" -> {
                        val method = call.argument<String>("method").orEmpty()
                        if (method.isBlank()) {
                            result.error("MIHOMO_ACTION_INVALID", "Missing action method", null)
                        } else {
                            MihomoCore.invokeAction(method, call.argument<Any?>("data")) { response ->
                                runOnUiThread { result.success(response) }
                            }
                        }
                    }
                    "verifyMMDB" -> {
                        val file = File(call.argument<String>("path").orEmpty())
                        result.success(file.isFile && file.length() > 0)
                    }
                    "getInitialUrl" -> {
                        val value = if (initialUrlConsumed) null else intent?.dataString
                        initialUrlConsumed = true
                        result.success(value)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                result.error("MIHOMO_ERROR", error.message, null)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.dataString?.let { methodChannel?.invokeMethod("protocolUrl", it) }
    }

    private fun requestVpn(result: MethodChannel.Result) {
        if (pendingVpnResult != null) {
            result.error("VPN_BUSY", "A VPN request is already in progress", null)
            return
        }
        pendingVpnResult = result

        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                    PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_REQUEST_CODE,
            )
            return
        }

        requestSystemVpnPermission()
    }

    private fun requestSystemVpnPermission() {
        val permissionIntent = VpnService.prepare(this)
        if (permissionIntent == null) {
            startVpn()
            pendingVpnResult?.success(true)
            pendingVpnResult = null
            return
        }

        @Suppress("DEPRECATION")
        startActivityForResult(permissionIntent, VPN_REQUEST_CODE)
    }

    private fun startVpn() {
        ClashService.start(this)
    }

    private fun stopVpn() {
        ClashService.stop(this)
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != VPN_REQUEST_CODE) return

        val result = pendingVpnResult
        pendingVpnResult = null
        if (resultCode == RESULT_OK) {
            startVpn()
            result?.success(true)
        } else {
            result?.error("VPN_DENIED", "VPN permission denied", null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_REQUEST_CODE) {
            // A denied notification permission must not make the VPN unusable. Android still
            // exposes a running foreground service in Task Manager; the user can enable normal
            // notifications later from system settings.
            requestSystemVpnPermission()
        }
    }

    override fun onDestroy() {
        pendingVpnResult?.error("ACTIVITY_DESTROYED", "VPN request cancelled", null)
        pendingVpnResult = null
        methodChannel = null
        super.onDestroy()
    }
}
