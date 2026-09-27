package io.qzz.wenyun

import android.content.Context
import android.os.Build
import io.github.oviron.libmihomo.Clash
import org.json.JSONObject

object MihomoCore {
    @Volatile
    private var homeDir: String? = null

    @Volatile
    private var running = false

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
        val initParams =
            """{"home-dir":${JSONObject.quote(directory)},"version":${Build.VERSION.SDK_INT}}"""
        Clash.quickSetup(initParams, """{"selected-map":{}}""") { error ->
            running = error.isNullOrEmpty()
            callback(running, error)
        }
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
