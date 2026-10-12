#!/bin/sh
set -eu

# How a member starts MINDY, in every message below that says so: /install-bwm in Claude Code, and /install-bwm in
# the ChatGPT app, where MINDY members use Codex. Both forms are written here and nowhere else in this
# script, so a different form is one edit. The /install-bwm skill repeats the no-code message in both forms,
# and a test holds them the same.
#
# Claude Code marks the commands it runs with CLAUDECODE. The ChatGPT app starts Codex with
# CODEX_INTERNAL_ORIGINATOR_OVERRIDE (the app's name for itself) and CODEX_CLI_PATH (its own copy of
# codex), and Codex marks the commands it runs with CODEX_THREAD_ID, or CODEX_SANDBOX and
# CODEX_SANDBOX_NETWORK_DISABLED when it runs them in its sandbox. Members use Codex only in the
# ChatGPT app, so any of the Codex marks means the app.
start_mindy_in_claude_code='type /install-bwm'
start_mindy_in_the_chatgpt_app='type /install-bwm'
start_mindy=$start_mindy_in_claude_code
if [ -z "${CLAUDECODE:-}" ] && [ -n "${CODEX_INTERNAL_ORIGINATOR_OVERRIDE:-}${CODEX_CLI_PATH:-}${CODEX_THREAD_ID:-}${CODEX_SANDBOX:-}${CODEX_SANDBOX_NETWORK_DISABLED:-}" ]; then
	start_mindy=$start_mindy_in_the_chatgpt_app
fi
start_mindy_capital="$(printf '%s' "$start_mindy" | cut -c 1 | tr '[:lower:]' '[:upper:]')$(printf '%s' "$start_mindy" | cut -c 2-)"

# The decided wording (2 October 2026). The member sees exactly one of these when setup stops, and no
# other words. "MINDY has already been sent the details" is printed only when MINDY's download server
# took the stop report; otherwise the unreachable message or the not-taken ending is printed instead.
no_code_message="This needs your MINDY access code, which came in the message with your install steps. $start_mindy_capital, a space and your code, all on one line."
not_issued_message="This is not a MINDY access code, so setup can't use it. Copy the code again in full from the message it came in, then $start_mindy with it."
not_active_message="This MINDY access code is no longer active, so it can't download MINDY. MINDY has sent Mike the details."
different_code_message="This Mac already has a different MINDY access code saved, and MINDY uses one code per Mac. $start_mindy_capital with that earlier code. MINDY has already been sent the details, in case you no longer have it."
unsigned_message="This download is not a signed MINDY release, so setup stopped before installing anything, to keep your Mac safe. MINDY has sent Mike the details. Check you're on your usual internet connection, then $start_mindy with your access code again."
too_many_message="Too many tries from this internet connection in the last minute, so MINDY's download server is pausing for a moment. Wait a minute, then $start_mindy with your access code again."
unreachable_message="Setup could not reach MINDY's download server, so MINDY could not be sent the details. Check you are online, then $start_mindy with your access code again."
# Any other stop is "Setup stopped while <step>: <reason>." and one of these two endings.
details_sent_ending="MINDY has sent Mike the details. $start_mindy_capital with your access code to try again."
details_not_taken_ending="MINDY could not send Mike the details. Check you are online, then $start_mindy with your access code to try again."
interrupted_message="Setup stopped because it was interrupted. $start_mindy_capital with your access code to start again."

# The <reason> in "Setup stopped while saving your access code on this Mac: <reason>." for each case
# the engine names when saving the code stops (mindy-install/delivery-credential-cli.ts,
# AccessCodeStopCase). The engine's own code and detail go only to the stop note and the stop report.
# A case not listed here, and an engine from before the cases, gets reason_kept below instead.
# access_code_reason <case>
access_code_reason() {
	case "$1" in
		keychain-out-of-reach-and-file-not-written) printf '%s\n' "this Mac's password store did not take your code, and the private file for your code could not be written either" ;;
		saved-code-file-not-private) printf '%s\n' "the file that holds your code on this Mac is not private to your Mac account, so setup will not use it" ;;
		saved-code-unreadable) printf '%s\n' "the access code already saved on this Mac could not be read back" ;;
		setup-record-not-written) printf '%s\n' "setup could not write its record of your code in your MINDY folder" ;;
		setup-record-unreadable) printf '%s\n' "setup could not read its record of your code in your MINDY folder" ;;
	esac
}

code_from_chat_message="Setup could not read your code from this chat. Start a new chat and type /install-bwm with your code there."
chat_reader_repair_message="MINDY TimeSaver needs repairing. Install MINDY TimeSaver again with /install-mts and your TimeSaver access code, then $start_mindy with your code again."

memory_first_message='Install MINDY TimeSaver first. Add MINDY TimeSaver Setup where you add plugins, and type /install-mts with your access code. When it has finished, type /install-bwm with your code again.'
case "${CODEX_INTERNAL_ORIGINATOR_OVERRIDE:-}" in
 *ChatGPT*) memory_first_message='Install MINDY TimeSaver first. Open Customize, then Plugins, then Personal, click + beside MINDY TimeSaver Setup, and type /install-mts with your access code. When it has finished, type /install-bwm with your code again.' ;;
 *) if [ "${MINDY_CLAUDE_LOCAL:-}" = 1 ]; then
  memory_first_message='Install MINDY TimeSaver first. On the speech-bubble side of the Claude app, open Customize, then Plugins, then Discover, add MINDY TimeSaver Setup, and type /install-mts with your access code on the Local Code side. When it has finished, type /install-bwm with your code again.'
 else
  for setup_option in "$@"; do
   if [ "$setup_option" = --claude-local ]; then
    memory_first_message='Install MINDY TimeSaver first. On the speech-bubble side of the Claude app, open Customize, then Plugins, then Discover, add MINDY TimeSaver Setup, and type /install-mts with your access code on the Local Code side. When it has finished, type /install-bwm with your code again.'
   fi
  done
 fi ;;
esac

# These guards also protect a direct invocation, before any temporary folder, report or network call.
# The stdin route remains for the internal installer tests and update caller, never for an AI tool.
if [ -n "${HOME:-}" ]; then
 capture_registered=false
 for registration in "${HOME:-}/Library/Application Support/MINDY/memories/"*.json; do
  if [ -f "$registration" ] && [ ! -L "$registration" ] && grep -q '"role"[[:space:]]*:[[:space:]]*"capture"' "$registration"; then capture_registered=true; break; fi
 done
 [ "$capture_registered" = true ] || { printf '%s\n' "$memory_first_message"; exit 0; }
fi
if [ "$#" -eq 0 ]; then
 installed_root="${HOME:-}/mindy"
 install_record="${HOME:-}/.mindy/install-state.json"
 if [ -f "$install_record" ] && [ ! -L "$install_record" ] && grep -q '"format"[[:space:]]*:[[:space:]]*"mindy.delivery-install-state.v1"' "$install_record"; then
  recorded_root=$(sed -n 's/.*"baseRoot"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$install_record" | head -n 1)
  case "$recorded_root" in /*) installed_root=$recorded_root ;; esac
 fi
 installed_active="$installed_root/.mindy/release-selection/active-release.json"
 if [ -f "$installed_active" ] && [ ! -L "$installed_active" ] && grep -q '"version"[[:space:]]*:[[:space:]]*"[^"]\{1,\}"' "$installed_active"; then
  printf '%s\n' 'MINDY is already installed.'; exit 0
 fi
fi

# Locate only this host's current session, as mindysave does. The reader writes its answer
# into this shell's private command substitution, never the tool's output or a temporary file.
code_from_current_chat() {
 chat_bun="${MTS_STATE_ROOT:-${HOME:-}/.timesaver}/bin/bun"
 if [ -f "$chat_bun" ] && [ ! -L "$chat_bun" ] && [ -x "$chat_bun" ] && BUN_RUNTIME_TRANSPILER_CACHE_PATH=0 "$chat_bun" -e 'process.exit(0)' >/dev/null 2>&1; then
  chat_native=false
  set -- "$chat_bun" - "$@"
 elif [ -x /usr/bin/osascript ] && /usr/bin/osascript -l JavaScript -e '1' >/dev/null 2>&1; then
  chat_native=true
  set -- /usr/bin/osascript -l JavaScript - "$@"
 else
  return 3
 fi
 run_chat_reader() {
 # Reading a chat must not leave Bun's compiled source cache in the person's home.
 BUN_RUNTIME_TRANSPILER_CACHE_PATH=0 "$@" 2>/dev/null <<'BWM_CURRENT_CHAT'
// One reader for Bun and macOS JavaScript for Automation, with no downloaded code.
var nativeReader = typeof process === "undefined";
if (nativeReader) ObjC.import("Foundation");
function run(options) {
 var fs = nativeReader ? null : require("node:fs");
 var fm = nativeReader ? $.NSFileManager.defaultManager : null;
 function env(name) {
  if (!nativeReader) return process.env[name] || "";
  var value = $.NSProcessInfo.processInfo.environment.objectForKey(name);
  return value.isNil() ? "" : ObjC.unwrap(value);
 }
 function attributes(file) {
  var info = fm.attributesOfItemAtPathError(file, null);
  if (info.isNil()) throw new Error();
  return info;
 }
 function directory(file) {
  try { return nativeReader ? ObjC.unwrap(attributes(file).objectForKey($.NSFileType)) === "NSFileTypeDirectory" : fs.lstatSync(file).isDirectory(); }
  catch (_) { return false; }
 }
 function children(folder) {
  if (!directory(folder)) return [];
  var names = nativeReader ? ObjC.deepUnwrap(fm.contentsOfDirectoryAtPathError(folder, null)) : fs.readdirSync(folder);
  return names.map(function(name) { return folder + "/" + name; });
 }
 function regular(file) {
  if (nativeReader) {
   var info = attributes(file);
   if (ObjC.unwrap(info.objectForKey($.NSFileType)) !== "NSFileTypeRegular" || !(Number(ObjC.unwrap(info.objectForKey($.NSFilePosixPermissions))) & 0o444)) throw new Error();
  } else {
   var stat = fs.lstatSync(file);
   if (!stat.isFile() || !(stat.mode & 0o444)) throw new Error();
  }
 }
 // The compatibility scan opens at most 100 metadata rows, each capped at 64 KiB.
 function read(file, maximum) {
  regular(file);
  if (nativeReader) {
   if (!maximum) {
    var value = $.NSString.stringWithContentsOfFileEncodingError(file, $.NSUTF8StringEncoding, null);
    if (value.isNil()) throw new Error();
    return ObjC.unwrap(value);
   }
   var handle = $.NSFileHandle.fileHandleForReadingAtPath(file);
   if (handle.isNil()) throw new Error();
   try {
    var bytes = handle.readDataOfLength(maximum);
    var plain = ObjC.unwrap($.NSString.alloc.initWithDataEncoding(bytes, $.NSISOLatin1StringEncoding));
    var newline = plain.indexOf("\n");
    if (newline < 0 && plain.length === maximum) throw new Error();
    var first = newline < 0 ? bytes : bytes.subdataWithRange($.NSMakeRange(0, newline));
    var decoded = $.NSString.alloc.initWithDataEncoding(first, $.NSUTF8StringEncoding);
    if (decoded.isNil()) throw new Error();
    return ObjC.unwrap(decoded);
   } finally { handle.closeFile; }
  }
  if (!maximum) return fs.readFileSync(file, "utf8");
  var fd = fs.openSync(file, "r");
  try {
   var buffer = Buffer.alloc(maximum), length = fs.readSync(fd, buffer, 0, maximum, null);
   var end = buffer.subarray(0, length).indexOf(10);
   if (end < 0 && length === maximum) throw new Error();
   return buffer.subarray(0, end < 0 ? length : end).toString("utf8");
  } finally { fs.closeSync(fd); }
 }
 function records(file) {
  return read(file).split(/\r?\n/).filter(function(line) { return line.trim(); }).map(function(line) {
   var row = JSON.parse(line);
   if (!row || typeof row !== "object" || Array.isArray(row)) throw new Error();
   return row;
  });
 }
 function text(content) {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content.filter(function(block) { return block && ["text", "input_text"].indexOf(block.type) >= 0 && typeof block.text === "string"; }).map(function(block) { return block.text; }).join("\n");
 }
 function sessionFiles(folder) {
  var files = [];
  children(folder).forEach(function(file) {
   if (directory(file)) files = files.concat(sessionFiles(file));
   else if (/\.jsonl$/.test(file)) files.push(file);
  });
  return files;
 }
 try {
  var explicit;
  for (var i = 0; i < options.length; i++) {
   if (options[i] === "--session-id" && !explicit) explicit = options[++i];
   else if (options[i] !== "--claude-local") throw new Error();
  }
  var claude = !!(env("CLAUDECODE") || env("CLAUDE_CODE_SESSION_ID") || env("CLAUDE_SESSION_ID"));
  var session = explicit || (claude ? env("CLAUDE_CODE_SESSION_ID") || env("CLAUDE_SESSION_ID") : env("CODEX_THREAD_ID") || env("CODEX_SESSION_ID"));
  if (!session || !/^[A-Za-z0-9_-]+$/.test(session)) throw new Error();
  var files, rows, messages;
  if (claude) {
   var projects = (env("CLAUDE_CONFIG_DIR") || env("HOME") + "/.claude") + "/projects";
   files = children(projects).filter(directory).map(function(folder) { return folder + "/" + session + ".jsonl"; }).filter(function(file) {
    return nativeReader ? fm.fileExistsAtPath(file) : fs.existsSync(file);
   });
   if (files.length !== 1) throw new Error();
   rows = records(files[0]);
   if (!rows.some(function(row) { return row.sessionId === session && row.message && typeof row.message.role === "string"; })) throw new Error();
   // A resumed file can retain earlier session rows. They cannot supply this session's code.
   messages = rows.filter(function(row) { return row.sessionId === session && row.message && row.message.role === "user"; }).map(function(row) { return row.message; });
  } else {
   var codex = env("CODEX_HOME") || env("HOME") + "/.codex";
   if (codex.charAt(0) !== "/") throw new Error();
   var all = sessionFiles(codex + "/sessions");
   files = all.filter(function(file) {
    var name = file.slice(file.lastIndexOf("/") + 1);
    return name.indexOf("rollout-") === 0 && name.slice(-session.length - 7) === "-" + session + ".jsonl";
   });
   if (!files.length) {
    all.sort().reverse().slice(0, 100).forEach(function(file) {
     try {
      var first = JSON.parse(read(file, 65536));
      if (first.type === "session_meta" && first.payload && first.payload.id === session) files.push(file);
     } catch (_) { /* Another chat's incomplete metadata cannot supply this chat's code. */ }
    });
   }
   if (files.length !== 1) throw new Error();
   rows = records(files[0]);
   var metas = rows.filter(function(row) { return row.type === "session_meta"; });
   if (metas.length !== 1 || !metas[0].payload || metas[0].payload.id !== session || rows[0] !== metas[0]) throw new Error();
   messages = rows.filter(function(row) { return row.type === "response_item" && row.payload && row.payload.type === "message" && row.payload.role === "user"; }).map(function(row) { return row.payload; });
  }
  var latest = "";
  var command = /^(?:\/(?:[A-Za-z0-9_-]+:)?install-bwm(?:\s|$)|\[\$?(?:[A-Za-z0-9_-]+:)?install-bwm\]\([^\n]*?\/install-bwm\/SKILL\.md\)(?:\s|$))|<command-name>\/(?:[A-Za-z0-9_-]+:)?install-bwm<\/command-name>/;
  messages.forEach(function(message) {
   var value = text(message.content).trim(), found = "", match;
   var pattern = /(^|[^A-Za-z0-9_.-])([A-Za-z0-9-]{3,32}\.[A-Za-z0-9_-]{86})(?=\.*(?:[^A-Za-z0-9_.-]|$))/g;
   while ((match = pattern.exec(value))) found = match[2];
   if (found) latest = found;
   // A new install invocation without a code must not silently reuse an earlier one.
   else if (command.test(value)) latest = "";
  });
  return latest || "BWM_CHAT_NO_CODE";
 } catch (_) { return "BWM_CHAT_UNREADABLE"; }
}
if (!nativeReader) process.stdout.write(run(process.argv.slice(2)));
BWM_CURRENT_CHAT
 }
 if chat_answer=$(run_chat_reader "$@") && [ -n "$chat_answer" ]; then :
 elif [ "$chat_native" = false ]; then
  # A damaged runtime can pass its probe and still fail to run the stdin reader.
  shift 2
  [ -x /usr/bin/osascript ] && /usr/bin/osascript -l JavaScript -e '1' >/dev/null 2>&1 || return 3
  chat_answer=$(run_chat_reader /usr/bin/osascript -l JavaScript - "$@") || return 3
 else
  return 3
 fi
 case "$chat_answer" in
  BWM_CHAT_NO_CODE) return 2 ;;
  BWM_CHAT_UNREADABLE) return 1 ;;
  '') return 3 ;;
  *) printf '%s' "$chat_answer" ;;
 esac
}

# The AI calls only --code-from-chat. It never supplies the secret in command text or tool stdin.
code=
if [ "${1:-}" = "--code-on-stdin" ]; then code=$(sed -n '1p' | tr -d ' \t\r') || code=
elif [ "${1:-}" = "--code-from-chat" ]; then
 shift
 chat_status=0
 code=$(code_from_current_chat "$@") || chat_status=$?
 # The app may not have written the message or finished its JSON row yet.
 if [ "$chat_status" = 1 ] || [ "$chat_status" = 2 ]; then
  sleep 0.2
  chat_status=0
  code=$(code_from_current_chat "$@") || chat_status=$?
 fi
 case "$chat_status" in
  0) ;;
  2) printf '%s\n' "$no_code_message"; exit 0 ;;
  3) printf '%s\n' "$chat_reader_repair_message"; exit 0 ;;
  *) printf '%s\n' "$code_from_chat_message"; exit 0 ;;
 esac
fi
if [ -z "$code" ]; then printf '%s\n' "$no_code_message"; exit 0; fi
# Only the identified Local Code skill route enables records without the CLI.
for setup_option in "$@"; do
 if [ "$setup_option" = --claude-local ]; then MINDY_CLAUDE_LOCAL=1; export MINDY_CLAUDE_LOCAL; fi
done
exec 2>/dev/null

# The code is a secret. Everything this script prints or keeps goes through redact, which replaces
# the whole code, and its signature half on its own, with [code removed]. Either one shorter than 16
# characters is left alone: a real code is far longer, and its signature half alone is 86 characters,
# so a mistyped scrap, or an ordinary word typed as the code, cannot garble the sentences. A code is
# found even when something that shows nothing has been put inside it (a zero-width space or joiner, a
# soft hyphen, a direction mark, a byte order mark and the like), when it was hard-wrapped across
# lines, with the line break (a Windows one too), and any spaces beside it, inside the code, or when
# the code as typed holds such marks itself. Those are the only things redact looks for: unlike the
# Mac-side utility that sends a mindysetup stop, it has no rule for something merely shaped like a code,
# for a bare run of signature characters, or for a Bearer token.
code_signature=${code##*.}
[ "$code_signature" != "$code" ] || code_signature=
# The marks that show nothing, as the bytes of their UTF-8, one pattern of alternatives, the same
# marks as mysetup-stop-report.ts: U+00AD, U+034F, U+061C, U+115F and U+1160, U+17B4 and U+17B5,
# U+180B to U+180F, U+200B to U+200F, U+202A to U+202E, U+2060 to U+206F, U+2800, U+3164, U+FE00 to
# U+FE0F, U+FEFF, U+FFA0, U+FFF9 to U+FFFB, U+1D173 to U+1D17A and the tag characters U+E0000 to U+E007F.
invisible_marks=$(printf '\302\255|\315\217|\330\234|\341\205[\237\240]|\341\236[\264\265]|\341\240[\213-\217]|\342\200[\213-\217]|\342\200[\252-\256]|\342\201[\240-\257]|\342\240\200|\343\205\244|\357\270[\200-\217]|\357\273\277|\357\276\240|\357\277[\271-\273]|\360\235\205[\263-\272]|\363\240\200[\200-\277]|\363\240\201[\200-\277]')
# Standard input with the code taken out, a few lines at a time: a code can only be spread over a few
# lines, so each hundred lines are searched together with the last lines of the hundred before, which
# are held back until then. The held-back lines are enough to hold more than the whole code, so a code
# is never cut between two searches, and the cost grows with the length of the input, not with its
# square. When no code long enough is given, the input passes through as it is.
redact() {
	MINDY_SETUP_REDACT_CODE=$code MINDY_SETUP_REDACT_SIGNATURE=$code_signature MINDY_SETUP_INVISIBLE=$invisible_marks LC_ALL=C awk '
		# A character as plain text inside a pattern.
		function plain(c) { return index("\\^$.[]|()*+?{}", c) ? "\\" c : c }
		# A pattern for the secret with, between each two of its characters, anything that may have been
		# put there: a mark that shows nothing, or a line break with the spaces beside it.
		function wrapped(secret,    re, i, n) {
			re = ""; n = length(secret)
			for (i = 1; i <= n; i++) re = re plain(substr(secret, i, 1)) (i < n ? gap : "")
			return re
		}
		# The held lines with the code taken out. Unless this is the end, all but the last lines are
		# printed, and the last lines stay held: at least `quota` characters that are not spaces, so
		# that a code which starts before them and goes on in the lines still to come is still whole
		# in what is held, and at most 400 lines.
		function flush(final,    k, out, n, lines, start, count, piece, i) {
			for (k = 1; k <= 2; k++) {
				if (pattern[k] == "") continue
				out = ""
				while (match(text, pattern[k]) > 0) { out = out substr(text, 1, RSTART - 1) "[code removed]"; text = substr(text, RSTART + RLENGTH) }
				text = out text
			}
			if (final) { print text; held = 0; return }
			if (text == "") { n = 1; lines[1] = "" } else n = split(text, lines, "\n")
			start = n + 1; count = 0
			while (start > 1 && n - start < 400 && count < quota) {
				start--; piece = lines[start]; gsub(/[ \t\r]/, "", piece); count += length(piece)
			}
			text = ""
			for (i = 1; i < start; i++) print lines[i]
			for (i = start; i <= n; i++) text = text (i > start ? "\n" : "") lines[i]
			held = n - start + 1; fresh = 0
		}
		BEGIN {
			secrets[1] = ENVIRON["MINDY_SETUP_REDACT_CODE"]; secrets[2] = ENVIRON["MINDY_SETUP_REDACT_SIGNATURE"]
			gap = "(" ENVIRON["MINDY_SETUP_INVISIBLE"] "|[ \t\r]*\n[ \t\r]*)*"
			longest = 0
			for (k = 1; k <= 2; k++) {
				# A code typed with such a mark inside it is looked for without it, as the text it is in is.
				gsub(ENVIRON["MINDY_SETUP_INVISIBLE"], "", secrets[k])
				if (length(secrets[k]) >= 16) { pattern[k] = wrapped(secrets[k]); active = 1; if (length(secrets[k]) > longest) longest = length(secrets[k]) }
			}
			quota = 4 * longest + 64
		}
		!active { print; next }
		{ text = (held ? text "\n" : "") $0; held++; if (++fresh >= 100) flush(0) }
		END { if (active && held) flush(1) }'
}
say() { printf '%s\n' "$1" | redact; }
# curl to MINDY's download server, with the code's Authorization header read from a here-document on
# descriptor 3 rather than given as an argument, so the process list never shows the code.
# gate_curl <curl arguments>
gate_curl() {
	curl -H @/dev/fd/3 "$@" 3<<GATE_AUTHORIZATION
Authorization: Bearer $code
GATE_AUTHORIZATION
}
# The first line of a reason worth reading: not blank, not a numbered source excerpt, not a caret,
# not a banner of repeated = - * # ~ or _. A Bun crash report opens with a banner and a block about
# the machine, so its panic line, when there is one, is the reason.
first_meaningful() {
	redact | awk '
		{ gsub(/[[:cntrl:]]/, " ") }
		/^[[:space:]]*$/ { next }
		/^[[:space:]]*[0-9]+[[:space:]]*\|/ { next }
		/^[[:space:]]*\^[[:space:]]*$/ { next }
		/^[[:space:]]*[=*#~_-][=*#~_-][=*#~_-]+[[:space:]]*$/ { next }
		{ line = $0; sub(/^[[:space:]]+/, "", line); sub(/[[:space:]]+$/, "", line); if (length(line) > 300) line = substr(line, 1, 297) "..." }
		line ~ /^panic[(:]/ { print line; found = 1; exit }
		first == "" { first = line }
		END { if (!found && first != "") print first }'
}
reason_of() {
	for reason_file in "$@"; do
		if [ -f "$reason_file" ]; then
			reason_line=$(first_meaningful <"$reason_file")
			if [ -n "$reason_line" ]; then printf '%s\n' "$reason_line"; return 0; fi
		fi
	done
	return 0
}

plugin_root="$(dirname "$0")/.."
tmp=
home=
version_dir=
created_version_dir=false
archive=
finished=false
said=false
told=false
kept=false
signal=
step='starting setup'
stop_message=
stop_reason=
member_reason=
withhold_reason=false
stop_status=
stop_file=
stop_stamp=
report_id=
keep_failure=
send_outcome=
member_names=
version=
active_version=
harness_list=
harnesses_checked=false
# What a stop shows in place of a reason it must not show. Not yet decided.
reason_kept="the reason is kept in setup's stop note on this Mac, in ~/.mindy/setup-stops"
reason_not_shown='the reason is not shown here'
# The gate's own sentences (build-machine-stack src/mindy-gate-rules.js), matched exactly and never
# relayed: the earlier words, and the words the gate uses since it took the decided wording. The
# Old gate replies are compared only. The client shows its own setup sentences.
gate_not_issued_sentence='This code is not one Mike issued. Check the code in Mike'"'"'s message, or ask Mike.'
gate_not_active_sentence='This code is no longer active. Ask Mike.'
gate_too_many_sentence='Too many requests. Wait a minute and try again.'
gate_not_issued_sentence_now="This is not a MINDY access code, so setup can't use it. Copy the code again in full from the message it came in, then type /install-bwm with it."
gate_not_active_sentence_now="This MINDY access code is no longer active, so it can't download MINDY."
gate_too_many_sentence_now="Too many tries from this internet connection in the last minute, so MINDY's download server is pausing for a moment. Wait a minute, then type /install-bwm with your access code again."
# The engine's own sentences for a different code already on this Mac: release 1.0.7 and later, and
# release 1.0.6.
engine_different_code_sentence='This Mac already has a different MINDY access code.'
engine_different_code_sentence_before='This machine already has a different code. Ask Mike.'

# Whether the text is one of the gate's sentences, in its earlier or its current words.
# is_gate_not_issued <text>, is_gate_not_active <text>, is_gate_too_many <text>
is_gate_not_issued() { [ "$1" = "$gate_not_issued_sentence" ] || [ "$1" = "$gate_not_issued_sentence_now" ]; }
is_gate_not_active() { [ "$1" = "$gate_not_active_sentence" ] || [ "$1" = "$gate_not_active_sentence_now" ]; }
is_gate_too_many() { [ "$1" = "$gate_too_many_sentence" ] || [ "$1" = "$gate_too_many_sentence_now" ]; }

# A reason as the end of a sentence: with a full stop, unless it already ends with one.
as_sentence() {
	case "$1" in *.) printf '%s' "$1" ;; *) printf '%s.' "$1" ;; esac
}

# Each step names itself before it starts, and its own error output goes to step.err, so an
# unexpected exit under set -eu can say which step stopped and what the failed command said.
begin() {
	step=$1
	if [ -n "$tmp" ]; then exec 2>"$tmp/step.err"; fi
}

# A name or path as a web address writes it, for the awk programs below: each byte that is not a
# letter, a digit, a slash or one of . _ ~ - as %xx, in lower case, as those programs compare in lower
# case. A file address writes a space as %20, and a letter such as the e in Jose with an accent as %xx
# for each byte of it. Add percent_setup() to BEGIN, then call percent_encode(<text>).
percent_functions='
	function percent_setup(    i) { for (i = 1; i < 256; i++) percent_ord[sprintf("%c", i)] = i }
	function percent_encode(text,    out, i, c) {
		out = ""
		for (i = 1; i <= length(text); i++) {
			c = substr(text, i, 1)
			out = out (c ~ /[A-Za-z0-9\/._~-]/ ? c : sprintf("%%%02x", percent_ord[c]))
		}
		return out
	}'

# The member's own home folder path, set aside as plain text in any letter case, as a Mac's folders
# ignore case, and only as a whole path part: where a slash, a space, a quote, punctuation that closes
# a path, or the end of the line follows it. A longer folder name that begins with it is left as it is.
# The path is also found as a file address writes it, with %20 for each space and %xx for other
# characters.
# set_home_aside <what stands in its place>
set_home_aside() {
	MINDY_SETUP_HOME=$home MINDY_SETUP_HOME_AS=$1 LC_ALL=C awk "$percent_functions"'
		BEGIN {
			percent_setup()
			home = tolower(ENVIRON["MINDY_SETUP_HOME"]); as = ENVIRON["MINDY_SETUP_HOME_AS"]; sub(/\/+$/, "", home)
			if (home != "") {
				spelled[++spellings] = home
				for (i = 1; i <= 2; i++) {
					other = i == 1 ? home : percent_encode(home)
					if (i == 1) gsub(/ /, "%20", other)
					for (j = 1; j <= spellings && other != spelled[j]; j++);
					if (j > spellings) spelled[++spellings] = other
				}
			}
		}
		{
			line = $0
			for (k = 1; k <= spellings; k++) {
				home = spelled[k]; out = ""
				while ((at = index(tolower(line), home)) > 0) {
					after = substr(line, at + length(home), 1)
					if (after == "" || after == "\047" || after ~ /[]\/[:space:]":;,)>`}]/) { out = out substr(line, 1, at - 1) as; line = substr(line, at + length(home)) }
					else { out = out substr(line, 1, at); line = substr(line, at + 1) }
				}
				line = out line
			}
			print line
		}'
}

# One check for every word a stop shows that someone else wrote: a tool's output, the engine's
# answer, a page that answered in place of the download server, or why the stop note could not be
# kept. The name the gate's sentences use must never reach the screen, in any letter case. The check
# reads the text as it would be shown, with the code already removed, and with the member's own home
# folder path taken out, compared as plain text: that folder name is the member's own and names no
# one else. The home path is taken out only as a whole path part, so a longer folder name that begins
# with it is still checked. What is shown is unchanged.
# must_not_show <text>
must_not_show() {
	printf '%s\n' "$1" | redact | set_home_aside ' ' | awk '
		{
			line = $0
			if (tolower(line) ~ /mike/) found = 1
		}
		END { exit (found ? 0 : 1) }'
}

# The member's names on this Mac, each replaced with [name removed] wherever it stands as a whole
# word, in any letter case: their full name, each word of it of three letters or more, and their user
# name. The longest is removed first, so a user name that is also the first word of the full name
# never leaves the rest of the full name behind. A full name or user name shorter than two characters
# is left alone, as it could not be told from an ordinary letter.
without_names() {
	MINDY_SETUP_NAMES=$member_names LC_ALL=C awk "$percent_functions"'
		function add(name, k) {
			for (k = 1; k <= count; k++) if (names[k] == name) return
			names[++count] = name
		}
		BEGIN {
			percent_setup()
			split(ENVIRON["MINDY_SETUP_NAMES"], list, "\n")
			user = tolower(list[1]); full = tolower(list[2])
			if (length(full) >= 2) add(full)
			words = split(full, part, /[[:space:]]+/)
			for (i = 1; i <= words; i++) if (length(part[i]) >= 3) add(part[i])
			if (length(user) >= 2) add(user)
			# Each name as a file address writes it as well: %20 for a space, and %xx for other characters.
			found = count
			for (i = 1; i <= found; i++) {
				other = names[i]; gsub(/ /, "%20", other); add(other)
				add(percent_encode(names[i]))
			}
			for (i = 2; i <= count; i++) {
				name = names[i]
				for (j = i - 1; j >= 1 && length(names[j]) < length(name); j--) names[j + 1] = names[j]
				names[j + 1] = name
			}
		}
		{
			line = $0
			for (k = 1; k <= count; k++) {
				name = names[k]; size = length(name); out = ""
				while ((at = index(tolower(line), name)) > 0) {
					before = at > 1 ? substr(line, at - 1, 1) : substr(out, length(out), 1)
					after = substr(line, at + size, 1)
					if (before !~ /[A-Za-z0-9_]/ && after !~ /[A-Za-z0-9_]/) { out = out substr(line, 1, at - 1) "[name removed]"; line = substr(line, at + size) }
					else { out = out substr(line, 1, at); line = substr(line, at + 1) }
				}
				line = out line
			}
			print line
		}'
}

# Text from standard input with the marks that show nothing taken out (invisible_marks above), so they
# cannot hide a name, a path or a code in what leaves this Mac.
without_invisible() {
	MINDY_SETUP_INVISIBLE=$invisible_marks LC_ALL=C awk '{ gsub(ENVIRON["MINDY_SETUP_INVISIBLE"], ""); print }'
}

# Text from standard input as it is kept before anything is looked for in it: a Windows line end is
# one newline and a lone carriage return is a newline, any broken UTF-8 (a byte that is not text, or
# a mark cut off at its end) is dropped, and control characters other than tab and newline are
# dropped. All of that happens before redact, never after it, because taking a stray byte out of the
# middle of a code afterwards would join the code back together once redact had passed over it.
# plain_text
plain_text() {
	LC_ALL=C sed -e "s/$(printf '\r')\$//" | LC_ALL=C tr '\r' '\n' \
		| if command -v iconv >/dev/null 2>&1; then iconv -c -f UTF-8 -t UTF-8 2>/dev/null; else cat; fi \
		| LC_ALL=C tr -d '\000-\010\013-\037\177'
}

# Text that is about to leave this Mac: made plain text, the marks that show nothing dropped, the code
# and its signature half removed, the member's home folder path replaced with ~, and their names
# removed.
for_sending() {
	plain_text | without_invisible | redact | set_home_aside '~' | without_names
}

# What for_sending gave, as the inside of a JSON string, at most <bytes> bytes before it is escaped:
# any broken UTF-8 at the cut dropped, then \ " tab and newline escaped. Each field's bytes are capped
# so that the whole report stays inside the download server's 131072 bytes even if every byte had to
# be escaped.
# json_escaped <bytes>
json_escaped() {
	head -c "$1" | if command -v iconv >/dev/null 2>&1; then iconv -c -f UTF-8 -t UTF-8 2>/dev/null; else cat; fi \
		| LC_ALL=C sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e "s/$(printf '\t')/\\\\t/g" \
		| LC_ALL=C awk '{ printf "%s%s", (NR > 1 ? "\\n" : ""), $0 }'
}

# Text read from standard input as the inside of a JSON string: what must not leave this Mac taken
# out first (for_sending), then cut and escaped (json_escaped).
# json_text <bytes>
json_text() {
	for_sending | json_escaped "$1"
}

# One line of text as the inside of a JSON string, its line breaks made spaces. What must not leave
# this Mac is taken out before the line breaks become spaces, so a code wrapped across lines is still
# found.
# json_line <text> <bytes>
json_line() {
	printf '%s' "$1" | for_sending | LC_ALL=C awk '{ printf "%s%s", (NR > 1 ? " " : ""), $0 }' | json_escaped "$2"
}

# Which app is running setup, by the same marks as start_mindy at the top: Claude Code, or Codex, which
# for a member is Codex in the ChatGPT app. The download server reads "Codex" for both.
app_name() {
	if [ -n "${CLAUDECODE:-}" ]; then printf '%s\n' 'Claude Code'
	elif [ -n "${CODEX_INTERNAL_ORIGINATOR_OVERRIDE:-}${CODEX_CLI_PATH:-}${CODEX_THREAD_ID:-}${CODEX_SANDBOX:-}${CODEX_SANDBOX_NETWORK_DISABLED:-}" ]; then printf '%s\n' 'Codex'
	else printf '%s\n' 'not known'; fi
}

# The time a stop happened, once per stop, and the report id made from it: the stop note's file stamp
# and this run's process id, the same for every send of this stop and new for the next stop.
stop_time() {
	[ -z "$stop_stamp" ] || return 0
	stop_stamp=$(date -u +%Y-%m-%dT%H:%M:%SZ) || stop_stamp=unknown-time
	report_id="$(printf '%s\n' "$stop_stamp" | tr ':' '-')-$$"
}

# Sends the stop's details to MINDY's download server, as build-machine-stack's
# src/mindy-setup-stop-rules.js reads them (report mindy-setup-stop/v1), with the whole code as the
# proof the sender holds it, exactly as the release list is asked for. Only the code's membership
# number, the part before the dot, is in the report itself. The member's home folder path, their
# names and the code never leave this Mac in the report: step, reason and stop note go through
# for_sending first. Call it only as a condition (if send_stop_report), so that set -e leaves its
# failures to it. It returns:
#   0 the server took the report: a 2xx answer whose body says "received": true, as the gate's
#     answer for a new stop (201) and for one it already had (200) both do (build-machine-stack
#     src/api/mindy-setup-stops.js)
#   1 something answered without taking it: any other status, or a 2xx without that body, such as a
#     filtering proxy or a Wi-Fi sign-in page answering in the server's place
#   2 the server was not reached: curl stopped, or there was no answer (status 000)
#   3 the code is not a MINDY access code: it has no membership number to send, or the route answered
#     403, which it gives only for a code it never issued, whatever the words of its refusal
# Whatever it returns, send_outcome says what came of it, for the note.
send_stop_report() {
	membership_number=${code%.*}
	case "$membership_number" in
		''|*[!A-Za-z0-9-]*) send_outcome='no, the access code has no membership number'; return 3 ;;
	esac
	if [ "$membership_number" = "$code" ] || [ "${#membership_number}" -lt 3 ] || [ "${#membership_number}" -gt 32 ]; then
		send_outcome='no, the access code has no membership number'
		return 3
	fi
	member_names=$(printf '%s\n%s\n' "$(id -un 2>/dev/null || :)" "$(id -F 2>/dev/null || :)")
	stop_time
	report_step=$(json_line "$step" 200)
	report_reason=$(json_line "$stop_reason" 2000)
	report_note=
	# The note, or, when it could not be kept, why not, as the member is not told.
	if [ "$note_kept" = true ] && [ -f "$stop_file" ]; then report_note=$(json_text 60000 <"$stop_file")
	elif [ -n "$keep_failure" ]; then report_note=$(json_line "The stop note could not be kept on this Mac: $keep_failure" 2000); fi
	report_app=$(app_name)
	report_mindy_version=$(json_line "$version" 64)
	report_macos_version=$(json_line "$(sw_vers -productVersion 2>/dev/null || :)" 64)
	send_answer=$(printf '{"report":"mindy-setup-stop/v1","reportId":"%s","membershipNumber":"%s","step":"%s","reason":"%s","stopNote":"%s","app":"%s","mindyVersion":"%s","macosVersion":"%s","stoppedAt":"%s"}' \
		"$report_id" "$membership_number" "$report_step" "$report_reason" "$report_note" "$report_app" "$report_mindy_version" "$report_macos_version" "$stop_stamp" \
		| gate_curl -sS --connect-timeout 5 --max-time 10 -H 'Content-Type: application/json' --data-binary @- -w '\n%{http_code}' 'https://gate.mindy.build/mindy/setup-stops' 2>/dev/null)
	send_exit=$?
	if [ "$send_exit" != 0 ]; then send_outcome="no, curl stopped with exit status $send_exit"; return 2; fi
	# The answer's body, then its status on the last line.
	send_status=$(printf '%s\n' "$send_answer" | tail -n 1)
	case "$send_status" in
		2[0-9][0-9])
			if printf '%s\n' "$send_answer" | sed '$d' | grep -q '"received"[[:space:]]*:[[:space:]]*true'; then
				send_outcome="yes, the answer was status $send_status"
				return 0
			fi
			send_outcome="no, the answer was status $send_status but did not say the stop was received"
			return 1 ;;
		000|'') send_outcome='no, there was no answer'; return 2 ;;
		403) send_outcome='no, the answer was status 403, as the code was not issued'; return 3 ;;
	esac
	send_outcome="no, the answer was status $send_status"
	return 1
}

# Tells the member, in one of the decided messages and nothing else, what stopped setup, chosen by
# what happened. The stop note is kept first, so the report can carry it; what came of sending, and
# what was said, are added to the note afterwards. Whether the note could be kept is in the note, or
# is the reason the note is missing; it is not told.
#
# - A signal stopped setup: the interrupted message. The member, or whatever ran setup, stopped it
#   and may be waiting for it to end, so nothing is sent.
# - The gate refused a code it never issued, the gate is pausing this connection, or the gate could not
#   be reached: that message alone. Nothing is sent.
# - Any other stop is sent to MINDY's download server, with its note when the note was kept. Then:
#   it was taken: the stop's own message, which says the details were sent (the code is no longer
#   active, this Mac already has a different code, or the download is not a signed release), or for
#   any other stop "Setup stopped while <step>: <reason>." and the sent ending;
#   it was not taken: "Setup stopped while <step>: <reason>." and the not-taken ending, where the
#   reason for the three messages above is that message's own first words;
#   the server was not reached: the unreachable message;
#   the code is not a MINDY access code: the not-issued message.
# A reason that must not be shown is replaced by where it is kept, or, when the note could not be
# kept, by saying it is not shown.
# tell <setup exit status>
tell() {
	[ -n "$stop_reason" ] || stop_reason="the command for $step gave no reason${stop_status:+ (exit status $stop_status)}"
	case "$stop_message" in
		"$not_active_message") member_reason='this MINDY access code is no longer active' ;;
		"$different_code_message") member_reason='this Mac already has a different MINDY access code saved' ;;
		"$unsigned_message") member_reason='this download is not a signed MINDY release' ;;
	esac
	shown_reason=${member_reason:-$stop_reason}
	reason_withheld=false
	if [ "$withhold_reason" = true ] || must_not_show "$shown_reason"; then reason_withheld=true; shown_reason=$reason_kept; fi
	stop_time
	if keep_stop "$1"; then note_kept=true; else note_kept=false; fi
	if [ "$note_kept" = false ] && [ "$reason_withheld" = true ]; then shown_reason=$reason_not_shown; fi
	send_outcome=
	if [ -n "$signal" ]; then
		send_outcome='no, a signal stopped setup'
		said_line=$interrupted_message
	elif [ "$stop_message" = "$not_issued_message" ] || [ "$stop_message" = "$too_many_message" ] || [ "$stop_message" = "$unreachable_message" ]; then
		said_line=$stop_message
	else
		if send_stop_report; then sent=0; else sent=$?; fi
		case "$sent" in
			0)
				if [ -n "$stop_message" ]; then said_line=$stop_message
				else said_line="Setup stopped while $step: $(as_sentence "$shown_reason") $details_sent_ending"; fi ;;
			2) said_line="Setup stopped while $step: $(as_sentence "$shown_reason") $details_not_taken_ending" ;;
			3) said_line=$not_issued_message ;;
			*) said_line="Setup stopped while $step: $(as_sentence "$shown_reason") $details_not_taken_ending" ;;
		esac
	fi
	if [ "$step" = "checking for installed memory" ]; then said_line=$memory_first_message; fi
	say "$said_line" || :
	told=true
	if [ "$note_kept" = true ]; then
		{
			[ -z "$send_outcome" ] || printf 'Sent to MINDY: %s\n' "$send_outcome"
			printf 'Said to the member: %s\n' "$said_line"
		} | redact >>"$stop_file" 2>/dev/null || :
	fi
}

# The download server's own sentence from an error answer, when it gave one.
server_error() {
	sed -n 's/.*"error"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1" 2>/dev/null | head -n 1
}

# An answer other than 200. The script never shows the download server's own words. Three of the
# gate's answers are matched exactly, in its earlier or its current words, each to the decided message
# for it (the gate's rules are build-machine-stack src/mindy-gate-rules.js; it refuses with 403 and
# limits with 429): the code was not issued, the code is no longer active (its answer for a revoked or
# expired code too), and too many tries. Any other answer, whether from the gate or from something in
# the way such as a proxy, stops with the status alone as the reason shown. The stop note and the
# report keep the answer's own message after the status, and the note keeps the whole answer.
# stop_for_status <status> <answer file>
stop_for_status() {
	message=$(server_error "$2")
	status_reason="the answer was status $1"
	case "$1" in
		401|403)
			if is_gate_not_issued "$message"; then stop_saying "$not_issued_message" "$status_reason: $message"; fi
			if is_gate_not_active "$message"; then stop_saying "$not_active_message" "$status_reason: $message"; fi ;;
		429)
			if is_gate_too_many "$message"; then stop_saying "$too_many_message" "$status_reason: $message"; fi ;;
	esac
	member_reason=$status_reason
	kept_message=$(printf '%s\n' "$message" | first_meaningful)
	if [ -n "$kept_message" ]; then stop "$status_reason: $kept_message"; fi
	stop "$status_reason"
}

# The enrol and install steps ask the gate for themselves, and pass the gate's two code sentences on
# inside their own answer. Either one stops with the decided message for it, as on the direct route.
# Only the step's reason line is read for them, so a sentence elsewhere in its output, such as an
# earlier answer it repeats, does not stand in for why the step stopped.
# stop_for_gate_sentence <step output> <exit status of the step's command>
stop_for_gate_sentence() {
	gate_reason=$(reason_of "$1")
	for gate_sentence in "$gate_not_issued_sentence" "$gate_not_issued_sentence_now"; do
		case "$gate_reason" in *"$gate_sentence"*) stop_saying "$not_issued_message" "$gate_reason" "$2" ;; esac
	done
	for gate_sentence in "$gate_not_active_sentence" "$gate_not_active_sentence_now"; do
		case "$gate_reason" in *"$gate_sentence"*) stop_saying "$not_active_message" "$gate_reason" "$2" ;; esac
	done
}

# curl could not reach the download server at all: 5 no proxy, 6 no host, 7 no connection, 28 timed
# out, 35 no TLS connection. Any other curl failure, such as 23 (could not write) or 56 (cut off
# mid-transfer), is an ordinary stop with curl's own line as the reason.
# stop_for_curl <exit status> <error file>
stop_for_curl() {
	case "$1" in 5|6|7|28|35) stop_saying "$unreachable_message" "$(reason_of "$2")" "$1" ;; esac
	stop "$(reason_of "$2")" "$1"
}

plugin_version() {
	plugin_version_value=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$plugin_root/.claude-plugin/plugin.json" 2>/dev/null | head -n 1)
	printf '%s\n' "${plugin_version_value:-unknown}"
}

# Every failed run keeps its evidence at ~/.mindy/setup-stops/<UTC time>.txt, readable only by the
# member, so the whole reason can be read afterwards. $tmp is still removed. When the note cannot be
# kept, keep_stop returns 1 and leaves the first line of why in keep_failure.
# keep_stop <setup exit status>
keep_stop() {
	[ "$kept" = false ] || return 0
	kept=true
	keep_failure=
	if [ -z "$home" ]; then keep_failure='HOME is not set'; return 1; fi
	stops="$home/.mindy/setup-stops"
	if keep_error=$( (umask 077 && mkdir -p "$stops") 2>&1 ); then :; else
		keep_failure=$(printf '%s\n' "$keep_error" | first_meaningful)
		[ -n "$keep_failure" ] || keep_failure="$stops could not be made"
		return 1
	fi
	stop_time
	file_stamp=$(printf '%s\n' "$stop_stamp" | tr ':' '-')
	stop_file="$stops/$file_stamp.txt"
	[ ! -e "$stop_file" ] || stop_file="$stops/$file_stamp-$$.txt"
	if [ -n "$stop_status" ]; then step_status_text=$stop_status
	elif [ -n "$signal" ]; then step_status_text="none, $(signal_named) stopped it"
	else step_status_text='none, a check stopped it'; fi
	if keep_error=$( (
		umask 077
		{
			printf '%s\n' 'MINDY setup stop'
			printf 'Time (UTC): %s\n' "$stop_stamp"
			printf 'Report id: %s\n' "$report_id"
			printf 'App: %s\n' "$(app_name)"
			printf 'Step: %s\n' "$step"
			printf 'Reason: %s\n' "$stop_reason"
			printf 'Step exit status: %s\n' "$step_status_text"
			printf 'Setup exit status: %s\n' "$1"
			printf 'MINDY version on the download server: %s\n' "${version:-not known yet}"
			printf 'MINDY version already installed: %s\n' "${active_version:-none}"
			if [ "$harnesses_checked" = true ]; then printf 'Harnesses for this setup: %s\n' "${harness_list:-none found}"; else printf 'Harnesses for this setup: not checked yet\n'; fi
			printf 'Plugin version: %s\n' "$(plugin_version)"
			printf 'Machine (uname -m): %s\n' "$(uname -m 2>/dev/null || printf 'unknown')"
			printf 'macOS: %s\n' "$(sw_vers -productVersion 2>/dev/null || printf 'unknown')"
			if [ -n "$tmp" ]; then
				for evidence in "$tmp"/*.out "$tmp"/*.err "$tmp"/packument.json; do
					[ -s "$evidence" ] || continue
					printf '\n--- %s ---\n' "${evidence##*/}"
					redact <"$evidence" | head -c 65536
					printf '\n'
				done
			fi
		} | redact >"$stop_file"
	) 2>&1 ) && [ -s "$stop_file" ]; then return 0; fi
	keep_failure=$(printf '%s\n' "$keep_error" | first_meaningful)
	[ -n "$keep_failure" ] || keep_failure="$stop_file could not be written"
	rm -f "$stop_file" 2>/dev/null || :
	return 1
}

cleanup() {
	exit_status=$?
	set +e
	trap '' HUP INT TERM
	if [ "$finished" = false ]; then
		if [ "$said" = false ]; then
			said=true
			stop_message=
			member_reason=
			if [ -n "$signal" ]; then
				stop_status=
				stop_reason="it was stopped by $(signal_named)"
			else
				stop_status=$exit_status
				stop_reason=$(reason_of "$tmp/step.err")
				[ -n "$stop_reason" ] || stop_reason="a command stopped with exit status $exit_status"
			fi
			tell "$exit_status"
		elif [ "$told" = false ] && [ -n "$signal" ]; then
			# A signal stopped setup while it was sending a stop's details, before it said anything.
			say "$interrupted_message" || :
			told=true
			[ "${note_kept:-false}" = false ] || printf 'Said to the member: %s\n' "$interrupted_message" | redact >>"$stop_file" 2>/dev/null || :
		fi
		keep_stop "$exit_status" || :
		if [ -n "$archive" ] && [ -f "$archive" ]; then rm -f "$archive"; fi
		if [ "$created_version_dir" = true ] && [ -n "$version_dir" ]; then rm -rf "$version_dir"; fi
	fi
	if [ -n "$tmp" ]; then rm -rf "$tmp"; fi
}
trap cleanup EXIT
# The signal that stopped setup, as words: "an INT signal", "a TERM signal".
signal_named() {
	case "$signal" in INT) printf '%s\n' 'an INT signal' ;; *) printf 'a %s signal\n' "$signal" ;; esac
}
trap 'signal=HUP; exit 1' HUP
trap 'signal=INT; exit 1' INT
trap 'signal=TERM; exit 1' TERM
# stop <reason> [exit status of the step's command]
stop() {
	said=true
	stop_reason=$1
	stop_status=${2:-}
	tell 1
	exit 1
}
# stop_saying <message printed alone> <reason for the stop note> [exit status of the step's command]
stop_saying() {
	stop_message=$1
	shift
	stop "$@"
}

begin 'finding your home folder'
if [ -z "${HOME:-}" ]; then
	stop 'HOME is not set'
else
	home=$HOME
fi
client_root="$home/mindy"
downloads="$home/.mindy/downloads"

begin 'making a temporary folder'
if made=$(mktemp -d 2>&1) && [ -d "$made" ]; then tmp=$made; else stop "$(printf '%s\n' "$made" | first_meaningful)"; fi

begin 'checking for installed memory'
capture_registered=false
for registration in "$HOME/Library/Application Support/MINDY/memories/"*.json; do
 if [ -f "$registration" ] && [ ! -L "$registration" ] && grep -q '"role"[[:space:]]*:[[:space:]]*"capture"' "$registration"; then capture_registered=true; break; fi
done
[ "$capture_registered" = true ] || stop_saying "$memory_first_message" 'no capture memory is registered on this Mac'

begin "asking MINDY's download server for the latest release"
packument="$tmp/packument.json"
if status=$(gate_curl -sS -H 'Accept: application/json' -o "$packument" -w '%{http_code}' 'https://gate.mindy.build/mindy' 2>"$tmp/curl-packument.err"); then :; else
	stop_for_curl "$?" "$tmp/curl-packument.err"
fi
[ "$status" = 200 ] || stop_for_status "$status" "$packument"
# A 200 answer that is not MINDY's release list at all, such as a Wi-Fi sign-in page, says so.
if ! grep -q '"dist-tags"[[:space:]]*:' "$packument" 2>/dev/null; then
	answer_start=$(reason_of "$packument")
	if [ -n "$answer_start" ]; then member_reason="the answer is not MINDY's release list"; stop "$member_reason; it begins: $answer_start"; fi
	stop 'the answer was empty'
fi

tags=$(sed -n 's/.*"dist-tags"[[:space:]]*:[[:space:]]*{\([^}]*\)}.*/\1/p' "$packument" | head -n 1)
version=$(printf '%s\n' "$tags" | sed -n 's/.*"latest"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
[ -n "$version" ] || stop "the download server's answer names no latest release"
version_entry=$(sed -n "s/.*\"$version\"[[:space:]]*:[[:space:]]*{\([^}]*\)}.*/\1/p" "$packument" | head -n 1)
integrity=$(printf '%s\n' "$version_entry" | sed -n 's/.*"integrity"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
case "$integrity" in sha512-*) ;; *) stop "the download server's answer for MINDY $version has no sha512 integrity value" ;; esac

# Enrol only the apps whose command is on this Mac: the install runs `claude --version` or
# `codex --version` for each one it registers, so an app without its command stops the install.
# An update keeps the apps recorded when MINDY was installed, and adds only an app that is on this
# Mac now and that MINDY is not yet set up in (see the check just below).
begin 'checking for Claude Code and Codex'
# Each app's command is looked for where that app installs it, not only on PATH, because the shell
# that runs setup is the shell of whichever app the member typed the command in, and the other app's
# command may not be on its PATH. This one lookup is used for a first install, an update and an add.
# Claude Code: on PATH, then ~/.local/bin/claude (its own installer's place, which a Terminal's PATH
# usually holds and Claude Code's shell may not), then ~/.claude/local/claude (its earlier place).
# Codex, the ChatGPT app: on PATH, then CODEX_CLI_PATH, which the app sets to its own copy of codex,
# then that copy where the app keeps it, <Applications>/ChatGPT.app/Contents/Resources/codex-cli/
# CodexCLI.app/Contents/MacOS/codex, and where an earlier build of the app kept it,
# <Applications>/Codex.app/Contents/Resources/codex, in /Applications and in ~/Applications. Both
# were read from the installed app on 4 October 2026. CODEX_CLI_PATH is used only as a whole path,
# with no ":" that would split it into two PATH entries and no line break that would hide a second
# path after the first, to an executable file named codex. A found
# command that is not on PATH gets its folder put at the end of PATH, for this script and the engine
# it runs, which runs `claude --version` or `codex --version` for each app it registers.
# MINDY_SETUP_APPLICATIONS_FOLDER names the folder to look in instead of /Applications, which is how a
# test keeps the Mac it runs on out of its answers.
# find_app_command <claude|codex> prints the command's full path, or nothing.
find_app_command() {
	app_found=$(command -v "$1" 2>/dev/null) || app_found=
	case "$app_found" in /*) if [ -f "$app_found" ] && [ -x "$app_found" ]; then printf '%s\n' "$app_found"; return 0; fi ;; esac
	if [ "$1" = claude ]; then
		app_candidates="$home/.local/bin/claude
$home/.claude/local/claude"
	else
		app_candidates=${CODEX_CLI_PATH:-}
		case "$app_candidates" in *:*|*'
'*) app_candidates= ;; /*/codex) ;; *) app_candidates= ;; esac
		for app_folder in "${MINDY_SETUP_APPLICATIONS_FOLDER:-/Applications}" "$home/Applications"; do
			app_candidates="${app_candidates:+$app_candidates
}$app_folder/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex
$app_folder/Codex.app/Contents/Resources/codex"
		done
	fi
	while IFS= read -r app_candidate; do
		if [ -n "$app_candidate" ] && [ -f "$app_candidate" ] && [ -x "$app_candidate" ]; then printf '%s\n' "$app_candidate"; return 0; fi
	done <<APP_CANDIDATES
$app_candidates
APP_CANDIDATES
	return 0
}
claude_command=$(find_app_command claude)
codex_command=$(find_app_command codex)
for app_command_found in "$claude_command" "$codex_command"; do
	[ -n "$app_command_found" ] || continue
	if ! command -v "${app_command_found##*/}" >/dev/null 2>&1; then
		PATH="$PATH:${app_command_found%/*}"
		export PATH
	fi
done

begin 'checking which MINDY is already here'
active="$client_root/.mindy/release-selection/active-release.json"
if [ -f "$active" ]; then active_version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$active" | head -n 1); fi
action=install
if [ -n "$active_version" ]; then
 action=update
 details_not_taken_ending="$details_not_taken_ending Open your MINDY folder and type /bwmteam if you need help."
fi
if [ "$active_version" = "$version" ]; then
	# The latest release is already here. An app put on this Mac after MINDY, Claude Code or the
	# ChatGPT app (Codex), still has no MINDY: the active receipt names the apps MINDY was set up in,
	# and a receipt that names none is one for both. Each app on this Mac that is not named gets MINDY
	# by the same steps as an update, with that app added to the ones recorded. With nothing to add,
	# setup says MINDY is already installed and does nothing else.
	begin 'checking for Claude Code and Codex'
	set_up=$(sed -n 's/.*"harnesses"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p' "$active" | head -n 1)
	set_up_list=
	if [ -z "$set_up" ]; then set_up_list='claude-code codex'; else
		case "$set_up" in *'"claude-code"'*) set_up_list='claude-code' ;; esac
		case "$set_up" in *'"codex"'*) set_up_list="${set_up_list:+$set_up_list }codex" ;; esac
	fi
	adding_an_app=false
	for app in claude-code codex; do
		app_command=$claude_command
		if [ "$app" = codex ]; then app_command=$codex_command; fi
		case " $set_up_list " in
			*" $app "*) harness_list="${harness_list:+$harness_list }$app" ;;
			*) if [ -n "$app_command" ] || { [ "$app" = claude-code ] && [ "${MINDY_CLAUDE_LOCAL:-}" = 1 ]; }; then harness_list="${harness_list:+$harness_list }$app"; adding_an_app=true; fi ;;
		esac
	done
 repair_install_record() {
  begin 'laying MINDY on this Mac'
  MINDY_INSTALLER_REPORTS=1; export MINDY_INSTALLER_REPORTS
  withhold_reason=true
  # The folder's own signed selection supplies the interpreter and repair command.
  materialized=$(sed -n 's/^.*"materializedReleaseDir":"\([^"]*\)".*$/\1/p' "$active")
  case "$materialized" in "$client_root"/.mindy/system-releases/*) ;; *) stop "MINDY installed folder has no verified active release" ;; esac
  set -- "$materialized"/components/mindy-bun-runtime/*/bun
  [ "$#" -eq 1 ] && [ -x "$1" ] && [ ! -L "$1" ] || stop "MINDY installed folder has no bundled runtime"
  if "$1" "$materialized/components/mindy-engine/mindy-install/delivery-cli.ts" --repair-install-record --client-root "$client_root" >"$tmp/record-repair.out" 2>&1; then :; else
   withhold_reason=true; stop "$(reason_of "$tmp/record-repair.out")"
  fi
  withhold_reason=false
 }
	if [ "$adding_an_app" = false ]; then repair_install_record; finished=true; printf '%s\n' 'MINDY is already installed.'; exit 0; fi
	# Enrolling grows the record of the apps before the install runs, and the record cannot shrink again.
	# So nothing is enrolled unless the command of every app in the new list answers --version, as the
	# install will ask of it. When one does not, nothing is added and setup says what it said before.
	for app in $harness_list; do
		app_command=$claude_command
		if [ "$app" = codex ]; then app_command=$codex_command; fi
		if [ "$app" = claude-code ] && [ -z "$app_command" ] && [ "${MINDY_CLAUDE_LOCAL:-}" = 1 ]; then continue; fi
		if [ -z "$app_command" ] || ! "$app_command" --version >/dev/null 2>&1 </dev/null; then repair_install_record; finished=true; printf '%s\n' 'MINDY is already installed.'; exit 0; fi
	done
fi

begin 'checking for Claude Code and Codex'
if [ "$action" = update ] && [ -z "$harness_list" ]; then
	recorded=$(sed -n 's/.*"harnessIds"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p' "$client_root/.mindy/update-verifier.json" 2>/dev/null | head -n 1)
	case "$recorded" in *'"claude-code"'*) harness_list='claude-code' ;; esac
	case "$recorded" in *'"codex"'*) harness_list="${harness_list:+$harness_list }codex" ;; esac
fi
if [ -z "$harness_list" ]; then
	# With no record yet, an app is enrolled only when its command answers --version, as the install
	# will ask of it, so an app the member does not use never stops their first install. One left out
	# can be added later by typing the command again.
	if { [ -n "$claude_command" ] && "$claude_command" --version >/dev/null 2>&1 </dev/null; } || [ "${MINDY_CLAUDE_LOCAL:-}" = 1 ]; then harness_list='claude-code'; fi
	if [ -n "$codex_command" ] && "$codex_command" --version >/dev/null 2>&1 </dev/null; then harness_list="${harness_list:+$harness_list }codex"; fi
fi
harnesses_checked=true
[ -n "$harness_list" ] || stop "neither claude nor codex is on this Mac's PATH"
set --
for harness in $harness_list; do set -- "$@" --harness "$harness"; done

begin 'downloading MINDY'
mkdir -p "$downloads"
version_dir="$downloads/$version"
if [ ! -d "$version_dir" ]; then mkdir -p "$version_dir"; created_version_dir=true; fi
archive="$version_dir/mindy.tgz"
if status=$(gate_curl -sS -o "$archive" -w '%{http_code}' "https://gate.mindy.build/mindy/-/mindy-$version.tgz" 2>"$tmp/curl-archive.err"); then :; else
	stop_for_curl "$?" "$tmp/curl-archive.err"
fi
if [ "$status" != 200 ]; then
	head -c 4096 "$archive" >"$tmp/download-answer.out" 2>/dev/null || :
	stop_for_status "$status" "$tmp/download-answer.out"
fi

begin 'checking the download'
actual=$(shasum -a 512 "$archive" 2>"$tmp/shasum-archive.err" | sed 's/[[:space:]].*$//')
expected=$(printf '%s\n' "${integrity#sha512-}" | openssl base64 -d -A 2>"$tmp/openssl-base64.err" | od -An -tx1 2>"$tmp/od.err" | tr -d ' \n')
if [ -z "$expected" ]; then
	decode_reason=$(reason_of "$tmp/openssl-base64.err" "$tmp/od.err")
	[ -n "$decode_reason" ] || decode_reason="the download server's sha512 integrity value could not be decoded"
	stop "$decode_reason"
fi
# An empty digest means shasum itself failed on this Mac, which says nothing about the download.
[ -n "$actual" ] || stop "$(reason_of "$tmp/shasum-archive.err")"
[ "$actual" = "$expected" ] || stop "the download's sha512 digest does not match the download server's integrity value"

begin 'unpacking the download'
mkdir -p "$tmp/unpacked"
if tar -xzf "$archive" -C "$tmp/unpacked" 2>"$tmp/tar.err"; then :; else tar_status=$?; stop "$(reason_of "$tmp/tar.err")" "$tar_status"; fi

begin 'checking the download is a signed MINDY release'
release="$tmp/unpacked/package/release"
key="$plugin_root/keys/mindy-release-signature.pem"
[ -f "$release/release-signature.sig" ] && [ -f "$release/release-signature.json" ] || stop_saying "$unsigned_message" 'the download has no release signature'
if openssl dgst -sha256 -verify "$key" -signature "$release/release-signature.sig" "$release/release-signature.json" >"$tmp/openssl-verify.out" 2>"$tmp/openssl-verify.err"; then :; else
	verify_status=$?
	# Only openssl's own verdict means the signature does not verify: LibreSSL, macOS's openssl, says
	# "Error Verifying Data" and OpenSSL 3 says "Verification failure". Anything else is openssl
	# failing to run the check on this Mac.
	if grep -qi -e 'verification failure' -e 'error verifying data' "$tmp/openssl-verify.out" "$tmp/openssl-verify.err" 2>/dev/null; then
		stop_saying "$unsigned_message" "$(reason_of "$tmp/openssl-verify.err" "$tmp/openssl-verify.out")" "$verify_status"
	fi
	stop "$(reason_of "$tmp/openssl-verify.err" "$tmp/openssl-verify.out")" "$verify_status"
fi
manifest_file_digest=$(shasum -a 256 "$release/release-manifest.json" 2>"$tmp/shasum-manifest.err" | sed 's/[[:space:]].*$//')
[ -n "$manifest_file_digest" ] || stop "$(reason_of "$tmp/shasum-manifest.err")"
signed_manifest_file_digest=$(sed -n 's/.*"manifestFileDigest"[[:space:]]*:[[:space:]]*"sha256:\([^"]*\)".*/\1/p' "$release/release-signature.json" | head -n 1)
[ -n "$signed_manifest_file_digest" ] && [ "$manifest_file_digest" = "$signed_manifest_file_digest" ] || stop_saying "$unsigned_message" 'the release manifest does not match its signature'

begin "checking this Mac's chip"
machine=$(uname -m 2>"$tmp/uname.err")
case "$machine" in arm64) arch=arm64;; x86_64) arch=x64;; *) stop "this Mac reports its chip as ${machine:-nothing}";; esac

begin 'checking the download is a signed MINDY release'
bun="$release/components/mindy-bun-runtime/darwin-$arch/bun"
runtime_component=$(sed -n 's/.*"componentId"[[:space:]]*:[[:space:]]*"mindy-bun-runtime"\(.*\)/\1/p' "$release/release-manifest.json" | sed 's/"componentId".*//')
runtime_entry=$(printf '%s\n' "$runtime_component" | sed -n "s|.*\({[^{}]*\"path\"[[:space:]]*:[[:space:]]*\"darwin-$arch/bun\"[^{}]*}\).*|\1|p" | head -n 1)
manifest_bun_digest=$(printf '%s\n' "$runtime_entry" | sed -n 's/.*"fileDigest"[[:space:]]*:[[:space:]]*"\(sha256:[^"]*\)".*/\1/p' | head -n 1)
[ -f "$bun" ] || stop_saying "$unsigned_message" "the download has no MINDY runtime for darwin-$arch"
actual_bun_digest="sha256:$(shasum -a 256 "$bun" 2>"$tmp/shasum-bun.err" | sed 's/[[:space:]].*$//')"
[ "$actual_bun_digest" != 'sha256:' ] || stop "$(reason_of "$tmp/shasum-bun.err")"
[ "$actual_bun_digest" = "$manifest_bun_digest" ] || stop_saying "$unsigned_message" 'the MINDY runtime in the download does not match the signed manifest'

begin 'getting the MINDY runtime ready'
if chmod 700 "$bun" 2>"$tmp/chmod.err"; then :; else chmod_status=$?; stop "$(reason_of "$tmp/chmod.err")" "$chmod_status"; fi

# This verifier belongs to setup, not the download. It loads only Bun built-ins.
# Check the whole engine, including unlisted files, before any downloaded source loads.
if (cd "$tmp" && "$bun" -e '
 const fs = require("node:fs"), path = require("node:path"), crypto = require("node:crypto");
 const [release, componentId, firstScript] = process.argv.slice(1);
 const manifest = JSON.parse(fs.readFileSync(path.join(release, "release-manifest.json"), "utf8"));
 const components = manifest.components.filter(item => item.componentId === componentId);
 if (components.length !== 1 || components[0].representations.length !== 1) process.exit(1);
 const inventory = components[0].representations[0].inventory;
 const expected = new Map();
 for (const entry of inventory) {
  if (typeof entry.path !== "string" || entry.path.includes("\\") || entry.path.split("/").some(part => !part || part === "." || part === "..") || path.isAbsolute(entry.path)) process.exit(1);
  if (!/^sha256:[a-f0-9]{64}$/.test(entry.fileDigest) || expected.has(entry.path)) process.exit(1);
  expected.set(entry.path, entry.fileDigest);
 }
 if (!expected.has(firstScript)) process.exit(1);
 const root = path.join(release, "components", componentId);
 if (!fs.lstatSync(path.join(release, "components")).isDirectory() || !fs.lstatSync(root).isDirectory()) process.exit(1);
 const seen = new Set();
 function walk(directory, prefix) {
  for (const name of fs.readdirSync(directory)) {
   const file = path.join(directory, name), relative = prefix + name, info = fs.lstatSync(file);
   if (info.isDirectory()) { walk(file, relative + "/"); continue; }
   if (!info.isFile() || !expected.has(relative)) process.exit(1);
   const digest = "sha256:" + crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
   if (digest !== expected.get(relative)) process.exit(1);
   seen.add(relative);
  }
 }
 walk(root, "");
 if (seen.size !== expected.size) process.exit(1);
' "$release" mindy-engine mindy-install/delivery-credential-cli.ts) >/dev/null 2>&1; then :; else stop_saying "$unsigned_message" 'the engine files in the download do not match the signed manifest'; fi

engine="$release/components/mindy-engine/mindy-install"
begin 'saving your access code on this Mac'
enrol="$tmp/enrol.out"
# The code reaches the engine on standard input, written by printf, which is part of this shell, so no
# program's arguments hold it and the Mac's list of running programs never shows it.
if printf '%s\n' "$code" | "$bun" "$engine/delivery-credential-cli.ts" bootstrap-with-code --membership-code-on-stdin --client-root "$client_root" "$@" >"$enrol" 2>&1; then enrol_status=0; else enrol_status=$?; fi
if [ "$enrol_status" != 0 ]; then
	message=$(sed -n '1p' "$enrol")
	# The engine's own sentences, matched exactly. Release 1.0.6 has the older different-code sentence.
	stop_for_gate_sentence "$enrol" "$enrol_status"
	if [ "$message" = "$engine_different_code_sentence" ] || [ "$message" = "$engine_different_code_sentence_before" ]; then stop_saying "$different_code_message" "$message" "$enrol_status"; fi
	# The engine's stop names its case, which becomes the plain reason. Its own code, such as
	# CREDENTIAL_PLACEMENT_FAILED, and its detail stay in the stop note and the stop report.
	enrol_reason=$(reason_of "$enrol")
	enrol_case=$(printf '%s\n' "$enrol_reason" | sed -n 's/.*"case"[[:space:]]*:[[:space:]]*"\([a-z-]*\)".*/\1/p' | head -n 1)
	member_reason=$(access_code_reason "$enrol_case")
	case "$enrol_reason" in '{'*) [ -n "$member_reason" ] || withhold_reason=true ;; esac
	stop "$enrol_reason" "$enrol_status"
fi

MINDY_INSTALLER_REPORTS=1
export MINDY_INSTALLER_REPORTS
begin 'installing MINDY'
install="$tmp/install.out"
if "$bun" "$engine/delivery-cli.ts" --release-signature "$release/release-signature.json" --release-package "$archive" --operation-id "mindy-setup-$(date +%s)-$$" --action "$action" --client-root "$client_root" >"$install" 2>&1; then :; else
	install_status=$?
	stop_for_gate_sentence "$install" "$install_status"
	install_reason=$(reason_of "$install")
 if grep -q 'MINDY_HOME_RUNTIME_LAY_FAILED' "$install"; then begin 'laying MINDY on this Mac'; withhold_reason=true; fi
	case "$install_reason" in
		*"Claude Local Code"*|*"Claude Code plugin copy"*|*"MINDY delivery install record"*|*"MINDY installed folder"*|*"Kept release signature does not name this release"*) withhold_reason=true ;;
	esac
	stop "$install_reason" "$install_status"
fi

begin 'laying MINDY on this Mac'
lay="$tmp/lay.out"
if "$bun" "$engine/home-runtime-lay.ts" "$client_root" >"$lay" 2>&1; then :; else
 lay_status=$?
 withhold_reason=true
 stop "$(reason_of "$lay")" "$lay_status"
fi

finished=true
printf '%s\n' 'Build With Mindy is now in a folder called mindy in your home folder.'
# The engine's receipt says "codexPet":"placed" when MINDY's Codex pet is in the member's pets (an engine
# from before the pet says nothing). The /install-bwm skill tells the member only when this line is printed.
if grep -q '"codexPet":"placed"' "$install" 2>/dev/null; then printf '%s\n' "MINDY's Codex pet is in place."; fi
