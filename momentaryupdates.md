# MANTRA_VPN: momentary updates

Every request from Marko, word for word, before any code. Each item has a Status line.

## 15.11.2026, request 1 (v1)

> Now another task for new worker. I need new Swift app called mantra_vpn, which is going to be very simplified version of connection keeper and it just relays all my internet connection through my virtual machine. So whatever I'm connected to on the Mac, actually the whole Mac become VPN through So basically we are building VPN client for My also two releases. Also for the Android. So I can also start this app as VPN service. And I'm in a Frankfurt IP. Protecting my privacy. If some secrets are stored in this software. If somebody can download this and connect to my Frankfurt machine, we don't build it or publish it on the GitHub. Build it in the Mac OS and we publish it in my GDrive under my GDrive repository. And then I download and install APK from there or Swift from there. If it's possible to build without any secrets, then we use GitHub and the secrets are stored locally. Please do that now.

**Status:** saved 15.11.2026 before any code. Design: chromium-vm is a Tailscale exit node; the apps hold no secret (Tailscale's own login on each device is the key), so GitHub builds them.

## 15.11.2026, request 2 (v2)

> and you need to switch my VPN Mantra on MacOS to Frankfurt. I cannot do this. It's always direct.

**Status:** saved 15.11.2026 before any code. Cause found: Tailscale.app's binary starts as the GUI (error "The Tailscale GUI failed to start") when run from a GUI app without TAILSCALE_BE_CLI=1; the app saw no Tailscale at all. Fix in v2.
