# MANTRA_VPN: takeover

**What it is.** VPN (Mantra): Marko's privacy VPN. The Mac (Swift app, `mac/`) and the phones (Kotlin app, `android/`)
send all their internet through his Oracle VM **chromium-vm in Frankfurt** (public 130.61.181.83), so the world sees a
Frankfurt IP. One switch: **FRANKFURT** (through the VM) | **DIRECT** (straight). Asked 15.11.2026 (momentaryupdates.md,
request 1), "a very simplified version of Connection Keeper".

This repository is public and unpromoted (MANTRA_MANIFEST modules/repo-privacy.md): no README, no description.

## Why there is no secret in it (so GitHub may build it)

Marko's condition: if a stranger who downloads the app could use his Frankfurt machine, it must not be on GitHub. It
cannot: the tunnel is **Tailscale's exit node**. chromium-vm advertises itself as an exit node inside Marko's tailnet;
only devices signed in to that tailnet (his Google login, on each device) see it. The apps carry no key, no auth key, no
address: the Mac app finds the exit node at run time in `tailscale status --json` (peers with `ExitNodeOption`), the
Android app names it (`chromium-vm`) to the Tailscale app, which looks it up in its own tailnet. Anyone else gets
"no exit node". The Android signing keystore is a repository secret (only for updates over each other), never in the tree.

## How it works

- **VM** (repo vm-chromium, TAKEOVER "Exit node"): `/etc/sysctl.d/99-tailscale.conf` (IPv4 + IPv6 forwarding),
  `tailscale set --advertise-exit-node`; Tailscale's own iptables chains (ts-forward, ts-postrouting MASQUERADE) do the
  forwarding and NAT; FORWARD policy DROP (Docker) is untouched. Approved once in the Tailscale admin console.
- **Mac**: `tailscale set --exit-node=<100.x of the exit node> --exit-node-allow-lan-access=true` (FRANKFURT) and
  `tailscale set --exit-node=` (DIRECT), through /Applications/Tailscale.app/Contents/MacOS/Tailscale. LAN stays
  reachable (Sound Link to the Pixel, adb over Wi-Fi). Public IP + country from https://ipinfo.io/json (no key), at
  start, after every switch and every ten minutes (SIM uplink). CONNECT (amber, top right) when Tailscale is not
  running or signed out; it opens Tailscale.
- **Android**: one VPN at a time is allowed and that is Tailscale, so the app drives the Tailscale app: AutomationActivity
  `com.tailscale.ipn.CONNECT_VPN`, then broadcast `com.tailscale.ipn.USE_EXIT_NODE` to `com.tailscale.ipn.IPNReceiver`
  with `exitNode=chromium-vm` (or "" for DIRECT) and `allowLanAccess=true` (verified in tailscale/tailscale-android
  IPNReceiver.java / UseExitNodeWorker.kt, 15.11.2026: the name is matched to the peer's display name). The lit word
  comes from the public IP (country DE = FRANKFURT). Tailscale reports a refused switch in its own notification.

## Build and install (never compiled on the Mac)

- Push to main: `.github/workflows/mac.yml` (macOS runner, `mac/build.sh`, app.zip) and `.github/workflows/android.yml`
  (APK `<N>-mantra-vpn-v<N>.apk`, signed with secret ANDROID_DEBUG_KEYSTORE_B64 = the Mac's ~/.android/debug.keystore)
  both upload into ONE release vN, marked Latest. **The number is the same on both sides**: `mac/Sources/Version.swift`
  `VERSION` and `android/gradle.properties` `appVersion` are raised together. Both workflows share one concurrency
  group, so they never race on creating the release.
- Mac: `gh release download --repo markoboskoauroville/MANTRA_VPN --pattern app.zip -D /tmp/vpn --clobber &&
  ditto -x -k /tmp/vpn/app.zip /Applications && codesign --force -s "Mantra Apps" "/Applications/VPN (Mantra).app"`.
  From v2 on the app asks to update at start (Updater.swift, kits/mac-updater).
- Phones: `adb -s 100.70.23.53:5555 install -r <apk>` (Pixel 7), `100.67.149.40:5555` (Nothing). From v2 on the app asks
  (AppUpdater.kt, kits/android-updater).
- Test: `tools/test_exit.sh` (BEFORE / DURING / AFTER public IP, ssh to the VM and a tailscale ping while on FRANKFURT,
  back to DIRECT on exit, under a minute).

## Status

- 15.11.2026 v1: release https://github.com/markoboskoauroville/MANTRA_VPN/releases/tag/v1 (Latest; app.zip 0.7 MB +
  1-mantra-vpn-v1.apk 22 MB). Runs green: Mac app https://github.com/markoboskoauroville/MANTRA_VPN/actions/runs/43676423685,
  Android https://github.com/markoboskoauroville/MANTRA_VPN/actions/runs/43676423596. Mac: installed, signed "Mantra Apps",
  window seen (DIRECT lit, Croatian IP, Tailscale CONNECTED, exit node "none offered" = not yet approved); all eight
  controls are AX buttons named by their word. Pixel 7 + Nothing: v1 installed by adb (not opened: live stream on the
  Pixel). Emulator: UI seen in portrait.
- Open: chromium-vm must be approved as exit node in the Tailscale admin console; then run `tools/test_exit.sh`.
- v2: no focus ring on ON at launch (`.focusable(false)` on the words).

## Next

- A row in the star (STAR_SWIFT rows.json + icons6/icons.json key `vpn`, VPN/FRA, Mac tools) when the star is not being
  changed by another session.
- Optional: menu-bar icon; an editable exit-node name on Android if a second exit node ever exists.
- 15.11.2026 v2 (Mac + Android, release v2 Latest; runs green: Mac https://github.com/markoboskoauroville/MANTRA_VPN/actions/runs/43698355498,
  Android https://github.com/markoboskoauroville/MANTRA_VPN/actions/runs/43698355497): bug "always DIRECT" fixed. Cause: Tailscale.app's one binary
  is the GUI unless `TAILSCALE_BE_CLI=1` (or a terminal environment) is set; started from the GUI app it printed "The Tailscale GUI failed to start"
  and the window showed NOT RUNNING / none offered. Now every CLI call runs with TAILSCALE_BE_CLI=1, stdin /dev/null; the exit node in use is read
  from `ExitNodeStatus.ID` (Tailscale 1.104); the lit word is FRANKFURT when the exit node is in use OR the public IP is Oracle / DE. Log:
  `~/Library/Logs/VPN (Mantra).log`. Verified on the Mac: FRANKFURT lit, CONNECTED, chromium-vm IN USE; DIRECT pressed -> Zagreb, Telemach;
  FRANKFURT pressed -> Frankfurt, Oracle; left on FRANKFURT. AX: the buttons have no names in v2 either (button 6 = FRANKFURT, 7 = DIRECT in group 1).
