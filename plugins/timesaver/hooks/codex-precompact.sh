#!/bin/sh
# Compaction must continue even if setup, capture or worker startup fails.
hook_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 0
log_root="${MTS_STATE_ROOT:-$HOME/.timesaver}/logs"
umask 077
mkdir -p "$log_root" 2>/dev/null || exit 0
# Keep the original stdin bytes for the launcher after reading Codex's identity.
payload_file=$(mktemp "$log_root/codex-precompact.XXXXXX") || exit 0
trap 'rm -f "$payload_file"' 0
cat >"$payload_file" || exit 0
if [ -z "${CODEX_THREAD_ID:-}" ]; then
 bun="${MTS_STATE_ROOT:-$HOME/.timesaver}/bin/bun"
 if [ ! -f "$bun" ] || [ -L "$bun" ] || [ ! -x "$bun" ]; then
  printf '%s\n' '[codex-compaction] installed capture launcher failed' >>"$log_root/codex-precompact.log" 2>/dev/null
  exit 0
 fi
 CODEX_THREAD_ID=$("$bun" -e 'try { const payload = JSON.parse(await Bun.stdin.text()); if (typeof payload?.session_id === "string") process.stdout.write(payload.session_id.trim()); } catch { console.error("[codex-compaction] PreCompact payload is not valid JSON"); process.exit(1); }' <"$payload_file" 2>>"$log_root/codex-precompact.log") || exit 0
 export CODEX_THREAD_ID
fi
if [ -z "$CODEX_THREAD_ID" ] || [ "${#CODEX_THREAD_ID}" -gt 1024 ]; then
 printf '%s\n' '[codex-compaction] chat could not be identified' >>"$log_root/codex-precompact.log" 2>/dev/null
 exit 0
fi
if sh "$hook_dir/../scripts/bun-runtime.sh" MY-MIND/MY-SYSTEM/utilities/transcript.ts codex-compaction-hook <"$payload_file" >>"$log_root/codex-precompact.log" 2>&1; then
 :
else
 printf '%s\n' '[codex-compaction] installed capture launcher failed' >>"$log_root/codex-precompact.log" 2>/dev/null
fi
exit 0
