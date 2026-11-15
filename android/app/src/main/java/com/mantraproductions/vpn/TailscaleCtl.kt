package com.mantraproductions.vpn

// Android lets one VPN run at a time, and on Marko's phones that one is Tailscale. So this app is not a second VPN: it
// tells the Tailscale app which exit node to use, through the intents Tailscale itself publishes for automation
// (tailscale/tailscale-android, IPNReceiver.java and AutomationActivity, read 15.11.2026):
//   com.tailscale.ipn.CONNECT_VPN / DISCONNECT_VPN        Tailscale on / off
//   com.tailscale.ipn.USE_EXIT_NODE  exitNode=<name>      the exit node by its display name ("" = none, DIRECT)
//                                    allowLanAccess=true  the home network stays reachable
// No key, no address, no secret is in this app: the exit node is found by name inside the tailnet Tailscale is signed
// in to. On a phone that is not in Marko's tailnet there is no "chromium-vm", and Tailscale says so in a notification.

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Handler
import android.os.Looper

object TailscaleCtl {
    const val PKG = "com.tailscale.ipn"
    const val EXIT_NODE = "chromium-vm"   // the Frankfurt VM's Tailscale name (MANTRA_MANIFEST modules/vpn-exit-node.md)
    private const val CONNECT = "com.tailscale.ipn.CONNECT_VPN"
    private const val USE_EXIT_NODE = "com.tailscale.ipn.USE_EXIT_NODE"

    fun installed(c: Context): Boolean =
        runCatching { c.packageManager.getPackageInfo(PKG, 0); true }.getOrDefault(false)

    /** Some VPN (Tailscale, the only one he uses) is carrying this phone's traffic. */
    fun vpnUp(c: Context): Boolean {
        val cm = c.getSystemService(ConnectivityManager::class.java) ?: return false
        @Suppress("DEPRECATION")
        return cm.allNetworks.any { n -> cm.getNetworkCapabilities(n)?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true }
    }

    /** FRANKFURT: Tailscale on (an activity start wakes a stopped Tailscale reliably), then the exit node. */
    fun frankfurt(a: Activity) {
        try {
            a.startActivity(Intent(CONNECT).setClassName(PKG, "$PKG.AutomationActivity").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (e: ActivityNotFoundException) {
            a.sendBroadcast(Intent(CONNECT).setClassName(PKG, "$PKG.IPNReceiver"))
        } catch (e: SecurityException) {
            a.sendBroadcast(Intent(CONNECT).setClassName(PKG, "$PKG.IPNReceiver"))
        }
        Handler(Looper.getMainLooper()).postDelayed({ exitNode(a, EXIT_NODE) }, 2500)
    }

    /** DIRECT: no exit node; Tailscale itself stays on (adb, Sound Link and the Mac still reach the phone). */
    fun direct(c: Context) = exitNode(c, "")

    private fun exitNode(c: Context, name: String) {
        c.sendBroadcast(Intent(USE_EXIT_NODE).setClassName(PKG, "$PKG.IPNReceiver")
            .putExtra("exitNode", name).putExtra("allowLanAccess", true))
    }

    fun openTailscale(a: Activity) {
        val launch = a.packageManager.getLaunchIntentForPackage(PKG)
        val intent = launch ?: Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$PKG"))
        runCatching { a.startActivity(intent) }
    }
}
