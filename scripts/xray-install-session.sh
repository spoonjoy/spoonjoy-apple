#!/bin/sh
# The App Intents X-ray probe's --prepare step: puts the disposable QA chef's session where a debug build reads it.
#
#   xray-install-session.sh <vault file>
#
# ouro-ui-apple's xray-probe.sh runs it once the app is installed on the probe's own simulator and before its first
# launch, with OURO_AX_UDID and OURO_AX_BUNDLE_ID set. The Duo journey's posture driver installs a session the same way.
set -eu
vault="$1"
[ -s "$vault" ] || { echo "xray-install-session: no session vault at $vault" >&2; exit 1; }
container="$(xcrun simctl get_app_container "$OURO_AX_UDID" "$OURO_AX_BUNDLE_ID" data)"
mkdir -p "$container/Library/Application Support/Spoonjoy"
cp "$vault" "$container/Library/Application Support/Spoonjoy/debug-auth-session.json"
echo "xray-install-session: the QA chef's session is in the app's data container"
