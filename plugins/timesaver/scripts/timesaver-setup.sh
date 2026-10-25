#!/bin/sh
set -eu

start='type /install-mts'
capital="$(printf '%s' "$start" | cut -c 1 | tr '[:lower:]' '[:upper:]')$(printf '%s' "$start" | cut -c 2-)"
unsigned="This isn't a signed MINDY TimeSaver release, so setup stopped before installing anything, to keep this computer safe. Check you're on your usual internet connection, then type /install-mts again."
too_many="Too many tries from this internet connection in the last minute, so MINDY TimeSaver's install server is pausing for a moment. Wait a minute, then $start again."
unreachable="Setup could not reach MINDY TimeSaver's install server. Check you are online, then $start again."
stalled_transfer="The connection to MINDY TimeSaver's install server made no progress for 2 minutes, so setup stopped. Nothing has been installed. Check you are online, then $start again."
app_stalled="Your app made no progress adding MINDY TimeSaver for 2 minutes, so setup stopped it and undid this setup's changes. Check you are online, then $start again."
interrupted="Setup stopped because it was interrupted. $capital to start again."
generic="It's safe to run setup again, so type /install-mts to have another go."
update_offer="Would you like me to check for a MINDY TimeSaver update?"

host_ui() {
 origin=$(printf '%s' "${CODEX_INTERNAL_ORIGINATOR_OVERRIDE:-}" | tr '[:upper:]' '[:lower:]')
 case "$origin" in *chatgpt*) printf '%s' chatgpt-app; return ;; esac
 case "${CODEX_CLI_PATH:-}" in
  */ChatGPT.app/Contents/*) printf '%s' chatgpt-app ;;
  */Codex.app/Contents/*) printf '%s' codex-app ;;
  *) printf '%s' unknown ;;
 esac
}

folder_place() {
 name=${content_root##*/}
 parent=${content_root%/*}
 case "$parent" in
  "$HOME") printf 'in a folder called %s in your home folder' "$name" ;;
  "$HOME/Desktop") printf 'on your Desktop, in a folder called %s' "$name" ;;
  "$HOME/Documents") printf 'in your Documents, in a folder called %s' "$name" ;;
  "$HOME/Library/CloudStorage/GoogleDrive-"*"/My Drive"*)
   inside=${parent#*/My Drive}; inside=${inside#/}
   printf 'in your Google Drive'; [ -z "$inside" ] || printf ', inside %s' "$(printf '%s' "$inside" | sed 's|/|, then |g')"
   printf ', in a folder called %s' "$name" ;;
  "$HOME/Library/CloudStorage/Dropbox"*|"$HOME/Library/CloudStorage/OneDrive"*)
   inside=${parent#"$HOME/Library/CloudStorage/"}; provider=${inside%%/*}
   case "$provider" in Dropbox*) label=Dropbox ;; OneDrive*) label=OneDrive ;; esac
   printf 'in your %s' "$label"; [ "$inside" = "$provider" ] || printf ', inside %s' "$(printf '%s' "${inside#*/}" | sed 's|/|, then |g')"
   printf ', in a folder called %s' "$name" ;;
  "$HOME/Library/Mobile Documents/com~apple~CloudDocs"*)
   inside=${parent#*com~apple~CloudDocs}; inside=${inside#/}
   printf 'in your iCloud Drive'; [ -z "$inside" ] || printf ', inside %s' "$(printf '%s' "$inside" | sed 's|/|, then |g')"
   printf ', in a folder called %s' "$name" ;;
  "$HOME"/*) printf 'in your home folder, inside %s, in a folder called %s' "$(printf '%s' "${parent#"$HOME"/}" | sed 's|/|, then |g')" "$name" ;;
  /Volumes/*) printf 'on %s, in a folder called %s' "$(printf '%s' "${parent#/Volumes/}" | sed 's|/|, then |g')" "$name" ;;
  *) printf 'in a folder called %s, inside %s' "$name" "${parent##*/}" ;;
 esac
}
print_welcome() {
 printf '%s\n' "MINDY TimeSaver is ready. It works in whatever folder you open the app in, and everything goes into one memory. Start a session with /mindyload, and type /mindyend when you finish to save it. Nothing will be saved to your TimeSaver unless you type /mindyend at the end of a session."
}

show_help() {
 cat <<'MTS_HOW_TO'
Type /mindyend at the end of a session to save it.
Use /mindysave to keep the words of a chat.
Use /mindyload to give your AI all the context it needs for any work you've saved.
Use /mindysearch to search for anything in your TimeSaver.
Use /mindyteam to send a bug report, give feedback or ask a question.
Use /mindyhelp for a reminder of these instructions.

Here's what to do right now to immediately save time with your TimeSaver...

1. Choose at least three of your most important recent sessions where you had ideas and made decisions which you don't want to forget and you want a future AI to know.
2. Open one of these chats in the app.
3. Type /mindyend at the bottom of the chat.
4. Mindy will save every time you asked, decided or did something important to your TimeSaver.
5. When you want to pick up that project again, type /mindyload [subject] or /mindyload alone to select a saved session.
6. Repeat for as many chats and sessions that you want to keep! :)

(And use /mindysearch to find anything in your entire TimeSaver.)

Remember: Mindy TimeSaver gets more valuable the more you use it. So don't forget: When you want to save time by saving time, always /mindyend.
MTS_HOW_TO
}
read_content_root() {
 content_root="$HOME/timesaver"
 location_bun=${1:-$HOME/.timesaver/bin/bun}
 [ -x "$location_bun" ] && [ -d "$HOME/.timesaver" ] || return 0
 # During setup this read is a recorded step (see held), so a stop ends it at once.
 if [ -n "${tmp:-}" ]; then
  held "$location_bun" -e "$content_root_reader" "$HOME/.timesaver" >"$tmp/content-root" || return 1
  content_root=$(cat "$tmp/content-root")
 else
  content_root=$(cd "$HOME/.timesaver" && "$location_bun" -e "$content_root_reader" "$HOME/.timesaver")
 fi
}
content_root_reader='
   const root = process.argv[1];
   let path = ["install-state.json", "kept-saves.json"].map(name => root + "/" + name).find(path => require("node:fs").existsSync(path));
   if (!path && require("node:fs").existsSync(root + "/install-transaction.json")) {
    const tx = await Bun.file(root + "/install-transaction.json").json();
    const state = tx.changed?.find(item => item.destination === root + "/install-state.json");
    if (state?.backup?.startsWith(root + "/install-state.json.previous-") && !state.backup.slice(root.length + 1).includes("/")) path = state.backup;
   }
   const state = path ? await Bun.file(path).json() : {};
   process.stdout.write(typeof state.contentRoot === "string" ? state.contentRoot : process.env.HOME + "/timesaver");
'
if [ "${1:-}" = "--host-ui" ]; then host_ui; printf '\n'; exit 0; fi
if [ "${1:-}" = "--setup-stage" ]; then
 if [ -f "$HOME/.timesaver/setup-progress.json" ] && [ -x "$HOME/.timesaver/bin/bun" ]; then
  (cd "$HOME/.timesaver" && "$HOME/.timesaver/bin/bun" -e 'process.stdout.write((await Bun.file(process.argv[1]).json()).stage)' "$HOME/.timesaver/setup-progress.json")
 fi
 exit 0
fi
if [ "${1:-}" = "--setup-complete" ]; then rm -f "$HOME/.timesaver/setup-progress.json"; exit 0; fi
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "help" ]; then show_help; exit 0; fi
if [ "${1:-}" = "--folder-info" ]; then
 read_content_root
 printf '%s\n' "Your saves are $(folder_place). MINDY TimeSaver works with Claude or ChatGPT, with other AIs coming soon. They all read the same memories and build the same context, so you are not locked in to one company. This folder is yours, not any company's. You can move it anywhere, at any time, by asking me."
 exit 0
fi
# Do not let variables left by a retired installer reach child programs.
unset code chat_code_copy chat_pipe
account_plugin=false
chosen_action=
while [ "$#" -gt 0 ]; do
 case "$1" in
  --account-plugin) account_plugin=true; shift ;;
  --chosen-action)
   shift; chosen_action=${1:-}
   [ "$chosen_action" = update ] || { printf '%s\n' 'Type /install-mts to set up MINDY TimeSaver.'; exit 1; }
   shift ;;
  *) printf '%s\n' 'Type /install-mts to set up MINDY TimeSaver.'; exit 1 ;;
 esac
done

tmp=
finished=false
pending_report=
step='starting MINDY TimeSaver setup'
cleanup() { [ -z "$tmp" ] || rm -rf "$tmp"; }
# A stop can arrive while a function's output goes to a temporary file, so the
# stop sentence uses the chat's own output, kept on descriptor 8.
exec 8>&1
# The stop record is kept on this computer first. The report to MINDY's install
# server goes only after the person has their reply (see send_report).
on_signal() { trap '' HUP INT TERM; finished=true; reason="Setup stopped while $step. $interrupted"; report_stop "$reason" || :; stop_steps; cleanup 1; printf '%s\n' "$reason" >&8; send_report; exit 1; }
on_exit() { status=$?; stop_steps; if [ "$status" != 0 ] && [ "$finished" = false ]; then report_stop "Setup stopped while $step. $generic" || :; fi; cleanup "$status"; if [ "$status" != 0 ] && [ "$finished" = false ]; then printf '%s\n' "Setup stopped while $step. $generic" >&8; send_report; fi; }
# Interruption is handled from here on.
trap on_signal HUP INT TERM

# Runs one step of setup's own (a program that starts nothing) in setup's
# temporary folder, as a recorded step (see Steps below).
held() {
 step_open main || return 1
 step_exec "$tmp" "$@" &
 step_started main
 step_wait main; held_status=$step_status
 step_end main
 return "$held_status"
}

# Steps. Every step that can take time runs in the background, so a stop
# reaches setup at once: the chat reader, a server transfer and its watch, each
# check of the release, and everything run through the runner below. The shell
# runs a stop handler only once its foreground command has ended, so a step run
# in the foreground would hold the stop up.
#
# Each step runs in a process group of its own, and setup only ever signals
# that whole group, never a process by a number it stored: the shell collects
# an ended process at once, and macOS may then give its number to another
# program. The step holder below makes the group. It starts the step as the
# first process of a new group, so the group's number is that process's own,
# and it never collects that process once it has ended. macOS gives out no
# number that an ended, uncollected process still has, so the group's number
# stays this step's for as long as the holder is kept. The holder ignores stop
# signals and ends only when setup closes the pipe it reads, which setup does
# only after its last signal to the group. The step's first process reports the
# step's exit status; the holder reports the group's number.
#
# A stop, and the end of a step's first process, send TERM and CONT to what is
# left in the step's group, wait up to group_grace looks (50 ms apart) for the
# group to empty, then KILL whatever is left. A program that leaves its group
# is not ended: Mike decided this is a known limit (Event 2251813).
#
# The holder and the step's first process both set the group, as job control
# does, and macOS can refuse the second of the two once the first has done it.
# The shell then prints a message, so the holder's own messages go nowhere and
# the step gets setup's error output back on descriptor 4.
group_grace=100
step_holder='trap "" HUP INT TERM
set -m
( exec 2>&4 4>&-; trap - HUP INT TERM; cd -- "$1" && shift && "$@" 5>&- 6<&-; printf "s%s\n" "$?" >&5 ) &
printf "g%s\n" "$!" >&5
exec <&6 >/dev/null 2>&1 3<&- 4>&- 5>&- 6<&-
exec /bin/cat'
step_count=0
main_files=
watch_files=
# Copies what a step's holder reports into files setup reads: the group's
# number and the step's exit status. It ends once both values are recorded,
# even if another process still holds the pipe open. No stop signal ends it.
step_reader() {
 trap '' HUP INT TERM
 while IFS= read -r step_line; do
  case "$step_line" in g*) printf '%s\n' "${step_line#g}" >"$1.group" ;; s*) printf '%s\n' "${step_line#s}" >"$1.status" ;; esac
  if [ -f "$1.group" ] && [ -f "$1.status" ]; then break; fi
 done
}
# Usage: step_open <main|watch>; then step_exec <folder> <command...> in the
# background; then step_started <main|watch>. Setup holds the only writing end
# of the holder's pipe: descriptor 7 for the main step, 4 for the transfer's
# watch. It also opens the reading end the holder is given (6 for the main
# step, 5 for the watch) and closes its own copy once the holder has started,
# so the holder never waits to open it. The step is recorded before anything
# starts, so a stop at any moment finds it.
step_open() {
 step_count=$((step_count + 1)); step_files="$tmp/step-$step_count"
 mkfifo -m 600 "$step_files.out" "$step_files.release" || return 1
 eval "${1}_files=\$step_files ${1}_reader="
 if [ "$1" = main ]; then exec 7<>"$step_files.release" 6<"$step_files.release"; step_release_fd=6
 else exec 4<>"$step_files.release" 5<"$step_files.release"; step_release_fd=5; fi
 step_reader "$step_files" <"$step_files.out" 4>&- 5<&- 6<&- 7>&- 8>&- 9>&- &
 eval "${1}_reader=\$!"
}
step_exec() {
 [ "$step_release_fd" = 6 ] || exec 6<&5
 exec 5>"$step_files.out" 4>&2 2>/dev/null 7>&- 8>&- 9>&-
 exec /bin/bash --posix -p -c "$step_holder" timesaver-step "$@"
}
step_started() { if [ "$1" = main ]; then exec 6<&-; else exec 5<&-; fi; }
# Waits for a step's first process to end, and leaves its exit status in step_status.
step_wait() {
 eval "step_reader_pid=\$${1}_reader step_files=\$${1}_files"
 wait "$step_reader_pid" 2>/dev/null || :
 step_status=1
 if [ -f "$step_files.status" ]; then IFS= read -r step_status <"$step_files.status" || step_status=1; fi
 case "$step_status" in ''|*[!0-9]*) step_status=1 ;; esac
}
# The step's group number, in step_g. A stop can come as a step starts, so this
# waits for it, but not for long.
step_group() {
 step_looks=0
 while :; do
  step_g=
  if [ -f "$1.group" ]; then IFS= read -r step_g <"$1.group" || step_g=; fi
  case "$step_g" in ''|*[!0-9]*) ;; *) return 0 ;; esac
  [ "$step_looks" -lt 40 ] || return 1
  /bin/sleep 0.05; step_looks=$((step_looks + 1))
 done
}
group_left() { kill -0 -- "-$1" 2>/dev/null; }
# Usage: end_groups <group number...>. Each group's holder is still kept.
end_groups() {
 [ "$#" -gt 0 ] || return 0
 for end_group in "$@"; do if group_left "$end_group"; then kill -TERM -- "-$end_group" 2>/dev/null || :; kill -CONT -- "-$end_group" 2>/dev/null || :; fi; done
 end_looks=0
 while :; do
  end_left=
  for end_group in "$@"; do if group_left "$end_group"; then end_left="$end_left $end_group"; fi; done
  [ -n "$end_left" ] || return 0
  if [ "$end_looks" -eq "$group_grace" ]; then
   for end_group in $end_left; do kill -KILL -- "-$end_group" 2>/dev/null || :; done
  fi
  # KILL ends a process at once, unless it cannot be ended at all (one that
  # belongs to another user, or is stuck in the system). Setup does not wait
  # for ever for one of those: it stops and says so as it would otherwise.
  [ "$end_looks" -lt $((group_grace + 20)) ] || return 0
  /bin/sleep 0.05; end_looks=$((end_looks + 1))
 done
}
# Ends what is left in a step's group and lets its holder go.
step_end() {
 eval "step_files=\$${1}_files"
 [ -n "$step_files" ] || return 0
 if step_group "$step_files"; then end_groups "$step_g"; fi
 if [ "$1" = main ]; then exec 7>&- 6<&-; main_files=; else exec 4>&- 5<&-; watch_files=; fi
 rm -f "$step_files.out" "$step_files.release" "$step_files.group" "$step_files.status"
}
# A stop ends every step that has started, together.
stop_steps() {
 stop_groups=
 for stop_slot in main watch; do
  eval "step_files=\$${stop_slot}_files"
  [ -n "$step_files" ] || continue
  # A step stopped just as it starts may still be opening its pipe; this open
  # lets it go on, so its group can be found and ended.
  exec 3<>"$step_files.out"; exec 3>&-
  if step_group "$step_files"; then stop_groups="$stop_groups $step_g"; fi
 done
 # Each group number is a single word.
 # shellcheck disable=SC2086
 end_groups $stop_groups
 if [ -n "$main_files" ]; then exec 7>&- 6<&-; main_files=; fi
 if [ -n "$watch_files" ]; then exec 4>&- 5<&-; watch_files=; fi
}

# The runner. It runs a command, in the step's group, and watches whether that
# command is still making progress. Stopping, and ending what the command left
# in the group when it finishes, are done by the step (see Steps above).
# git started by the command does no housekeeping of its own (automatic gc and
# maintenance), the usual way git leaves a process running after the command
# has finished.
# In watch mode the runner stops a command only after 2 minutes in which its own
# processes, read from macOS's own process records, showed no progress at all:
# none used processor time, and none started or ended. Reading the records
# directly needs no other program, so it also works where a sandbox refuses
# ps. The clock runs only while the records can be read and show the command,
# so a command setup cannot see is never stopped for taking long. A working
# command shows progress within seconds, and 2 minutes is longer than macOS
# waits for an unanswered connection (75 seconds), so a slow network is left to
# finish.
owner_runner='
 const { spawn } = require("node:child_process");
 const fs = require("node:fs");
 const [directory, stalledMarker, mode, command, ...args] = process.argv.slice(1);
 const stallMs = 120000, lookMs = 5000, followMs = 50;
 const system = (() => {
  try {
   const { dlopen, FFIType: T, ptr } = require("bun:ffi");
   const lib = dlopen("/usr/lib/libSystem.B.dylib", {
    proc_listpids: { args: [T.u32, T.u32, T.ptr, T.i32], returns: T.i32 },
    proc_pidinfo: { args: [T.i32, T.i32, T.u64, T.ptr, T.i32], returns: T.i32 },
   }).symbols;
   const ids = new Int32Array(65536);
   const bsd = new Uint8Array(136), bsdView = new DataView(bsd.buffer), task = new Uint8Array(96), taskView = new DataView(task.buffer);
   const list = (kind, value) => { const bytes = lib.proc_listpids(kind, value, ptr(ids), ids.byteLength); return bytes < 0 ? null : [...ids.subarray(0, bytes / 4)].filter(id => id > 0); };
   // A record that cannot be read is of a process that has gone only when macOS says no such process exists.
   const unread = pid => { try { process.kill(pid, 0); } catch (error) { if (error.code === "ESRCH") return "gone"; } return null; };
   return {
    // The processes in a process group, and the children of a process.
    inGroup: group => list(2, group),
    children: parent => list(6, parent),
    // Who a process is: its parent, group and start time. "gone" once it has ended or is a zombie; null while its record cannot be read.
    record: pid => lib.proc_pidinfo(pid, 3, 0n, ptr(bsd), 136) === 136 ? (bsdView.getUint32(4, true) === 5 ? "gone" : { parent: bsdView.getUint32(16, true), group: bsdView.getUint32(100, true), start: bsdView.getBigUint64(120, true) * 1000000n + bsdView.getBigUint64(128, true) }) : unread(pid),
    // The processor time a process has used; null when it cannot be read.
    cpu: pid => lib.proc_pidinfo(pid, 4, 0n, ptr(task), 96) === 96 ? taskView.getBigUint64(16, true) + taskView.getBigUint64(24, true) : null,
   };
  } catch { return null; }
 })();
 // The processes whose progress counts. A process is known by its number and
 // start time, because macOS gives a number that is free to another program.
 // Only a process confirmed to be the command or one it started is held:
 //  - the command itself (taken while it has not yet been collected, so its
 //    number can belong to no other program);
 //  - a child of a held process, listed while that process is confirmed, before
 //    and after the listing, to be the same one, and itself showing that parent;
 //  - a process in the group of the step itself, every process of which
 //    belongs to setup;
 //  - a process in a group a held process made (the number of the group is the
 //    number of that process), listed while that process is confirmed, before
 //    and after the listing, to be the same one.
 // A held process is let go only once it is confirmed gone: ended, or its number
 // now belongs to a process that started at another time. While its record
 // cannot be read it is kept, and every look is unavailable.
 const holder = (system, self, stepGroup) => {
  const held = new Map();
  const known = record => record !== null && record !== "gone";
  const confirmed = (pid, start) => { const record = system.record(pid); return known(record) && record.start === start ? record : null; };
  const take = pid => { if (held.has(pid)) return; const record = system.record(pid); if (known(record)) held.set(pid, record.start); };
  const follow = () => {
   const seen = new Map();
   for (const [pid, start] of held) {
    const record = system.record(pid);
    if (record === "gone" || (known(record) && record.start !== start)) held.delete(pid);
    else if (known(record)) seen.set(pid, record);
   }
   for (let grown = true; grown;) {
    grown = false;
    const found = [], groups = new Map([[stepGroup, null]]);
    for (const [parent, record] of seen) {
     const kids = system.children(parent) ?? [], candidates = [];
     for (const kid of kids) {
      if (kid === self || held.has(kid)) continue;
      const kidRecord = system.record(kid);
      if (known(kidRecord) && kidRecord.parent === parent && kidRecord.start >= record.start) candidates.push([kid, kidRecord]);
     }
     if (candidates.length && confirmed(parent, record.start)) found.push(...candidates);
     if (record.group === parent && parent !== stepGroup) groups.set(parent, record.start);
    }
    for (const [group, leaderStart] of groups) {
     const inside = system.inGroup(group) ?? [], candidates = [];
     for (const pid of inside) {
      if (pid === self || held.has(pid)) continue;
      const record = system.record(pid);
      if (known(record) && record.group === group) candidates.push([pid, record]);
     }
     if (candidates.length && (leaderStart === null || confirmed(group, leaderStart)?.group === group)) found.push(...candidates);
    }
    for (const [pid, record] of found) if (!held.has(pid)) { held.set(pid, record.start); seen.set(pid, record); grown = true; }
   }
  };
  // What the held processes have done so far, or null when that cannot be
  // seen: no process is held, or a held process cannot be confirmed to be the
  // same one, even if its processor time can be read.
  const observe = () => {
   follow();
   if (!held.size) return null;
   const parts = [];
   for (const [pid, start] of held) {
    if (!confirmed(pid, start)) return null;
    const time = system.cpu(pid);
    if (time === null || !confirmed(pid, start)) return null;
    parts.push(pid + ":" + time);
   }
   return parts.sort().join(",");
  };
  return { held, take, follow, observe };
 };
 const stepGroup = system?.record(process.pid)?.group;
 const tracked = system && typeof stepGroup === "number" ? holder(system, process.pid, stepGroup) : null;
 const env = { ...process.env };
 const count = /^[0-9]+$/.test(env.GIT_CONFIG_COUNT ?? "") ? Number(env.GIT_CONFIG_COUNT) : 0;
 [["gc.auto", "0"], ["maintenance.auto", "false"]].forEach(([key, value], index) => { env["GIT_CONFIG_KEY_" + (count + index)] = key; env["GIT_CONFIG_VALUE_" + (count + index)] = value; });
 env.GIT_CONFIG_COUNT = String(count + 2);
 const child = spawn(command, args, { cwd: directory, env, stdio: "inherit" });
 child.on("error", () => process.exit(1));
 // Until the command has been collected, its number can belong to no other program.
 const follow = () => { if (!tracked || !child.pid) return; if (child.exitCode === null && child.signalCode === null) tracked.take(child.pid); tracked.follow(); };
 follow();
 setInterval(follow, followMs);
 // The no-progress clock runs only between two looks that both saw the command.
 let seen = null, still = 0, lookedAt = 0;
 if (mode === "watch") setInterval(() => {
  const now = Date.now(), view = tracked ? tracked.observe() : null;
  if (view === null) { lookedAt = 0; return; }
  if (view !== seen) { seen = view; still = 0; } else if (lookedAt) still += now - lookedAt;
  lookedAt = now;
  if (still >= stallMs) { fs.writeFileSync(stalledMarker, "no progress\n"); process.exit(124); }
 }, lookMs);
 child.on("exit", status => process.exit(status ?? 1));
'
# Usage: run_owned <folder> <watch|hold> <command...>.
run_owned() {
 owned_directory=$1; owned_mode=$2; shift 2
 rm -f "$tmp/app-stalled"
 step_open main || return 1
 step_exec "$tmp" "$bun" -e "$owner_runner" "$owned_directory" "$tmp/app-stalled" "$owned_mode" "$@" &
 step_started main
 step_wait main; owned_status=$step_status
 step_end main
 return "$owned_status"
}
# An app's plugin command, watched for progress.
run_app_in() { app_directory=$1; shift; run_owned "$app_directory" watch "$@"; }
run_app() { run_app_in "$tmp" "$@"; }
# A step of setup's own that may start processes of its own.
run_step() { run_owned "$tmp" hold "$@"; }

gate_curl() { /usr/bin/curl "$@"; }

# A server transfer is never stopped for taking long. It is stopped only when
# not one byte has arrived for 2 minutes, which covers a connection that never
# gets set up as well as a transfer that stops. 2 minutes is longer than macOS
# waits for an unanswered connection (75 seconds), so a slow network is left
# to finish, while a transfer that has stopped cannot hold setup for ever. The
# watch is a step of its own, and it signals the transfer's group only while
# setup still keeps that group's holder (see gate_transfer).
transfer_stall_seconds=120
transfer_watch='group=$1 output=$2 limit=$3 marker=$4 watched_size=-1 still=0
while kill -0 -- "-$group" 2>/dev/null; do
 size=$(wc -c <"$output" 2>/dev/null | tr -d " ") || size=0
 if [ "$size" != "$watched_size" ]; then watched_size=$size; still=0; else still=$((still + 1)); fi
 if [ "$still" -ge "$limit" ]; then : >"$marker"; kill -TERM -- "-$group" 2>/dev/null; kill -CONT -- "-$group" 2>/dev/null; exit 0; fi
 /bin/sleep 1
done'
# Usage: gate_transfer <output file> <curl arguments>. curl's -w output is left in "$tmp/transfer-status".
gate_transfer() {
 transfer_output=$1; shift
 rm -f "$tmp/transfer-stalled"; : >"$transfer_output"
 step_open main || return 1
 # --no-buffer: curl otherwise holds received bytes in its write buffer until
 # it is full or the transfer ends (curl 8.7.1, as macOS ships it), so a slow
 # transfer could look as if no byte had arrived.
 step_exec "$tmp" /usr/bin/curl --no-buffer -o "$transfer_output" "$@" >"$tmp/transfer-status" 2>/dev/null &
 step_started main
 if step_group "$main_files"; then
  step_open watch || return 1
  step_exec "$tmp" /bin/bash --posix -p -c "$transfer_watch" timesaver-watch "$step_g" "$transfer_output" "$transfer_stall_seconds" "$tmp/transfer-stalled" >/dev/null 2>&1 &
  step_started watch
 fi
 step_wait main; transfer_status=$step_status
 # The watch is ended first: until then, setup keeps the transfer's holder.
 step_end watch
 step_end main
 # curl's own code for a transfer that timed out.
 [ ! -f "$tmp/transfer-stalled" ] || transfer_status=28
 return "$transfer_status"
}

ensure_install_number() {
 install_number_file="$home/.timesaver/install-number"
 [ ! -L "$home/.timesaver" ] || return 1
 mkdir -p "$home/.timesaver" || return 1
 if [ -e "$install_number_file" ] || [ -L "$install_number_file" ]; then
  [ -f "$install_number_file" ] && [ ! -L "$install_number_file" ] && [ -O "$install_number_file" ] || return 1
  number_bytes=$(wc -c <"$install_number_file" | tr -d ' ')
  install_number=$(cat "$install_number_file")
  case "$install_number" in *[!0-9a-f]*) return 1 ;; esac
  if [ "$number_bytes" = 32 ] && [ "${#install_number}" = 32 ]; then return 0; fi
  [ "$number_bytes" -lt 32 ] && [ "$number_bytes" = "${#install_number}" ] || return 1
  # A prefix from an older interrupted write was never a complete identity.
  # Defer its repair to the verified release, so even an older installed helper
  # cannot refuse this retry before recovery. Stop reports stay silent meanwhile.
  return 2
 else
  fresh_number=$(/usr/bin/openssl rand -hex 16) || return 1
  number_temporary=$(/usr/bin/mktemp "$home/.timesaver/.install-number.XXXXXX") || return 1
  printf '%s' "$fresh_number" >"$number_temporary"
  ln "$number_temporary" "$install_number_file" 2>/dev/null || :
  rm -f "$number_temporary"
 fi
 [ -f "$install_number_file" ] && [ ! -L "$install_number_file" ] && [ -O "$install_number_file" ] || return 1
 [ "$(wc -c <"$install_number_file" | tr -d ' ')" = 32 ] || return 1
 install_number=$(cat "$install_number_file")
 case "$install_number" in *[!0-9a-f]*|'') return 1 ;; esac
 [ "${#install_number}" = 32 ]
}

json_text() { printf '%s' "$1" | LC_ALL=C tr -d '\000-\010\013-\037\177' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e "s/$(printf '\t')/\\\\t/g"; }
report_stop() {
	[ -n "${home:-}" ] || return 0
	stamp=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf 'unknown-time')
	report_id="$(printf '%s' "$stamp" | tr ':' '-')-$$"
	stop_root="$home/.timesaver/setup-stops"
	note="$stop_root/$report_id.txt"
	if mkdir -p "$stop_root" 2>/dev/null; then
		chmod 700 "$home/.timesaver" "$stop_root" 2>/dev/null || :
		printf 'MINDY TimeSaver setup stop\nTime (UTC): %s\nStep: %s\nReason: %s\n' "$stamp" "$step" "$1" >"$note" 2>/dev/null || :
		chmod 600 "$note" 2>/dev/null || :
	fi
	ensure_install_number || return 0
	app='not known'
	if [ -n "${CLAUDECODE:-}${CLAUDE_CODE_SESSION_ID:-}" ]; then app='Claude Code'
	elif [ -n "${CODEX_THREAD_ID:-}${CODEX_SESSION_ID:-}${CODEX_CLI_PATH:-}" ]; then app=Codex; fi
	report=$(printf '{"report":"mts-setup-stop/v1","reportId":"%s","installNumber":"%s","step":"%s","reason":"%s","stopNote":"","app":"%s","mindyVersion":"%s","macosVersion":"%s","stoppedAt":"%s"}' "$(json_text "$report_id")" "$install_number" "$(json_text "$step")" "$(json_text "$1")" "$app" "$(json_text "${installed_version:-}")" "$(json_text "$(/usr/bin/sw_vers -productVersion 2>/dev/null || :)")" "$(json_text "$stamp")")
	pending_report=$report
	return 0
}
# The report goes to MINDY's install server only after the person has their
# reply, and on its own, so a slow or unreachable server never holds the reply
# up. It ends within 15 seconds (curl's own limits) and touches nothing else.
send_report() {
	[ -n "$pending_report" ] || return 0
	(trap '' HUP INT TERM; printf '%s' "$pending_report" | gate_curl -sS --connect-timeout 5 --max-time 10 -H 'Content-Type: application/json' --data-binary @- 'https://gate.mindy.build/mts/setup-stops') </dev/null >/dev/null 2>&1 8>&- &
	pending_report=
}
fail_as() { finished=true; reason="Setup stopped while $step. $1"; report_stop "$reason" || :; printf '%s\n' "$reason"; send_report; exit 1; }
# 28 means not one byte arrived for 2 minutes (see gate_transfer).
fail_transfer() { if [ "$1" = 28 ]; then fail_as "$stalled_transfer"; fi; fail_as "$unreachable"; }

installed_version=
if [ -f "$HOME/.timesaver/install-state.json" ] && [ ! -f "$HOME/.timesaver/install-transaction.json" ]; then
  installed_version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$HOME/.timesaver/install-state.json" | head -n 1)
 fi
# The ordinary command repairs the signed current release, including a missing
# managed file or a deferred memory registration. Keep the existing help reply.
repairing=false
if [ "$chosen_action" != update ] && [ -f "$HOME/.timesaver/install-state.json" ] && [ ! -f "$HOME/.timesaver/install-transaction.json" ]; then repairing=true; fi
trap on_exit EXIT

[ -n "$tmp" ] || tmp=$(mktemp -d) || fail_as "$generic"
plugin_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P) || fail_as "$generic"
home=${HOME:-}
[ -n "$home" ] || fail_as "$generic"
step='checking this computer can run MINDY TimeSaver'
[ "$(uname -s)" = Darwin ] || fail_as 'Setup needs to run on this computer. Click the </> button, choose This computer and run /install-mts there.'
step='finding your saves folder'
read_content_root || fail_as "$generic"
if [ -x "$home/.timesaver/bin/bun" ] && [ ! -f "$home/.timesaver/install-transaction.json" ] && { [ -f "$home/.timesaver/install-state.json" ] || [ -f "$home/.timesaver/kept-saves.json" ]; }; then
 [ -d "$content_root" ] || fail_as "MINDY TimeSaver cannot reach your saves folder $(folder_place). Reconnect its disk or cloud folder, then try again. Your existing saves have not been changed."
fi
state_root="$home/.timesaver"
ensure_install_number || { number_status=$?; [ "$number_status" = 2 ] || fail_as "$generic"; }

packument="$tmp/packument.json"
step="asking MINDY TimeSaver's install server for the latest release"
if gate_transfer "$packument" -sS -H 'Accept: application/json' -w '%{http_code}' 'https://gate.mindy.build/mts'; then status=$(cat "$tmp/transfer-status"); else fail_transfer "$?"; fi
case "$status" in
	200) ;;
	403) fail_as "$unreachable" ;;
	429) fail_as "$too_many" ;;
	000) fail_as "$unreachable" ;;
	*) fail_as "$generic" ;;
esac
step='checking the latest release details'
grep -q '"name"[[:space:]]*:[[:space:]]*"mts"' "$packument" || fail_as "$unsigned"
tags=$(sed -n 's/.*"dist-tags"[[:space:]]*:[[:space:]]*{\([^}]*\)}.*/\1/p' "$packument" | head -n 1)
version=$(printf '%s\n' "$tags" | sed -n 's/.*"latest"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
# Repair the installed release. A later version still uses the existing yes-to-update route.
if [ "$repairing" = true ] && [ -n "$installed_version" ]; then version=$installed_version; fi
case "$version" in [0-9]*.[0-9]*.[0-9]*) ;; *) fail_as "$unsigned" ;; esac
entry=$(sed -n "s/.*\"$version\"[[:space:]]*:[[:space:]]*{\([^}]*\)}.*/\1/p" "$packument" | head -n 1)
integrity=$(printf '%s\n' "$entry" | sed -n 's/.*"integrity"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
case "$integrity" in sha512-*) ;; *) fail_as "$unsigned" ;; esac
if [ "${chosen_action:-}" = update ] && [ "$version" = "${installed_version:-}" ]; then
 finished=true
 printf '%s\n' "MINDY TimeSaver is already up to date, at version $version, so nothing has changed. You can carry on using it as you are."
 exit 0
fi

archive="$tmp/mts.tgz"
step='installing the MINDY TimeSaver release'
if gate_transfer "$archive" -sS -w '%{http_code}' "https://gate.mindy.build/mts/-/mts-$version.tgz"; then status=$(cat "$tmp/transfer-status"); else fail_transfer "$?"; fi
[ "$status" = 200 ] || fail_as "MINDY TimeSaver's install server didn't send it just now. Wait a minute, then type /install-mts again."
step='checking the file matches the release'
# Each check that reads the whole release runs as a recorded step (see held).
held shasum -a 512 "$archive" >"$tmp/archive-digest" 2>/dev/null || fail_as "$unsigned"
actual=$(sed 's/[[:space:]].*$//' "$tmp/archive-digest")
expected=$(printf '%s\n' "${integrity#sha512-}" | openssl base64 -d -A 2>/dev/null | od -An -tx1 | tr -d ' \n')
[ -n "$actual" ] && [ "$actual" = "$expected" ] || fail_as "$unsigned"
step='checking the install is a signed MINDY TimeSaver release'
entries="$tmp/archive-entries"
details="$tmp/archive-details"
[ "$(wc -c <"$archive" | tr -d ' ')" -le 262144000 ] || fail_as "$unsigned"
held tar -tzf "$archive" >"$entries" 2>/dev/null || fail_as "$unsigned"
[ "$(wc -l <"$entries" | tr -d ' ')" -le 1024 ] || fail_as "$unsigned"
while IFS= read -r archive_entry; do
	case "$archive_entry" in ''|/*|.|./*|*/./*|*/.|../*|*/../*|*/..|*\\*) fail_as "$unsigned" ;; esac
done <"$entries"
# A case-insensitive disk must not let a later path replace an earlier one.
LC_ALL=C awk '{ name = tolower($0); sub(/\/$/, "", name); if (seen[name]++) exit 1 }' "$entries" || fail_as "$unsigned"
held tar -tvzf "$archive" >"$details" 2>/dev/null || fail_as "$unsigned"
if grep -Ev '^[-d]' "$details" >/dev/null 2>&1; then fail_as "$unsigned"; fi
awk '$1 ~ /^-/ { if ($5 !~ /^[0-9]+$/ || $5 > 209715200) exit 1; total += $5; if (total > 629145600) exit 1 }' "$details" || fail_as "$unsigned"

checked="$tmp/checked"
mkdir -p "$checked"
held tar -xOf "$archive" package/release/release-signature.json >"$checked/release-signature.json" 2>/dev/null || fail_as "$unsigned"
held tar -xOf "$archive" package/release/release-signature.sig >"$checked/release-signature.sig" 2>/dev/null || fail_as "$unsigned"
held tar -xOf "$archive" package/release/release-manifest.json >"$checked/release-manifest.json" 2>/dev/null || fail_as "$unsigned"
key="$plugin_root/keys/timesaver-release-signature.pem"
[ -f "$key" ] || fail_as "$unsigned"
held openssl dgst -sha256 -verify "$key" -signature "$checked/release-signature.sig" "$checked/release-signature.json" >/dev/null 2>&1 || fail_as "$unsigned"
grep -q '"packageName":"mts"' "$checked/release-signature.json" || fail_as "$unsigned"
grep -q "\"packageVersion\":\"$version\"" "$checked/release-signature.json" || fail_as "$unsigned"
held shasum -a 256 "$checked/release-manifest.json" >"$tmp/manifest-digest" 2>/dev/null || fail_as "$unsigned"
manifest_digest=$(sed 's/[[:space:]].*$//' "$tmp/manifest-digest")
signed_manifest=$(sed -n 's/.*"manifestFileDigest":"sha256:\([^"]*\)".*/\1/p' "$checked/release-signature.json" | head -n 1)
[ "$manifest_digest" = "$signed_manifest" ] || fail_as "$unsigned"

mkdir -p "$tmp/unpacked"
held tar -xzf "$archive" -C "$tmp/unpacked" 2>/dev/null || fail_as "$unsigned"
release="$tmp/unpacked/package/release"
for control in release-manifest.json release-signature.json release-signature.sig; do
 cmp -s "$checked/$control" "$release/$control" || fail_as "$unsigned"
done

step='finding the right version for this computer'
machine=$(uname -m)
case "$machine" in arm64) arch=arm64 ;; x86_64) arch=x64 ;; *) fail_as "$generic" ;; esac
manifest="$checked/release-manifest.json"
runtime_tail=$(sed -n 's/.*"componentId":"mts-bun-runtime"\(.*\)/\1/p' "$manifest" | sed 's/"componentId".*//' | head -n 1)
runtime_entry=$(printf '%s\n' "$runtime_tail" | sed -n "s|.*\({[^{}]*\"path\":\"mts-install/sealed-parts/bun/darwin-$arch/bun\"[^{}]*}\).*|\1|p" | head -n 1)
bun_digest=$(printf '%s\n' "$runtime_entry" | sed -n 's/.*"fileDigest":"\(sha256:[^"]*\)".*/\1/p')
bun="$release/components/mts-bun-runtime/mts-install/sealed-parts/bun/darwin-$arch/bun"
[ -f "$bun" ] || fail_as "This version of MINDY TimeSaver came without the part it needs to run on this computer. Trying again won't fix this one, so type /mindyteam and let us know."
held shasum -a 256 "$bun" >"$tmp/runtime-digest" 2>/dev/null || fail_as "$unsigned"
[ "sha256:$(sed 's/[[:space:]].*$//' "$tmp/runtime-digest")" = "$bun_digest" ] || fail_as "$unsigned"
chmod 700 "$bun" || fail_as "$generic"

# This verifier belongs to setup, not the download. It loads only Bun built-ins.
# Check every listed component and refuse unlisted release files before source loads.
if held "$bun" -e '
 const fs = require("node:fs"), path = require("node:path"), crypto = require("node:crypto");
 const [release, componentId, firstScript, manifestPath] = process.argv.slice(1);
 const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
 const components = manifest.components.filter(item => item.componentId === componentId);
 if (components.length !== 1 || components[0].representations.length !== 1) process.exit(1);
 const validPath = value => typeof value === "string" && !value.includes("\\") && !path.isAbsolute(value) && !value.split("/").some(part => !part || part === "." || part === "..");
 const expected = new Map(), ids = new Set();
 for (const component of manifest.components) {
  if (!validPath(component.componentId) || component.componentId.includes("/") || ids.has(component.componentId)) process.exit(1);
  ids.add(component.componentId);
  for (const representation of component.representations) {
   for (const entry of representation.inventory) {
    if (!validPath(entry.path) || !/^sha256:[a-f0-9]{64}$/.test(entry.fileDigest)) process.exit(1);
    const relative = "components/" + component.componentId + "/" + entry.path;
    if (expected.has(relative)) process.exit(1);
    expected.set(relative, entry.fileDigest);
   }
  }
 }
 if (!expected.has("components/" + componentId + "/" + firstScript)) process.exit(1);
 if (!fs.lstatSync(release).isDirectory()) process.exit(1);
 const controls = new Set(["release-manifest.json", "release-signature.json", "release-signature.sig"]);
 const seen = new Set();
 // The builder writes canonical receipt bytes followed by one newline.
 function walk(directory, prefix) {
  for (const name of fs.readdirSync(directory)) {
   const file = path.join(directory, name), relative = prefix + name, info = fs.lstatSync(file);
   if (info.isDirectory()) { walk(file, relative + "/"); continue; }
   if (!info.isFile()) process.exit(1);
   if (controls.has(relative)) continue;
   if (relative === "build-receipt.json") {
    const bytes = fs.readFileSync(file);
    const receipt = bytes[bytes.length - 1] === 10 ? bytes.subarray(0, -1) : bytes;
    const digest = "sha256:" + crypto.createHash("sha256").update(receipt).digest("hex");
    if (digest !== manifest.provenance?.buildReceiptRef) process.exit(1);
    continue;
   }
   if (!expected.has(relative)) process.exit(1);
   const digest = "sha256:" + crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
   if (digest !== expected.get(relative)) process.exit(1);
   seen.add(relative);
  }
 }
 walk(release, "");
 if (seen.size !== expected.size) process.exit(1);
' "$release" mts-engine mts-install/runtime/install-release.ts "$manifest" >/dev/null 2>&1; then :; else fail_as "$unsigned"; fi

installer="$release/components/mts-engine/mts-install/runtime/install-release.ts"

step='finding your saves folder'
read_content_root "$bun" || fail_as "$generic"
if [ ! -f "$state_root/install-transaction.json" ] && { [ -f "$state_root/install-state.json" ] || [ -f "$state_root/kept-saves.json" ]; }; then
 [ -d "$content_root" ] || fail_as "MINDY TimeSaver cannot reach your saves folder $(folder_place). Reconnect its disk or cloud folder, then try again. Your existing saves have not been changed."
fi
step='checking the files inside the release'
# From here every step that runs the release's own code goes through the runner
# (run_step, run_owned), so a stop ends it and anything it started at once.
run_step "$bun" "$installer" "$release" "$content_root" "$state_root" --verify-only >/dev/null 2>&1 || fail_as "$unsigned"
if [ "$chosen_action" != update ] && [ -f "$state_root/install-transaction.json" ]; then
 if run_step "$bun" -e 'const tx = await Bun.file(process.argv[1]).json(); process.exit(tx.changed.some(item => item.destination === process.argv[2] && item.backup !== null) ? 0 : 1);' "$state_root/install-transaction.json" "$state_root/install-state.json"; then repairing=true; fi
fi
run_step "$bun" "$installer" "$release" "$content_root" "$state_root" --rollback-if-present >"$tmp/recovery.json" 2>/dev/null || fail_as "$generic"
recovered_current=false
if grep -q '"recovery":"finalized"' "$tmp/recovery.json"; then
 recovered_version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^\"]*\)".*/\1/p' "$state_root/install-state.json" | head -n 1)
 [ "$recovered_version" != "$version" ] || recovered_current=true
fi
install_result="$tmp/install.json"
step='installing MINDY TimeSaver'
had_previous=false
[ ! -f "$state_root/install-state.json" ] || had_previous=true
if [ "$recovered_current" = false ]; then
 run_step "$bun" "$installer" "$release" "$content_root" "$state_root" --prepare >"$install_result" 2>/dev/null || fail_as "$generic"
fi

marketplace="$state_root/plugin-marketplace"
# A registration that failed is undone, and the person is told whether the app stopped making progress.
app_failed() { app_reason=$generic; [ ! -f "$tmp/app-stalled" ] || app_reason=$app_stalled; rollback_registration; fail_as "$app_reason"; }
installed_marketplace_name='mindy'
installed_plugin_reference='timesaver@mindy'
registered=$account_plugin
step='making MINDY TimeSaver available in your apps'
claude_present=false
codex_present=false
if command -v claude >/dev/null 2>&1; then claude_present=true; fi
app_codex=${CODEX_CLI_PATH:-}
if ! command -v codex >/dev/null 2>&1 && [ -x "$app_codex" ] && [ "${app_codex##*/}" = codex ]; then PATH="$PATH:${app_codex%/codex}"; export PATH; fi
if command -v codex >/dev/null 2>&1; then codex_present=true; fi

old_public_timesaver() {
 # An unreadable or unfamiliar source leaves this registration alone.
 run_app "$1" plugin marketplace list --json >"$tmp/marketplaces-$1.json" 2>/dev/null || return 1
 held "$bun" -e '
  const [app, path] = process.argv.slice(1);
  const listing = await Bun.file(path).json();
  const entries = app === "claude" ? listing : listing.marketplaces;
  const old = Array.isArray(entries) && entries.find(entry => entry.name === "timesaver");
  const repository = "The-Monday-Stack/mindy-timesaver";
  const gitSources = [repository, `https://github.com/${repository}`, `https://github.com/${repository}.git`, `git@github.com:${repository}.git`];
  const matches = app === "claude"
   ? old?.source === "github" && old.repo === repository
   : old?.marketplaceSource?.sourceType === "git" && gitSources.includes(old.marketplaceSource.source);
  process.exit(matches ? 0 : 1);
 ' "$1" "$tmp/marketplaces-$1.json" >/dev/null 2>&1
}

remove_old_registration() {
	# The old content and state folders remain untouched. Only app registrations go.
	if [ "$claude_present" = true ]; then
		if old_public_timesaver claude; then
			run_app claude plugin uninstall timesaver@timesaver --scope user >/dev/null 2>&1 || :
			run_app claude plugin marketplace remove timesaver --scope user >/dev/null 2>&1 || :
		fi
		run_app claude plugin uninstall timesaver@timesaver-marketplace --scope user >/dev/null 2>&1 || :
		run_app claude plugin marketplace remove timesaver-marketplace --scope user >/dev/null 2>&1 || :
		run_app claude plugin uninstall timecone@timecone-marketplace --scope user >/dev/null 2>&1 || :
		run_app claude plugin uninstall timecone@timecone --scope user >/dev/null 2>&1 || :
		run_app claude plugin marketplace remove timecone-marketplace --scope user >/dev/null 2>&1 || :
		run_app claude plugin marketplace remove timecone --scope user >/dev/null 2>&1 || :
	fi
	if [ "$codex_present" = true ]; then
		if old_public_timesaver codex; then
			run_app codex plugin remove timesaver@timesaver --json >/dev/null 2>&1 || :
			run_app codex plugin marketplace remove timesaver --json >/dev/null 2>&1 || :
		fi
		run_app codex plugin remove timesaver@timesaver-marketplace --json >/dev/null 2>&1 || :
		run_app codex plugin marketplace remove timesaver-marketplace --json >/dev/null 2>&1 || :
		run_app codex plugin remove timecone@timecone-marketplace --json >/dev/null 2>&1 || :
		run_app codex plugin remove timecone@timecone --json >/dev/null 2>&1 || :
		run_app codex plugin marketplace remove timecone-marketplace --json >/dev/null 2>&1 || :
		run_app codex plugin marketplace remove timecone --json >/dev/null 2>&1 || :
	fi
}

claude_added=false
codex_added=false
has_public_plugin() {
 run_app "$1" plugin list --json >"$tmp/plugins-$1.json" 2>/dev/null || return 1
 held "$bun" -e '
  const [app, path] = process.argv.slice(1), listing = await Bun.file(path).json();
  const entries = app === "claude" ? listing : listing.installed;
  const prior = Array.isArray(entries) && entries.find(entry => ["timesaver@mindy-memory", "timesaver@timesaver-marketplace"].includes(entry.id ?? entry.pluginId));
  await Bun.write(path + ".restore", prior ? prior.id ?? prior.pluginId : "");
  process.exit(Array.isArray(entries) && entries.some(entry => (["timesaver@mindy", ...(app === "claude" ? ["timesaver@synced"] : [])].includes(entry.id ?? entry.pluginId)) && (() => { const [major, minor] = String(entry.version ?? "0.0.0").split(".").map(Number); return major > 1 || major === 1 && minor >= 1; })()) ? 0 : 1);
 ' "$1" "$tmp/plugins-$1.json" >/dev/null 2>&1
}
ensure_public_marketplace() {
 run_app "$1" plugin marketplace list --json >"$tmp/public-marketplaces-$1.json" 2>/dev/null || return 1
 if held "$bun" -e '
  const [app, path] = process.argv.slice(1), listing = await Bun.file(path).json();
  const entries = app === "claude" ? listing : listing.marketplaces;
  process.exit(Array.isArray(entries) && entries.some(entry => entry.name === "mindy") ? 0 : 1);
 ' "$1" "$tmp/public-marketplaces-$1.json" >/dev/null 2>&1; then
  if [ "$1" = claude ]; then run_app claude plugin marketplace update mindy >/dev/null 2>&1
  elif held "$bun" -e 'const value = await Bun.file(process.argv[1]).json(); process.exit(value.marketplaces.find(row => row.name === "mindy")?.marketplaceSource?.sourceType === "git" ? 0 : 1);' "$tmp/public-marketplaces-codex.json"; then run_app codex plugin marketplace upgrade mindy --json >/dev/null 2>&1
  else return 0; fi
  return $?
 fi
 if [ "$1" = claude ]; then run_app claude plugin marketplace add The-Monday-Stack/Mindy --scope user >/dev/null 2>&1
 else run_app codex plugin marketplace add https://github.com/The-Monday-Stack/Mindy.git --json >/dev/null 2>&1; fi
}
remove_private_copy() {
 if [ "$claude_present" = true ]; then
  if run_app claude plugin list --json >"$tmp/legacy-claude.json" 2>/dev/null && held "$bun" -e 'const rows = await Bun.file(process.argv[1]).json(); process.exit(rows.some(row => row.id === "timesaver@mindy-memory") ? 0 : 1);' "$tmp/legacy-claude.json"; then
   run_app claude plugin uninstall timesaver@mindy-memory --scope user >/dev/null 2>&1 || return 1
  fi
  run_app claude plugin marketplace remove mindy-memory --scope user >/dev/null 2>&1 || :
 fi
 if [ "$codex_present" = true ]; then
  if run_app codex plugin list --json >"$tmp/legacy-codex.json" 2>/dev/null && held "$bun" -e 'const value = await Bun.file(process.argv[1]).json(); process.exit(value.installed.some(row => row.pluginId === "timesaver@mindy-memory") ? 0 : 1);' "$tmp/legacy-codex.json"; then
   run_app codex plugin remove timesaver@mindy-memory --json >/dev/null 2>&1 || return 1
  fi
  run_app codex plugin marketplace remove mindy-memory --json >/dev/null 2>&1 || :
 fi
}
rollback_registration() {
 if [ "$claude_added" = true ]; then run_app claude plugin uninstall "$installed_plugin_reference" --scope user >/dev/null 2>&1 || :; fi
 if [ "$codex_added" = true ]; then run_app codex plugin remove "$installed_plugin_reference" --json >/dev/null 2>&1 || :; fi
 run_step "$bun" "$installer" "$release" "$content_root" "$state_root" --rollback >/dev/null 2>&1 || return 1
 if [ "$had_previous" = true ]; then
  for app in claude codex; do
   if [ -s "$tmp/plugins-$app.json.restore" ]; then
    prior_reference=$(cat "$tmp/plugins-$app.json.restore")
    if [ "$app" = claude ]; then { run_app_in "$content_root" claude plugin marketplace add "$marketplace" --scope user >/dev/null 2>&1 && run_app_in "$content_root" claude plugin install "$prior_reference" --scope user >/dev/null 2>&1; } || return 1
    else { run_app_in "$content_root" codex plugin marketplace add "$marketplace" --json >/dev/null 2>&1 && run_app_in "$content_root" codex plugin add "$prior_reference" --json >/dev/null 2>&1; } || return 1; fi
   fi
  done
 fi
}

if [ "$claude_present" = true ] && [ "$account_plugin" = false ]; then
 if ! has_public_plugin claude; then
  if ! ensure_public_marketplace claude; then app_failed; fi
  if held "$bun" -e 'const value = await Bun.file(process.argv[1]).json(); process.exit(value.some(row => row.id === "timesaver@mindy") ? 0 : 1);' "$tmp/plugins-claude.json"; then
   if ! run_app_in "$content_root" claude plugin update "$installed_plugin_reference" --scope user >/dev/null 2>&1; then app_failed; fi
  elif ! run_app_in "$content_root" claude plugin install "$installed_plugin_reference" --scope user >/dev/null 2>&1; then app_failed; fi
  claude_added=true
 fi
 registered=true
fi
if [ "$codex_present" = true ]; then
 if ! has_public_plugin codex; then
  if ! ensure_public_marketplace codex || ! run_app_in "$content_root" codex plugin add "$installed_plugin_reference" --json >/dev/null 2>&1; then app_failed; fi
  codex_added=true
 fi
 registered=true
fi
if [ "$registered" != true ]; then rollback_registration; fail_as "$generic"; fi
remove_private_copy || app_failed
remove_old_registration
if [ "$had_previous" = false ]; then
 run_step /usr/bin/env MTS_STATE_ROOT="$state_root" "$bun" "$content_root/timesaver-install/runtime/privacy.ts" reports-on >/dev/null 2>&1 || { rollback_registration; fail_as "$generic"; }
fi
run_step "$bun" "$installer" "$release" "$content_root" "$state_root" --finalize >/dev/null 2>&1 || { rollback_registration; fail_as "$generic"; }
if [ "${chosen_action:-}" != update ] && [ "$repairing" = false ]; then printf '%s\n' '{"stage":"chat-keeping"}' >"$state_root/setup-progress.json"; fi

if [ -f "$state_root/memory-note-warning.txt" ]; then cat "$state_root/memory-note-warning.txt"; rm -f "$state_root/memory-note-warning.txt"; fi
finished=true
# An update ends here: the welcome and the setup messages are for a first install.
if [ "${chosen_action:-}" = update ]; then printf '%s\n' "MINDY TimeSaver is now updated to version $version. Start a new session to use the new version."; exit 0; fi
if [ "$repairing" = true ]; then
 printf '%s\n' "MINDY TimeSaver is already installed $(folder_place)."
 show_help
 printf '\n%s\n' "$update_offer"
 exit 0
fi
printf '%s\n' "MINDY TimeSaver is now $(folder_place)."
print_welcome
printf '%s\n' "If you need help, type /mindyteam and your message. For all installation steps, go to https://install.mindy.build."

if [ "$account_plugin" = false ]; then printf "MTS_HOST_UI=%s\n" "$(host_ui)"; fi
