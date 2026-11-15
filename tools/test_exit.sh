#!/bin/bash
# test_exit.sh: the Mac's exit-node round trip, at most 60 s on FRANKFURT, then back to DIRECT (tiny: three IP lookups).
#   tools/test_exit.sh            DIRECT ip → FRANKFURT ip + ssh chromium-vm + tailscale ping → DIRECT ip
set -u
TS=/Applications/Tailscale.app/Contents/MacOS/Tailscale; [ -x "$TS" ] || TS=$(command -v tailscale)
ip() { curl -s -m 10 https://ipinfo.io/json | python3 -c 'import json,sys; j=json.load(sys.stdin); print(j.get("ip"), j.get("country"), j.get("city"), j.get("org"))'; }
NODE=$("$TS" status --json | python3 -c '
import json,sys; j=json.load(sys.stdin)
ps=[p for p in j.get("Peer",{}).values() if p.get("ExitNodeOption")]
ps.sort(key=lambda p: p.get("HostName")!="chromium-vm")
print(ps[0]["TailscaleIPs"][0] if ps else "")')
[ -n "$NODE" ] || { echo "no exit node offered in the tailnet (approve chromium-vm in the admin console)"; exit 1; }
echo "BEFORE  $(ip)"
trap '"$TS" set --exit-node= ; echo "AFTER   $(ip)"' EXIT
"$TS" set --exit-node="$NODE" --exit-node-allow-lan-access=true || exit 1
sleep 3
echo "DURING  $(ip)"
echo "ssh     $(ssh -o ConnectTimeout=10 ubuntu@chromium-vm hostname 2>&1)"
echo "ping    $("$TS" ping -c 1 --timeout 5s pixel-7 2>&1 | tail -1)"
