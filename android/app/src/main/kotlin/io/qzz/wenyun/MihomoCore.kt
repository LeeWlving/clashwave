package io.qzz.wenyun

import android.content.Context
import android.os.Build
import io.github.oviron.libmihomo.Clash
import java.io.File
import java.util.UUID
import org.json.JSONObject

object MihomoCore {
    @Volatile
    private var homeDir: String? = null

    @Volatile
    private var running = false

    @Volatile
    private var controllerAddress: String? = null

    fun ensureLoaded(context: Context) {
        Clash.load(context.applicationInfo.nativeLibraryDir)
        Clash.assertReady()
    }

    fun setHomeDir(path: String): Boolean {
        homeDir = path
        return path.isNotBlank()
    }

    fun start(context: Context, callback: (Boolean, String?) -> Unit) {
        ensureLoaded(context)
        if (running) {
            callback(true, null)
            return
        }

        val directory = homeDir ?: context.filesDir.absolutePath
        homeDir = directory
        controllerAddress = readControllerAddress(directory) ?: controllerAddress
        val initParams =
            """{"home-dir":${JSONObject.quote(directory)},"version":${Build.VERSION.SDK_INT}}"""
        Clash.quickSetup(initParams, """{"selected-map":{}}""") { error ->
            running = error.isNullOrEmpty()
            callback(running, error)
        }
    }

    fun resolveController(requested: String): String {
        if (running && !controllerAddress.isNullOrBlank()) return controllerAddress!!
        controllerAddress = requested
        return requested
    }

    fun invokeAction(method: String, data: Any?, callback: (String) -> Unit) {
        val action =
            JSONObject()
                .put("id", UUID.randomUUID().toString())
                .put("method", method)
                .put("data", data ?: JSONObject.NULL)
        Clash.invokeAction(action.toString()) { callback(it.orEmpty()) }
    }

    private fun readControllerAddress(directory: String): String? {
        val config = File(directory, "config.yaml")
        if (!config.isFile) return null
        val match =
            Regex("(?m)^\\s*external-controller\\s*:\\s*['\"]?([^'\"#\\s]+)")
                .find(config.readText())
        return match?.groupValues?.getOrNull(1)
    }

    fun restoreController() {
        Clash.invokeAction(
            """{"id":"restore-controller","method":"startListener","data":null}""",
        ) { result ->
            if (result.isNullOrBlank()) {
                running = false
            }
        }
    }
}
