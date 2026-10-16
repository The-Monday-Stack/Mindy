#!/bin/sh
set -eu

start='type /install-mts'
capital="$(printf '%s' "$start" | cut -c 1 | tr '[:lower:]' '[:upper:]')$(printf '%s' "$start" | cut -c 2-)"
no_code="This needs your MINDY TimeSaver access code, which came in the message with your install steps. $capital, a space and your code, all on one line."
chat_unreadable="We couldn't read this chat on this computer, so setup hasn't started. Start a new chat on this computer and type /install-mts with your code there."
not_issued="This isn't a MINDY TimeSaver access code. It may be the code for your other MINDY product, which is different. Nothing was installed. Type /install-mts with your MINDY TimeSaver access code instead."
not_active="This access code has been switched off, so it can't install MINDY TimeSaver any more. You've typed it right - it's the code itself that isn't active. If you've got a newer code, type /install-mts with that one, and if not, just reply to the email your code came in."
different="This computer already has a different MINDY TimeSaver access code saved, and MINDY TimeSaver uses one code per computer. $capital with that earlier code."
unsigned="This isn't a signed MINDY TimeSaver release, so setup stopped before installing anything, to keep this computer safe. Check you're on your usual internet connection, then type /install-mts with your access code again."
too_many="Too many tries from this internet connection in the last minute, so MINDY TimeSaver's install server is pausing for a moment. Wait a minute, then $start with your access code again."
unreachable="Setup could not reach MINDY TimeSaver's install server. Check you are online, then $start with your access code again."
stalled_transfer="The connection to MINDY TimeSaver's install server made no progress for 2 minutes, so setup stopped. Nothing has been installed. Check you are online, then $start with your access code again."
app_stalled="Your app made no progress adding MINDY TimeSaver for 2 minutes, so setup stopped it and undid this setup's changes. Check you are online, then $start with your access code again."
interrupted="Setup stopped because it was interrupted. $capital with your access code to start again."
generic="It's safe to run setup again, so type /install-mts with your access code to have another go."

# JXA is supplied by macOS, including before our Bun runtime is installed.
# Only the identified chat is opened. Its contents never enter command arguments.
# It runs only as setup's recorded background reader: it becomes that step's
# holder, so a stop reaches the reader (see Steps and the chat read below).
read_chat_code() {
 step_exec / /usr/bin/osascript -l JavaScript - "$chat_file" "$chat_harness" "$chat_id" <<'MTS_READ_CURRENT_CHAT'
ObjC.import('Foundation');
function run(arguments) {
 const manager = $.NSFileManager.defaultManager;
 const environment = $.NSProcessInfo.processInfo.environment;
 const get = key => { const value = environment.objectForKey(key); return value.isNil() ? '' : ObjC.unwrap(value); };
 const children = directory => {
  const value = manager.contentsOfDirectoryAtPathError(directory, null);
  return value.isNil() ? [] : ObjC.deepUnwrap(value).map(name => directory + '/' + name);
 };
 const read = file => {
  const value = $.NSString.stringWithContentsOfFileEncodingError(file, $.NSUTF8StringEncoding, null);
  if (value.isNil()) throw Error('chat unavailable');
  return ObjC.unwrap(value);
 };
 const claude = arguments[1] === 'claude' ? arguments[2] : arguments[1] === 'codex' ? '' : get('CLAUDE_CODE_SESSION_ID') || get('CLAUDE_SESSION_ID');
 const codex = arguments[1] === 'codex' ? arguments[2] : claude ? '' : get('CODEX_THREAD_ID') || get('CODEX_SESSION_ID');
 if (!/^[a-zA-Z0-9_-]+$/.test(claude || codex)) throw Error('current chat not identified');
 let candidates = [];
 if (arguments[0]) candidates.push(arguments[0]);
 else if (claude && /^[a-zA-Z0-9_-]+$/.test(claude)) {
  for (const directory of children((get('CLAUDE_CONFIG_DIR') || get('HOME') + '/.claude') + '/projects')) {
   const file = directory + '/' + claude + '.jsonl';
   if (manager.fileExistsAtPath(file)) candidates.push(file);
  }
 } else if (codex && /^[a-zA-Z0-9_-]+$/.test(codex)) {
  const base = get('CODEX_HOME') || get('HOME') + '/.codex';
  for (const storage of ['sessions', 'archived_sessions']) {
   const iterator = manager.enumeratorAtPath(base + '/' + storage);
   if (iterator.isNil()) continue;
   let entry;
   while (!(entry = iterator.nextObject).isNil()) {
    const relative = ObjC.unwrap(entry);
    if (relative.split('/').pop().startsWith('rollout-') && relative.endsWith('-' + codex + '.jsonl')) candidates.push(base + '/' + storage + '/' + relative);
   }
  }
 } else throw Error('current chat not identified');
 if (candidates.length !== 1 || candidates[0][0] !== '/') throw Error('current chat not unique');
 const file = candidates[0];
 const attributes = manager.attributesOfItemAtPathError(file, null);
 if (attributes.isNil() || ObjC.unwrap(attributes.objectForKey($.NSFileType)) !== 'NSFileTypeRegular') throw Error('chat unavailable');
 const textOf = content => typeof content === 'string' ? content : Array.isArray(content)
  ? content.filter(item => item && ['text', 'input_text'].includes(item.type) && typeof item.text === 'string').map(item => item.text).join('\n') : '';
 // Only a whole message that is this host's own install invocation can supply
 // the code. Claude Code records a typed /install-mts as its command tags and
 // nothing else; Codex and the ChatGPT app record the typed words themselves.
 // An invocation inside pasted, quoted or logged text, or in the other host's
 // form, is never one, so it can never supply or replace a code.
 const name = '(?:[a-zA-Z0-9_-]+:)?install-mts';
 const invocation = claude
  ? new RegExp('^(?:<command-message>[^<]*</command-message>\\s*)?<command-name>/' + name + '</command-name>\\s*(?:<command-message>[^<]*</command-message>\\s*)?<command-args>([^<]*)</command-args>$')
  : new RegExp('^(?:[/$]' + name + '|\\[\\$?' + name + '\\]\\([^\\n()]*/install-mts/SKILL\\.md\\))(?:\\s+([^]*))?$');
 // The invocation's argument must be the code alone: the issued Ed25519
 // signature is 86 base64url characters, and one full stop may end it.
 const alone = /^([`'"]?)([a-zA-Z0-9-]{3,32}\.[a-zA-Z0-9_-]{86})\1\.?$/;
 // An appending writer may not have finished its last row yet. Wait for it
 // even when an earlier code is already there: it may be the newer code.
 let lines;
 for (let attempt = 0; ; attempt++) {
  lines = read(file).split('\n');
  const last = lines[lines.length - 1];
  let unfinished = false;
  if (last.trim()) { try { JSON.parse(last); } catch (_) { unfinished = true; } }
  if (!unfinished) break;
  if (attempt === 9) throw Error('chat still being written');
  $.NSThread.sleepForTimeInterval(0.2);
 }
  const rows = lines.filter(line => line.trim()).map(line => {
   const row = JSON.parse(line);
   if (!row || typeof row !== 'object' || Array.isArray(row)) throw Error('invalid chat');
   return row;
  });
  const firstMeta = rows.find(row => row.type === 'session_meta');
  if (codex && (!firstMeta || !firstMeta.payload || firstMeta.payload.id !== codex)) throw Error('wrong thread');
  if (claude && !rows.some(row => row.sessionId === claude && row.message)) throw Error('wrong session');
  let code = '';
  for (const row of rows) {
   let message;
   if (codex && row.type === 'response_item') message = row.payload && row.payload.type === 'message' ? row.payload : null;
   else if (!codex && row.type === 'user' && !row.isMeta && (!claude || row.sessionId === claude)) message = row.message;
   if (!message || message.role !== 'user') continue;
   const install = textOf(message.content).trim().match(invocation);
   if (!install) continue;
   // The newest install invocation decides: without a code alone, it has none.
   const given = (install[1] || '').trim().match(alone);
   code = given ? given[2] : '';
  }
  return code;
}
MTS_READ_CURRENT_CHAT
}

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
2. Select one of these chats in your left hand column.
3. Type /mindyend at the bottom of the chat.
4. Mindy will save every time you asked, decided or did something important to your TimeSaver.
5. When you want to pick up that project again, type /mindyload [subject] or /mindyload alone to select a saved session.
6. Repeat for as many chats and sessions that you want to keep! :)

(And use /mindysearch to find anything in your entire TimeSaver.)

Remember: Mindy TimeSaver gets more valuable the more you use it. So don't forget: When you want to save time by saving time - always /mindyend.
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
# A variable this computer already exported stays exported when setup gives it
# a value, so every program setup starts would see it. Each variable that holds
# the access code, or the name of a file or pipe the code passes through, is
# unset before setup gives it a value.
unset code chat_code_copy chat_pipe
code=
account_plugin=false
from_chat=false
chat_file=
chat_harness=
chat_id=
for argument in "$@"; do
 case "$argument" in --account-plugin) account_plugin=true ;; --code-from-chat) from_chat=true ;; esac
done
while [ "$#" -gt 0 ]; do
 case "$1" in
  --code-from-chat|--account-plugin) shift ;;
  --claude-session|--codex-thread)
   case "$1" in --claude-session) chat_harness=claude ;; --codex-thread) chat_harness=codex ;; esac
   shift; chat_id=${1:-}; [ -n "$chat_id" ] || { printf '%s\n' "$chat_unreadable"; exit 1; }; shift ;;
  --transcript) shift; chat_file=${1:-}; [ -n "$chat_file" ] || { printf '%s\n' "$chat_unreadable"; exit 1; }; shift ;;
  *) printf '%s\n' 'Setup reads your code from this chat. Use /install-mts with your code in the message box to start.'; exit 1 ;;
 esac
done

tmp=
chat_code_copy=
chat_code_copy_ready=
finished=false
pending_report=
step='starting MINDY TimeSaver setup'
cleanup() { if [ "${1:-0}" != 0 ] && [ -n "$chat_code_copy" ] && [ -f "$chat_code_copy_ready" ]; then rm -f "$chat_code_copy"; fi; [ -z "$tmp" ] || rm -rf "$tmp"; }
# A stop can arrive while a function's output goes to a temporary file, so the
# stop sentence uses the chat's own output, kept on descriptor 8.
exec 8>&1
# The stop record is kept on this computer first. The report to MINDY's install
# server goes only after the person has their reply (see send_report).
on_signal() { trap '' HUP INT TERM; finished=true; reason="Setup stopped while $step. $interrupted"; report_stop "$reason" || :; stop_steps; cleanup 1; printf '%s\n' "$reason" >&8; send_report; exit 1; }
on_exit() { status=$?; stop_steps; if [ "$status" != 0 ] && [ "$finished" = false ]; then report_stop "Setup stopped while $step. $generic" || :; fi; cleanup "$status"; if [ "$status" != 0 ] && [ "$finished" = false ]; then printf '%s\n' "Setup stopped while $step. $generic" >&8; send_report; fi; }
# Interruption is handled from here on, including while this chat is read.
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
# number, then the step's exit status. It ends when the step and its holder have
# both closed the pipe, and no stop signal ends it before then.
step_reader() {
 trap '' HUP INT TERM
 while IFS= read -r step_line; do
  case "$step_line" in g*) printf '%s\n' "${step_line#g}" >"$1.group" ;; s*) printf '%s\n' "${step_line#s}" >"$1.status" ;; esac
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
# Usage: run_owned <folder> <watch|hold> <none|line|raw> <command...>. line and
# raw give the command the access code on its input (with or without a newline),
# never in its arguments.
run_owned() {
 owned_directory=$1; owned_mode=$2; owned_input=$3; shift 3
 rm -f "$tmp/app-stalled"
 step_open main || return 1
 case "$owned_input" in
  line) printf '%s\n' "$code" | step_exec "$tmp" "$bun" -e "$owner_runner" "$owned_directory" "$tmp/app-stalled" "$owned_mode" "$@" & ;;
  raw) printf '%s' "$code" | step_exec "$tmp" "$bun" -e "$owner_runner" "$owned_directory" "$tmp/app-stalled" "$owned_mode" "$@" & ;;
  *) step_exec "$tmp" "$bun" -e "$owner_runner" "$owned_directory" "$tmp/app-stalled" "$owned_mode" "$@" & ;;
 esac
 step_started main
 step_wait main; owned_status=$step_status
 step_end main
 return "$owned_status"
}
# An app's plugin command, watched for progress.
run_app_in() { app_directory=$1; shift; run_owned "$app_directory" watch none "$@"; }
run_app() { run_app_in "$tmp" "$@"; }
# A step of setup's own that may start processes of its own.
run_step() { run_owned "$tmp" hold none "$@"; }

# The access code is handed only to macOS's own curl, named in full, so no
# other program found by name can receive it.
gate_curl() {
	/usr/bin/curl -H @/dev/fd/3 "$@" 3<<GATE_AUTHORIZATION
Authorization: Bearer $code
GATE_AUTHORIZATION
}

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
 (step_exec "$tmp" /usr/bin/curl --no-buffer -H @/dev/fd/3 -o "$transfer_output" "$@") 3<<GATE_AUTHORIZATION >"$tmp/transfer-status" 2>/dev/null &
Authorization: Bearer $code
GATE_AUTHORIZATION
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

json_text() { printf '%s' "$1" | LC_ALL=C tr -d '\000-\010\013-\037\177' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e "s/$(printf '\t')/\\\\t/g"; }
report_stop() {
	[ -n "${home:-}" ] && [ -n "$code" ] || return 0
	stamp=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf 'unknown-time')
	report_id="$(printf '%s' "$stamp" | tr ':' '-')-$$"
	stop_root="$home/.timesaver/setup-stops"
	note="$stop_root/$report_id.txt"
	if mkdir -p "$stop_root" 2>/dev/null; then
		chmod 700 "$home/.timesaver" "$stop_root" 2>/dev/null || :
		printf 'MINDY TimeSaver setup stop\nTime (UTC): %s\nStep: %s\nReason: %s\n' "$stamp" "$step" "$1" >"$note" 2>/dev/null || :
		chmod 600 "$note" 2>/dev/null || :
	fi
	access_number=${code%.*}
	case "$access_number" in ''|*[!A-Za-z0-9-]*) return 0 ;; esac
	[ "$access_number" != "$code" ] || return 0
	report=$(printf '{"report":"mts-setup-stop/v1","product":"mts","reportId":"%s","membershipNumber":"%s","step":"%s","reason":"%s","stoppedAt":"%s"}' "$(json_text "$report_id")" "$(json_text "$access_number")" "$(json_text "$step")" "$(json_text "$1")" "$(json_text "$stamp")")
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

if [ "$from_chat" = true ]; then
 [ "$(uname -s)" = Darwin ] || { printf '%s\n' 'Setup needs to run on this computer. Click the </> button, choose Local and run /install-mts there.'; exit 1; }
 step='reading your code from this chat'
 # The reader runs in the background as a recorded step (see Steps), so a stop
 # ends it and waits for it before the interruption sentence, however long its
 # read takes. Its answer comes back through a pipe that has no name on disk,
 # never a file. Setup's temporary folder holds the step's own pipes.
 tmp=$(mktemp -d) || { printf '%s\n' "$chat_unreadable"; exit 1; }
 trap cleanup EXIT
 chat_pipe=$(mktemp -d) || { printf '%s\n' "$chat_unreadable"; exit 1; }
 if mkfifo -m 600 "$chat_pipe/code"; then exec 9<>"$chat_pipe/code"; else rm -rf "$chat_pipe"; printf '%s\n' "$chat_unreadable"; exit 1; fi
 rm -rf "$chat_pipe"
 step_open main || { printf '%s\n' "$chat_unreadable"; exit 1; }
 read_chat_code >&9 2>/dev/null &
 step_started main
 step_wait main; reader_status=$step_status
 step_end main
 # One more line after the reader's answer, so this read never waits.
 printf '\n' >&9
 IFS= read -r code <&9 || code=
 exec 9>&-
 if [ "$reader_status" != 0 ]; then code=; printf '%s\n' "$chat_unreadable"; exit 1; fi
 if [ -z "$code" ]; then printf '%s\n' "$no_code"; exit 1; fi
 step='starting MINDY TimeSaver setup'
fi
# An unfinished setup retains its transaction until app registration succeeds.
if [ -z "$code" ] && [ -f "$HOME/.timesaver/install-state.json" ] && [ ! -f "$HOME/.timesaver/install-transaction.json" ]; then
 read_content_root
 printf '%s\n' "MINDY TimeSaver is already installed $(folder_place)."
 show_help
 exit 0
fi
if [ -z "$code" ]; then printf '%s\n' "$no_code"; exit 0; fi
trap on_exit EXIT

[ -n "$tmp" ] || tmp=$(mktemp -d) || fail_as "$generic"
plugin_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P) || fail_as "$generic"
home=${HOME:-}
[ -n "$home" ] || fail_as "$generic"
step='checking this computer can run MINDY TimeSaver'
[ "$(uname -s)" = Darwin ] || fail_as 'Setup needs to run on this computer. Click the </> button, choose Local and run /install-mts there.'
step='finding your saves folder'
read_content_root || fail_as "$generic"
if [ -x "$home/.timesaver/bin/bun" ] && [ ! -f "$home/.timesaver/install-transaction.json" ] && { [ -f "$home/.timesaver/install-state.json" ] || [ -f "$home/.timesaver/kept-saves.json" ]; }; then
 [ -d "$content_root" ] || fail_as "MINDY TimeSaver cannot reach your saves folder $(folder_place). Reconnect its disk or cloud folder, then try again. Your existing saves have not been changed."
fi
state_root="$home/.timesaver"

packument="$tmp/packument.json"
step="asking MINDY TimeSaver's install server for the latest release"
if gate_transfer "$packument" -sS -H 'Accept: application/json' -w '%{http_code}' 'https://gate.mindy.build/mts'; then status=$(cat "$tmp/transfer-status"); else fail_transfer "$?"; fi
case "$status" in
	200) ;;
	403) if grep -qi 'no longer active\|expired\|revoked' "$packument"; then fail_as "$not_active"; else fail_as "$not_issued"; fi ;;
	429) fail_as "$too_many" ;;
	000) fail_as "$unreachable" ;;
	*) fail_as "$generic" ;;
esac
step='checking the latest release details'
grep -q '"name"[[:space:]]*:[[:space:]]*"mts"' "$packument" || fail_as "$unsigned"
tags=$(sed -n 's/.*"dist-tags"[[:space:]]*:[[:space:]]*{\([^}]*\)}.*/\1/p' "$packument" | head -n 1)
version=$(printf '%s\n' "$tags" | sed -n 's/.*"latest"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
case "$version" in [0-9]*.[0-9]*.[0-9]*) ;; *) fail_as "$unsigned" ;; esac
entry=$(sed -n "s/.*\"$version\"[[:space:]]*:[[:space:]]*{\([^}]*\)}.*/\1/p" "$packument" | head -n 1)
integrity=$(printf '%s\n' "$entry" | sed -n 's/.*"integrity"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
case "$integrity" in sha512-*) ;; *) fail_as "$unsigned" ;; esac

archive="$tmp/mts.tgz"
step='installing the MINDY TimeSaver release'
if gate_transfer "$archive" -sS -w '%{http_code}' "https://gate.mindy.build/mts/-/mts-$version.tgz"; then status=$(cat "$tmp/transfer-status"); else fail_transfer "$?"; fi
[ "$status" = 200 ] || fail_as "MINDY TimeSaver's install server didn't send it just now. Wait a minute, then type /install-mts with your access code again."
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
[ -f "$bun" ] || fail_as "This version of MINDY TimeSaver came without the part it needs to run on this computer. Trying again won't fix this one, so reply to the email your access code came in and let us know."
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
run_step "$bun" "$installer" "$release" "$content_root" "$state_root" --rollback-if-present >/dev/null 2>&1 || fail_as "$generic"
save_code="$release/components/mts-engine/mts-install/runtime/save-access-code.ts"
different_code_refusal=$(run_step "$bun" -e 'const { MTS_DIFFERENT_ACCESS_CODE } = await import(process.argv[1]); process.stdout.write(MTS_DIFFERENT_ACCESS_CODE);' "$release/components/mts-engine/mts-install/access-code-file.ts") || fail_as "$generic"
save_error="$tmp/save-code-error"
step='saving your access code on this computer'
if run_owned "$tmp" hold line "$bun" "$save_code" >/dev/null 2>"$save_error"; then :
elif grep -Fxq "$different_code_refusal" "$save_error"; then fail_as "$different"
else fail_as "$generic"
fi
install_result="$tmp/install.json"
step='installing MINDY TimeSaver'
had_previous=false
[ ! -f "$state_root/install-state.json" ] || had_previous=true
run_step "$bun" "$installer" "$release" "$content_root" "$state_root" --prepare >"$install_result" 2>/dev/null || fail_as "$generic"

# Chat runs on Anthropic's machine. Its connected folder supplies this code copy.
# Keep the code on stdin, and keep the copy private beside the saving setting.
chat_code_copy="$content_root/.timesaver/timesaver-access-code"
chat_code_copy_ready="$tmp/chat-code-copy-ready"
if run_owned "$tmp" hold raw "$bun" -e '
 const fs = require("node:fs"), path = require("node:path");
 const folder = path.join(process.argv[1], ".timesaver");
 const info = fs.lstatSync(folder);
 if (!info.isDirectory() || info.isSymbolicLink() || info.uid !== process.getuid()) process.exit(1);
 fs.chmodSync(folder, 0o700);
 const searches = path.join(folder, "search-commands");
 fs.mkdirSync(searches, { recursive: true, mode: 0o700 });
 const searchesInfo = fs.lstatSync(searches);
 if (!searchesInfo.isDirectory() || searchesInfo.isSymbolicLink() || searchesInfo.uid !== process.getuid()) process.exit(1);
 fs.chmodSync(searches, 0o700);
 const target = path.join(folder, "timesaver-access-code");
 if (fs.existsSync(target)) {
  const old = fs.lstatSync(target);
  if (!old.isFile() || old.isSymbolicLink() || old.nlink !== 1 || old.uid !== process.getuid()) process.exit(1);
 }
 const code = await Bun.stdin.text();
 const fd = fs.openSync(target, fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_TRUNC | fs.constants.O_NOFOLLOW, 0o600);
 try { fs.fchmodSync(fd, 0o600); fs.writeFileSync(process.argv[2], "ready", { mode: 0o600 }); fs.writeFileSync(fd, code); fs.fsyncSync(fd); } finally { fs.closeSync(fd); }
' "$content_root" "$chat_code_copy_ready" >/dev/null 2>&1; then :
else run_step "$bun" "$installer" "$release" "$content_root" "$state_root" --rollback-if-present >/dev/null 2>&1 || :; fail_as "$generic"
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
if [ "$account_plugin" = true ]; then printf '%s\n' '{"stage":"chat-keeping"}' >"$state_root/setup-progress.json"; fi

if [ -f "$state_root/memory-note-warning.txt" ]; then cat "$state_root/memory-note-warning.txt"; fi
finished=true
printf '%s\n' "MINDY TimeSaver is now $(folder_place)."
if [ "${account_plugin:-false}" = true ]; then
 printf '%s\n' "Switch the mode at the bottom of the window back to Auto. Open Customize, then Plugins, then Discover, and add MINDY TimeSaver. The next step needs a new session: start one and type /install-mts to continue."
else
 print_welcome
fi

if [ "${from_chat:-false}" = true ] && [ "$account_plugin" = false ]; then printf "MTS_HOST_UI=%s\n" "$(host_ui)"; fi
