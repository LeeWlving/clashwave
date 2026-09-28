package io.qzz.wenyun

import android.content.Intent
import android.net.VpnService
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

class ClashTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }

    override fun onClick() {
        super.onClick()
        if (ClashService.isRunning || ClashService.shouldRestore(this)) {
            ClashService.stop(this)
            updateTile()
            return
        }

        val permission = VpnService.prepare(this)
        if (permission == null) {
            ClashService.start(this)
        } else {
            startActivityAndCollapse(
                Intent(this, VpnPermissionActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
        updateTile()
    }

    private fun updateTile() {
        qsTile?.apply {
            label = "ClashWave"
            state =
                if (ClashService.isRunning || ClashService.shouldRestore(this@ClashTileService)) {
                    Tile.STATE_ACTIVE
                } else {
                    Tile.STATE_INACTIVE
                }
            updateTile()
        }
    }
}
