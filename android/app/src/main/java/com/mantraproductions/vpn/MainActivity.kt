package com.mantraproductions.vpn

// VPN (Mantra) on the phone: one switch, FRANKFURT | DIRECT, and what the internet sees (public IP, country, city,
// provider). The lit word is decided by the internet itself: the public address in Germany = FRANKFURT. CAMERA language
// (green on, grey off, amber warning), portrait first, system bars + cutout + 16 dp on every side.

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material3.Text
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import kotlin.concurrent.thread

private val BG = Color(0xFF15181B)
private val GREEN = Color(0xFF33D17A)
private val GREY = Color(0xFF7A8087)
private val AMBER = Color(0xFFE8A33D)
private val DARK = Color(0xFF33383E)
private val TEXT = Color(0xFFE6E8EA)
private val LINE = Color(0x1FFFFFFF)
private const val REPO_URL = "https://github.com/markoboskoauroville/MANTRA_VPN"

class MainActivity : ComponentActivity() {
    private var ip by mutableStateOf("")
    private var country by mutableStateOf("")
    private var city by mutableStateOf("")
    private var org by mutableStateOf("")
    private var ipState by mutableStateOf("…")
    private var busy by mutableStateOf("")
    private var installed by mutableStateOf(true)
    private var vpnUp by mutableStateOf(false)
    private val main = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { Screen() }
        AppUpdater.checkAtStart(this)
    }

    override fun onResume() {
        super.onResume()
        AppUpdater.resume(this)
        installed = TailscaleCtl.installed(this)
        vpnUp = TailscaleCtl.vpnUp(this)
        checkIp()
    }

    private val frankfurt: Boolean get() = country == "DE"

    private fun press(which: String) {
        if (busy.isNotEmpty()) return
        if (!installed) { TailscaleCtl.openTailscale(this); return }
        busy = which
        if (which == "FRANKFURT") TailscaleCtl.frankfurt(this) else TailscaleCtl.direct(this)
        // the switch takes a few seconds inside Tailscale; then the internet is asked where we are
        main.postDelayed({ vpnUp = TailscaleCtl.vpnUp(this); checkIp(done = true) }, 6000)
    }

    private fun checkIp(done: Boolean = false) {
        ipState = "…"
        thread(name = "ip") {
            var j: JSONObject? = null
            var err = ""
            try {
                val c = URL("https://ipinfo.io/json").openConnection() as HttpURLConnection
                c.connectTimeout = 8000; c.readTimeout = 8000; c.useCaches = false
                c.setRequestProperty("Accept", "application/json")
                j = JSONObject(c.inputStream.bufferedReader().use { it.readText() })
            } catch (e: Exception) { err = "no answer" }
            val got = j
            runOnUiThread {
                if (got != null) {
                    val j = got
                    ip = j.optString("ip"); city = j.optString("city"); org = j.optString("org")
                    country = j.optString("country")
                    ipState = ""
                } else ipState = err
                if (done) busy = ""
            }
        }
    }

    private fun countryName(code: String): String =
        if (code.isEmpty()) "" else Locale("", code).getDisplayCountry(Locale.ENGLISH).ifEmpty { code }

    @Composable
    private fun Word(word: String, color: Color, size: Int = 14, onClick: () -> Unit) {
        Text(
            word,
            color = color,
            style = TextStyle(fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Bold, fontSize = size.sp,
                letterSpacing = (size * 0.04).sp),
            modifier = Modifier.clickable(role = Role.Button, onClick = onClick).padding(vertical = 6.dp),
        )
    }

    @Composable
    private fun Hairline() {
        Box(Modifier.fillMaxWidth().padding(vertical = 12.dp).height(1.dp).background(LINE))
    }

    @Composable
    private fun Cell(label: String, value: String, color: Color = TEXT) {
        Column(Modifier.fillMaxWidth().padding(vertical = 6.dp)) {
            Text(label, color = GREY, style = TextStyle(fontFamily = FontFamily.Monospace, fontWeight = FontWeight.SemiBold, fontSize = 10.sp))
            Text(value.ifEmpty { "—" }, color = color,
                style = TextStyle(fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Bold, fontSize = 16.sp))
            Box(Modifier.fillMaxWidth().padding(top = 4.dp).height(1.dp).background(LINE))
        }
    }

    @Composable
    private fun Screen() {
        Column(
            Modifier.fillMaxSize().background(BG).windowInsetsPadding(WindowInsets.safeDrawing)
                .padding(16.dp).verticalScroll(rememberScrollState())
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("VPN (Mantra)", color = TEXT,
                    style = TextStyle(fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Bold, fontSize = 14.sp))
                Spacer(Modifier.weight(1f))
                if (!installed) Word("GET TAILSCALE", AMBER) { TailscaleCtl.openTailscale(this@MainActivity) }
                Word("v${BuildConfig.VERSION_NAME}", GREY) {
                    runCatching { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("$REPO_URL/releases/latest"))) }
                }
            }
            Hairline()
            Word("FRANKFURT",
                when { busy == "FRANKFURT" -> AMBER; frankfurt -> GREEN; !installed -> DARK; else -> GREY }, 40) { press("FRANKFURT") }
            Word("DIRECT",
                when { busy == "DIRECT" -> AMBER; frankfurt -> GREY; else -> GREEN }, 40) { press("DIRECT") }
            if (!installed) {
                Text("Tailscale is not on this phone. Install it and sign in once; then FRANKFURT works.",
                    color = AMBER, style = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 12.sp),
                    modifier = Modifier.padding(top = 6.dp))
            }
            Hairline()
            Cell("PUBLIC IP", if (ipState.isEmpty()) ip else ipState, if (ipState.isEmpty()) TEXT else GREY)
            Cell("COUNTRY", countryName(country))
            Cell("CITY", city)
            Cell("PROVIDER", org)
            Cell("EXIT NODE", TailscaleCtl.EXIT_NODE)
            Cell("TAILSCALE", when { !installed -> "NOT INSTALLED"; vpnUp -> "ON"; else -> "OFF" },
                if (installed && vpnUp) GREEN else AMBER)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                Word("CHECK IP", GREY, 12) { vpnUp = TailscaleCtl.vpnUp(this@MainActivity); checkIp() }
            }
        }
    }
}
