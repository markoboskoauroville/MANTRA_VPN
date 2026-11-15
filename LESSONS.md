# MANTRA_VPN: lessons

1. **A privacy VPN without a secret is a Tailscale exit node** (15.11.2026). Authentication is the tailnet login on each
   device; the app only flips `--exit-node`. That is what makes a public repo and GitHub builds safe.
2. **Android: never a second VPN beside Tailscale.** Android runs one VPN at a time; drive Tailscale's own automation
   intents (CONNECT_VPN through AutomationActivity, USE_EXIT_NODE broadcast to IPNReceiver). USE_EXIT_NODE matches the
   peer's display name, not its IP, and reports failure as a Tailscale notification, not to the caller.
3. **Advertising is not enough: the exit node must be approved** in the Tailscale admin console (or by autoApprovers in
   the policy). Until then peers see `ExitNodeOption: false` and `tailscale exit-node list` says "no exit nodes found".
4. **Oracle's Ubuntu image here has FORWARD policy DROP from Docker**, not Oracle's REJECT rules; Tailscale's ts-forward
   chain (jumped from FORWARD) accepts tailnet traffic and ts-postrouting masquerades it. Nothing to add by hand.
5. **One release for two platforms**: the Mac and Android workflows upload into the same vN, so both updaters (which read
   the Latest tag) stay in step; one shared concurrency group stops the two runs from racing on `gh release create`.
