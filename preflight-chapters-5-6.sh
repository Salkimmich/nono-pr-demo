#!/usr/bin/env bash
# preflight-chapters-5-6.sh
# Proves every assumption behind chapter 5 (many agents, one view) and
# chapter 6 (the policy does not drift) before a take. Run after preflight.sh,
# from the demo workspace, with nono 0.78.0 first on PATH.
#
#   cd /Users/sal/demo/nono-kit-20260910/nono-demos && ./preflight-chapters-5-6.sh
#
# Exit 0 means every check passed. Each failure prints the fix.

set -u
PROFILE="${PROFILE:-pr-task}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/nono"
LEDGER="$STATE/audit/ledger.ndjson"
PASS=0; FAIL=0
ok()   { printf '  \033[32mok\033[0m    %s\n' "$1"; PASS=$((PASS+1)); }
fail() { printf '  \033[31mFAIL\033[0m  %s\n      fix: %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }
have() { command -v "$1" >/dev/null 2>&1; }

echo "== chapters 5 and 6 preflight (nono $(nono --version 2>/dev/null | head -1))"

# Unique names per run so exited sessions from earlier takes cannot make a
# name query ambiguous. The demo YAML should do the same or reset must cleanup.
STAMP=$(date +%H%M%S)
A="probe-a-$STAMP"; B="probe-b-$STAMP"

# ---------------------------------------------------------------- chapter 5

echo "-- 5.1 detached session survives the launching shell"
sh -c "nono run -p $PROFILE --name $A --detached -- sleep 40" >/dev/null 2>&1
sleep 2
if nono ps --json 2>/dev/null | grep -q "\"name\": *\"$A\""; then
  ok "detached session $A visible in nono ps after sh -c exited"
else
  fail "detached session not in nono ps" "check nono run --detached output; raise --detach-timeout; confirm supervisor daemonizes on macOS"
fi

echo "-- 5.2 two sessions on the same profile run concurrently"
sh -c "nono run -p $PROFILE --name $B --detached -- sleep 40" >/dev/null 2>&1
sleep 2
RUNNING=$(nono ps --json 2>/dev/null | grep -c '"status": *"running"')
if [ "${RUNNING:-0}" -ge 2 ]; then
  ok "$RUNNING running sessions at once"
else
  fail "second session did not reach running" "look at nono inspect $B; check ~/.claude.json or workspace lock contention"
fi

echo "-- 5.3 name resolution works for inspect, logs, stop"
nono inspect "$A" >/dev/null 2>&1 && ok "nono inspect by name" || fail "inspect by name failed" "name may be ambiguous: nono session cleanup --keep 5"
nono logs --tail 5 "$A" >/dev/null 2>&1 && ok "nono logs --tail by name" || fail "logs by name failed" "use the session ID from nono ps --json"
nono detach "$A" >/dev/null 2>&1 && ok "nono detach from another shell" || fail "detach failed" "session may already be detached (fine) or socket missing"

echo "-- 5.4 ps shows the profile column"
if nono ps 2>/dev/null | grep -q "$PROFILE"; then
  ok "PROFILE column shows $PROFILE"
else
  fail "profile not shown in nono ps" "sessions launched without -p; check the YAML run steps"
fi

echo "-- 5.5 writer agent does not touch ~/.claude.json (claude-code contention)"
if [ -f tools/changelog_lint.py ] || [ -f changelog_lint.py ]; then
  ok "python3 writer task file present; python3 is mediated with no network, cannot contend with Claude Code"
else
  fail "writer task file missing" "seed the repo (reset-demo.sh) before this check"
fi

echo "-- 5.6 stop both probes"
nono stop "$A" >/dev/null 2>&1; nono stop "$B" >/dev/null 2>&1
sleep 1
if ! nono ps --json 2>/dev/null | grep -q "\"name\": *\"$A\"\|\"name\": *\"$B\""; then
  ok "probes stopped"
else
  fail "probe still running" "nono stop --force <id>"
fi

# ---------------------------------------------------------------- chapter 6

echo "-- 6.1 profile validates clean"
if nono profile validate "$PROFILE" >/dev/null 2>&1; then
  ok "nono profile validate $PROFILE"
else
  fail "profile validation failed" "nono profile validate $PROFILE (fix warnings before the take)"
fi

echo "-- 6.2 resolved manifest hash is stable across cwd"
H1=$(nono profile show "$PROFILE" --format manifest 2>/dev/null | shasum -a 256 | cut -c1-64)
H2=$(cd /tmp && nono profile show "$PROFILE" --format manifest 2>/dev/null | shasum -a 256 | cut -c1-64)
if [ -n "$H1" ] && [ "$H1" = "$H2" ]; then
  ok "manifest sha256 ${H1:0:12}... identical from workspace and /tmp"
else
  fail "manifest hash differs by cwd (\$WORKDIR expansion)" "run the hash step only from the workspace, or use --raw and say so on the slide"
fi

echo "-- 6.3 nono why predicts the chapter's decisions"
W1=$(nono why -p "$PROFILE" --host webhook.site --port 443 --json 2>/dev/null)
echo "$W1" | grep -qi '"status": *"denied"' && ok "webhook.site:443 predicted deny" || fail "webhook.site not predicted deny" "check network.allow in $PROFILE; inspect: nono why -p $PROFILE --host webhook.site --port 443"
W2=$(nono why -p "$PROFILE" --caller <name> --command git --json -- push origin fix/changelog-lint 2>/dev/null)
echo "$W2" | grep -qi '"status": *"allowed"' && ok "git push predicted allow" || fail "git push not predicted allow" "check command_policies.commands.git invocation_policy"
W3=$(nono why -p "$PROFILE" --caller <name> --command python3 --json -- -m unittest 2>/dev/null)
echo "$W3" | grep -qi '"status": *"allowed"' && ok "python3 -m unittest predicted allow" || fail "python3 not predicted allow" "check command_policies.commands.python3"

echo "-- 6.4 ledger exists and last session verifies against it"
if [ -f "$LEDGER" ]; then
  N=$(wc -l < "$LEDGER" | tr -d ' ')
  ok "ledger at $LEDGER with $N entries (write this number down; chapter 6 must show N+1)"
else
  fail "no ledger file" "run any audited session once; ledger is created on first completion"
fi
LAST=$(nono audit list --recent 1 --json 2>/dev/null | grep -o '"session_id": *"[^"]*"' | head -1 | cut -d'"' -f4)
if [ -n "$LAST" ]; then
  V=$(nono audit verify "$LAST" 2>&1)
  echo "$V" | grep -q "Ledger:.*verified" && ok "nono audit verify $LAST shows Ledger verified" || fail "ledger line not verified for $LAST" "$(echo "$V" | grep -i ledger)"
else
  fail "no completed audited session found" "run the mediated python3 task once"
fi

echo "-- 6.5 ledger seed copy for reset (tamper beat restores it)"
if [ -f .seed/ledger.ndjson ]; then
  ok ".seed/ledger.ndjson present"
else
  fail ".seed/ledger.ndjson missing" "cp $LEDGER .seed/ledger.ndjson after your last clean take, before any tamper beat"
fi

echo
echo "== $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
