#!/bin/sh
set -eu

[ -n "${HOME:-}" ] || { printf '%s\n' "MINDY TimeSaver couldn't find your home folder on this computer, so it stopped there. Start a new session and try again, and if you see this again, type /mindyteam and let us know." >&2; exit 1; }

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export MTS_PRODUCT=mts
export MTS_STATE_ROOT="${MTS_STATE_ROOT:-$HOME/.timesaver}"
export MTS_RUNTIME_SCRATCH_DIR="${MTS_RUNTIME_SCRATCH_DIR:-$MTS_STATE_ROOT/runtime-scratch}"

bun="$MTS_STATE_ROOT/bin/bun"
session_start=false
case "${1:-}" in session-start.ts|*/session-start.ts) session_start=true ;; esac
setup_missing() {
 [ "$session_start" != true ] || exit 0
 printf '%s\n' "MINDY TimeSaver isn't fully set up on this computer yet. Type /install-mts with your access code to finish, then try again." >&2
 exit 1
}
[ -f "$bun" ] && [ ! -L "$bun" ] && [ -x "$bun" ] || setup_missing

content_root=${MTS_CONTENT_ROOT:-}
if [ -z "$content_root" ] && [ -f "$MTS_STATE_ROOT/install-state.json" ]; then
 content_root=$(cd "$MTS_STATE_ROOT" && "$bun" -e 'const state = await Bun.file(process.argv[1]).json(); process.stdout.write(typeof state.contentRoot === "string" ? state.contentRoot : process.env.HOME + "/timesaver");' "$MTS_STATE_ROOT/install-state.json")
fi
if [ -z "$content_root" ]; then setup_missing; fi
folder_place() {
 folder_name=${content_root##*/}
 parent_place=${content_root%/*}
 case "$content_root" in
  "$HOME/timesaver") printf '%s' 'in a folder called timesaver in your home folder'; return ;;
 esac
 case "$parent_place" in
  "$HOME") printf 'in a folder called %s in your home folder' "$folder_name" ;;
  "$HOME/Desktop") printf 'on your Desktop, in a folder called %s' "$folder_name" ;;
  "$HOME/Documents") printf 'in your Documents, in a folder called %s' "$folder_name" ;;
  "$HOME/Library/CloudStorage/GoogleDrive-"*"/My Drive") printf 'in your Google Drive, in a folder called %s' "$folder_name" ;;
  "$HOME/Library/CloudStorage/GoogleDrive-"*"/My Drive/"*) printf 'in your Google Drive, inside %s, in a folder called %s' "$(printf '%s' "${parent_place#*/My Drive/}" | sed 's|/|, then |g')" "$folder_name" ;;
  "$HOME/Library/CloudStorage/Dropbox"|"$HOME/Library/CloudStorage/Dropbox/"*|"$HOME/Library/CloudStorage/Dropbox-"*|"$HOME/Library/CloudStorage/OneDrive"|"$HOME/Library/CloudStorage/OneDrive/"*|"$HOME/Library/CloudStorage/OneDrive-"*)
   cloud_place=${parent_place#"$HOME/Library/CloudStorage/"}
   provider_root=${cloud_place%%/*}
   case "$provider_root" in
    Dropbox|Dropbox-*) provider_name=Dropbox ;;
    OneDrive|OneDrive-*) provider_name=OneDrive ;;
   esac
   if [ "$cloud_place" = "$provider_root" ]; then
    printf 'in your %s, in a folder called %s' "$provider_name" "$folder_name"
   else
    printf 'in your %s, inside %s, in a folder called %s' "$provider_name" "$(printf '%s' "${cloud_place#*/}" | sed 's|/|, then |g')" "$folder_name"
   fi
   ;;
  "$HOME/Library/Mobile Documents/com~apple~CloudDocs") printf 'in your iCloud Drive, in a folder called %s' "$folder_name" ;;
  "$HOME/Library/Mobile Documents/com~apple~CloudDocs/"*) printf 'in your iCloud Drive, inside %s, in a folder called %s' "$(printf '%s' "${parent_place#*/com~apple~CloudDocs/}" | sed 's|/|, then |g')" "$folder_name" ;;
  "$HOME"/*) printf 'in your home folder, inside %s, in a folder called %s' "$(printf '%s' "${parent_place#"$HOME"/}" | sed 's|/|, then |g')" "$folder_name" ;;
  /Volumes/*) printf 'on %s, in a folder called %s' "$(printf '%s' "${parent_place#/Volumes/}" | sed 's|/|, then |g')" "$folder_name" ;;
  *) printf 'in a folder called %s, inside %s' "$folder_name" "${parent_place##*/}" ;;
 esac
}

folder_unreachable() {
 printf '%s\n' 'MTS_SAVE_REFUSED' "MINDY TimeSaver cannot reach your saves folder $(folder_place). Reconnect its disk or cloud folder, then try again. Your existing saves have not been changed." >&2
 exit 1
}
if [ ! -d "$content_root" ]; then folder_unreachable; fi
if [ ! -r "$content_root/timesaver.json" ]; then
 [ "$session_start" != true ] || exit 0
 printf '%s\n' 'MTS_SAVE_REFUSED' "MINDY TimeSaver needs a quick update before it can do that. Type /install-mts with your access code, then try again." >&2
 exit 1
fi
if MTS_CONTENT_ROOT=$(CDPATH= cd -- "$content_root" 2>/dev/null && pwd); then :; else folder_unreachable; fi
export MTS_CONTENT_ROOT
cd "$MTS_CONTENT_ROOT"

# Setting commands and session start run even while saving is off.
# Manual writers need the app's session id. Capture and scheduled compression need only the current setting.
case "${1:-}:${2:-}" in
 timesaver-install/runtime/memory.ts:write-memory|timesaver-install/runtime/memory.ts:save-chat|timesaver-install/runtime/memory.ts:landmark)
  if [ "${2:-}" = write-memory ] && [ "${3:-}" = --quote-labels ] && [ "$#" -eq 3 ]; then :; else
   if "$bun" "$MTS_CONTENT_ROOT/timesaver-install/runtime/privacy.ts" save-check "$@"; then :; else
    status=$?
    case "$status" in 2) exit 0 ;; *) exit 1 ;; esac
   fi
  fi
 ;;
 timesaver-install/runtime/memory.ts:*) ;;
 *)
case "${1:-}" in
 */privacy.ts|*/session-start.ts|timesaver-install/runtime/read-memory.ts|timesaver-install/runtime/remove.ts|timesaver-install/runtime/move.ts|timesaver-install/runtime/import-old-memory.ts|timesaver-install/runtime/team-message.ts|MY-MIND/MY-SYSTEM/utilities/mindy-search.ts|MY-MIND/MY-SYSTEM/utilities/claude-chat-keeping.ts|bin/save-failure.ts) ;;
 *)
  if [ "${2:-}" = --quote-labels ] && [ "$#" -eq 2 ]; then :; else
   case "${1:-}" in
    *timesaver-capture-worker.ts|\
    MY-MIND/MY-SYSTEM/daemons/DailyCompress.daemon.ts|MY-MIND/MY-SYSTEM/daemons/WeeklyCompress.daemon.ts|MY-MIND/MY-SYSTEM/daemons/MonthlyCompress.daemon.ts|MY-MIND/MY-SYSTEM/daemons/QuarterlyCompress.daemon.ts|MY-MIND/MY-SYSTEM/daemons/YearlyCompress.daemon.ts|\
    "$MTS_CONTENT_ROOT"/MY-MIND/MY-SYSTEM/daemons/DailyCompress.daemon.ts|"$MTS_CONTENT_ROOT"/MY-MIND/MY-SYSTEM/daemons/WeeklyCompress.daemon.ts|"$MTS_CONTENT_ROOT"/MY-MIND/MY-SYSTEM/daemons/MonthlyCompress.daemon.ts|"$MTS_CONTENT_ROOT"/MY-MIND/MY-SYSTEM/daemons/QuarterlyCompress.daemon.ts|"$MTS_CONTENT_ROOT"/MY-MIND/MY-SYSTEM/daemons/YearlyCompress.daemon.ts) gate=check ;;
    *) gate=save-check ;;
   esac
   if [ "$gate" = check ]; then
    if "$bun" "$MTS_CONTENT_ROOT/timesaver-install/runtime/privacy.ts" check ""; then :; else
     status=$?
     case "$status" in 2) exit 0 ;; *) exit 1 ;; esac
    fi
   else
    if "$bun" "$MTS_CONTENT_ROOT/timesaver-install/runtime/privacy.ts" save-check "$@"; then :; else
     status=$?
     case "$status" in 2) exit 0 ;; *) exit 1 ;; esac
    fi
   fi
  fi
 ;;
esac
 ;;
esac
case "${1:-}" in
 timesaver-install/runtime/memory.ts)
  case "${2:-}" in
   save-chat|landmark) exec "$bun" timesaver-install/runtime/privacy.ts save-run "$@" ;;
  esac
  exec "$bun" "$@" ;;
 MY-MIND/MY-SYSTEM/utilities/transcript.ts)
  exec "$bun" timesaver-install/runtime/privacy.ts save-run "$@" ;;
 *) exec "$bun" "$@" ;;
esac
