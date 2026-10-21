---
name: install-bwm
description: Use /install-bwm to set up Build With Mindy with your access code.
user-invocable: true
---

Keep routine checks and successful writes silent. Never announce a skill name, markers, registration, settings checks or your working notes. Use a short member-facing tool description instead of the command text. Send each fixed question or confirmation once, verbatim, in its own message when specified. Do not paraphrase it or join it to the next question.

AI-facing triggers: /install-bwm, install MINDY, set up MINDY, or my MINDY access code. Invoke this skill with no arguments. Never put a person's code in the Skill tool arguments, shell command, tool input, permission reason, description, running line or reply. It stays in their own chat message; the setup script reads it there.

In the Claude app outside a Local Code session, do not run setup or ask for an access code. Say exactly: `Install has to run on your own computer, and this chat runs somewhere else, so it can't happen here. Click the </> button and choose This computer, then type /install-bwm with your access code there.` If their message contained an access code, add exactly: `Your access code is now in this chat. Keep it private, and use it in the new session on this computer.` Then stop.

Before asking for a code, mentioning Manual, requesting permission or running any setup script, use ordinary file tools to read the records described below, or run this read-only command inside the sandbox. Replace `<current app>` with `claude-code` in either Claude Code host or `codex` in either Codex host. Replace `<current host>` with `claude-local`, `claude-terminal`, `chatgpt` or `codex` according to the app the person is using. Identify the ChatGPT app from the actual window or `CODEX_INTERNAL_ORIGINATOR_OVERRIDE` containing `ChatGPT`; the word Codex alone does not prove the ChatGPT app. A Codex-marked host can still be the ChatGPT app, as on the laptop test. When the host is unknown or only marked Codex, retain the complete conditional ChatGPT block below; do not drop it because the host was not positively identified. These literal names carry no code. Never run the setup script to do this check.

```sh
bwm_app='<current app>'
bwm_host='<current host>'
bwm_root="$HOME/mindy"
bwm_read() { /usr/bin/plutil -extract "$2" "$3" -o - "$1" 2>/dev/null; }
bwm_capture=false
for bwm_file in "$HOME/Library/Application Support/MINDY/memories/"*.json; do
 if [ -f "$bwm_file" ] && [ ! -L "$bwm_file" ] && [ "$(bwm_read "$bwm_file" role raw)" = capture ]; then bwm_capture=true; break; fi
done
if [ "$bwm_capture" = false ]; then
 printf '%s\n' BWM_TIMESAVER_FIRST 'Install MINDY TimeSaver first. Add MINDY TimeSaver Setup where you add plugins, and type /install-mts with your TimeSaver access code. When it has finished, type /install-bwm with your Build With Mindy code again.'
 exit 0
fi
bwm_active="$bwm_root/.mindy/release-selection/active-release.json"
bwm_version=
if [ -f "$bwm_active" ] && [ ! -L "$bwm_active" ]; then bwm_version=$(bwm_read "$bwm_active" version raw); fi
if [ -z "$bwm_version" ]; then
 printf '%s\n' BWM_INSTALL_READY
 exit 0
fi
bwm_apps=$(bwm_read "$bwm_active" harnesses json)
# A release from before the app list was recorded was set up in both apps.
if [ -z "$bwm_apps" ] || [ "$(bwm_read "$bwm_active" harnesses raw)" = 0 ] || printf '%s' "$bwm_apps" | grep -q "\"$bwm_app\""; then
 printf '%s\n' BWM_ALREADY_INSTALLED 'MINDY is already installed.' 'Would you like us to check for an update, repair MINDY, or add it to another app?'
 case "$bwm_host" in
  chatgpt) printf '%s\n' "If you see an anchor icon with a yellow dot under the message box, MINDY needs your okay to work in the background while you chat. Click it, then Allow all." 'Open Customize, then Plugins, and click the refresh button beside Search plugins. Next, start a new chat with This computer selected and type /mindysetup' ;;
  claude-local|claude-terminal) printf '%s\n' 'Next, start a new session and type /mindysetup' ;;
  *) printf '%s\n' 'If you are in the ChatGPT app:' "If you see an anchor icon with a yellow dot under the message box, MINDY needs your okay to work in the background while you chat. Click it, then Allow all." 'Open Customize, then Plugins, and click the refresh button beside Search plugins. Next, start a new chat with This computer selected and type /mindysetup' 'In other apps, start a new chat and type /mindysetup' ;;
 esac
else
 printf '%s\n' BWM_ADD_APP 'MINDY is installed on this computer, but it has not been added to this app yet. Would you like us to add it now?'
fi
```

These reads check the regular JSON files in `<home>/Library/Application Support/MINDY/memories` for top-level `role: capture`, and the active release receipt's `version` and `harnesses` in `<home>/mindy`, the one folder setup installs, updates, repairs and adds apps in. A missing app list is the older receipt for both apps. File tools must apply these same tests. They read local files only: no writes, internet, plugin execution or permission request. `plutil -extract ... -o -` prints the extracted value and does not change its file. Hide the BWM markers and paths, and relay the other output lines exactly.

For `BWM_TIMESAVER_FIRST`, stop, with or without a code. For `BWM_ALREADY_INSTALLED`, stop, with or without a code. Give every line after the offer, in order, even when the person does not choose an update: in the ChatGPT app that is the anchor-icon line and then the next-step line. For an unknown or Codex-marked host, give the complete conditional ChatGPT block and the other-app next step instead. Do not compare with the latest release here: the update offer is how someone on an older release chooses that check. For `BWM_ADD_APP`, wait for the person to choose adding this app. No Manual instruction, permission request or setup call before that choice.

Only a new install (`BWM_INSTALL_READY`), or a separate update, repair or add-app step the person has chosen, continues below. On the chosen step append `--chosen-action update`, `--chosen-action repair` or `--chosen-action add-app` to the command. A code in the original install request is never itself a choice to update or repair.

Before a new install, check whether the person gave a code in this chat. If not, say exactly: `This needs your MINDY access code, which came in the message with your install steps. Type /install-bwm, a space and your code, all on one line.` Then stop, before Manual or permission.

Before a chosen update, repair or add-app step, check the same. If not, do not ask them to type /install-bwm again: that only brings back the already-installed sentence and the choice. Say exactly: `This needs your MINDY access code, which came in the message with your install steps. Type your code on its own and send it.` Then stop, before Manual or permission. When their next message is the code on its own, carry on with the step they already chose, from the Manual sentence below: do not run the reads again and do not ask them to choose again. The setup script reads a message that is only the code.

If the server says this is not a MINDY access code, relay only this sentence: `That looks like a MINDY TimeSaver code. The two products have different codes, so nothing was installed. Type /install-bwm with your Build With Mindy access code.` Do not guess that it is a test code or repeat any part of it. A malformed code still uses the copy-in-full reply below.

A code is a membership number of 3 to 32 letters, digits or hyphens, a dot, and exactly 86 letters, digits, underscores or hyphens. A full stop after it is punctuation. Let the server decide which product it belongs to. Never search other chats for a code.

In Local Code in the Claude app and in Claude Code in the Terminal, before the setup command or any permission request, say exactly: `We're about to install Build With Mindy on this computer, and Auto mode can stop an install part way. So switch the mode at the bottom of the window to Manual for now, and tell me when it shows Manual. Once it's installed, you can switch back to Auto.` If the host does not already show Manual, stop this turn and wait until the person confirms Manual or the host shows it. Switching back to Auto afterwards is the person's choice, as that sentence says, so say nothing more about it and do not wait for it. Do not give this mode instruction in either Codex host.

Run exactly one setup command, with no tool stdin, here-document or code-bearing environment variable:

```sh
<script> --code-from-chat --app <current app> --session-id "<current session id>"
```

Use this chat's host-provided session id only. In Claude Code use `CLAUDE_CODE_SESSION_ID` or `CLAUDE_SESSION_ID`, or the current session id the host gives you. In Codex use `CODEX_THREAD_ID`. Never use the newest file or guess an id. The script uses TimeSaver's already-installed Bun to read the Claude Code file named for that session under its projects folder, or the Codex file whose first metadata row matches the thread id under its sessions folder. It reads only user messages in that chat. Its answer goes into the setup process, never a tool output or temporary file. If there is no code, it prints the no-code sentence above for a new install, or the code-on-its-own sentence for a chosen step; relay it and stop. The newest message that holds anything shaped like a code decides, wherever the code sits in it and even when it is wrong: if that message does not hold exactly one valid code and nothing else shaped like one (a code one character short or long, say, or two codes), the script prints `This is not a MINDY access code, so setup can't use it. Copy the code again in full from the message it came in, then type /install-bwm with it.`, or for a chosen step `This is not a MINDY access code, so setup can't use it. Copy the code again in full from the message it came in, then send it on its own.`, and never uses an earlier code instead; relay it and stop. After the chosen-step sentence, a next message that is the code on its own carries on with the step already chosen, as above. If this chat cannot be identified or read, it prints `We could not read your code from this chat. Start a new chat and type /install-bwm with your code there.` Relay it and stop; typing again in an unreadable chat cannot help. If TimeSaver's reader cannot run, it prints `MINDY TimeSaver needs repairing before we can read your code. Type /install-mts with your TimeSaver access code, then try /install-bwm again.` Relay it and stop. Never fall back to showing a code in a command or permission box.

Use these tool labels exactly:

- Permission title: `Install Build With Mindy`
- Permission description or justification: `Install Build With Mindy in your home folder and add it to your apps.`
- Running line or Bash description: `Install Build With Mindy`
- Successful running line: `Installed Build With Mindy`

In Claude Code, resolve the host-supplied plugin folder to a quoted literal absolute path for `<script>`, ending in `/scripts/mindy-setup.sh`. Never leave a variable in braces in the command. Resolve the session id from host context or a separate read-only `printenv CLAUDE_CODE_SESSION_ID CLAUDE_SESSION_ID`, then put the confirmed literal id in the command, never a shell default expression. In Local Code in the Claude app, append `--claude-local`. This registers the private full plugin at user scope, using the CLI when present and the same local records when it is absent.

In the ChatGPT app (Codex), this skill's `SKILL.md` was given to you by its absolute path, and the plugin folder is two levels above the `install-bwm` skill folder, so `<script>` is the quoted absolute path `<plugin folder>/scripts/mindy-setup.sh`.

The script must run with network access and outside the sandbox: it gets the signed install package from MINDY's server and saves it in the person's home folder, outside the current folder. Inside the sandbox it cannot reach the server, and it would then wrongly tell the person to check they are online. Never run it inside the sandbox first to see whether it works. Run it outside the sandbox from the first try, by your app's own way of doing that: in Claude Code, whose sandbox is off unless the person turned it on, run the command with the sandbox disabled (`dangerouslyDisableSandbox: true`) only when your Bash tool's instructions describe a sandbox, and otherwise run it as an ordinary command without `dangerouslyDisableSandbox`; in the ChatGPT app (Codex), make the one request the next paragraph describes. If your app will ask the person before it runs the command, first say exactly `Setup needs to reach the internet and save Build With Mindy in your home folder. When your app asks, allow it this once.` In Local Code in the Claude app when the current mode is Manual, always say that allow-it-this-once sentence immediately before the setup command or its permission request. Otherwise, if your app can run the command outside the sandbox without asking (Codex set to never ask or to full access), just run it, without that sentence. Only if the person declines, do not run it, and say exactly `Setup needs that permission to install Build With Mindy. Ask me again when you're ready.` In Claude Code, if the tool result says the setup command was denied by the auto mode classifier, do not run it again and do not suggest adding permission rules or changing settings; say exactly `Auto mode stopped setup, because it's careful about anything that installs from the internet. Fair enough. Press Shift and Tab together until the line under the box says manual mode on. Then press the up arrow, press Return, and choose Yes (not the don't ask again option) when it asks, and setup will carry on.`

In the ChatGPT app (Codex), the app lets the command reach the internet and edit only the folders you ask for, and setup edits three folders in the person's home folder: `mindy`, where MINDY goes; `.mindy`, where setup keeps its install package and its notes; and `.codex`, where setup adds MINDY to this app. Asking for fewer stops setup part way, and asking again for each missing folder means another stop each time. So make one request, before setup runs, for the internet and all of these folders together. First, with one ordinary command inside the sandbox, which asks the person nothing, find the full path of the person's home folder and whether Claude Code is on this computer too: `printf '%s\n' "$HOME"; if command -v claude >/dev/null 2>&1 || test -x "$HOME/.local/bin/claude" || test -x "$HOME/.claude/local/claude"; then printf '%s\n' BWM_CLAUDE_PRESENT; fi`. Its first line is `<home>`. A second line means Claude Code is on this computer and setup adds MINDY to it as well, so `<home>/.claude` is a fourth folder in the same request. Then call the `request_permissions` tool once, with `{"network": {"enabled": true}, "file_system": {"write": ["<home>/mindy", "<home>/.mindy", "<home>/.codex"]}}`, adding `"<home>/.claude"` to that list when Claude Code is on this computer. Say the sentence above about allowing it this once just before this call. The app then asks the person once to let it connect to the internet and edit those folders. Never ask for the folders one at a time. When the person allows it, run the setup command straight away, in the same turn, as an ordinary command with no `sandbox_permissions`. Only if the `request_permissions` tool is not offered to you, instead run the setup command once with escalated permissions (`sandbox_permissions: "require_escalated"`) and a one-line justification, such as `Install Build With Mindy in your home folder and add it to your apps.`, which never contains the code. When Codex is set to never ask or to full access, request nothing, give no `sandbox_permissions` and just run it, as the paragraph above says.

When the script stops before it finishes, relay every line it printed, exactly as printed and in order. When it says `MINDY is already installed.`, relay it, offer `Would you like us to check for an update, repair MINDY, or add it to another app?`, then give this host's lines below. Run no further script unless the person chooses a step.

At the successful install sentence below, place `![MINDY](<${CLAUDE_PLUGIN_ROOT}/assets/mindy-message-icon.png>)` beside that sentence in the reply. Resolve `${CLAUDE_PLUGIN_ROOT}` to this plugin's absolute folder supplied by the host, or move up two directories from the folder containing this skill file. Use the host's image-viewing tool to display those image bytes inline at this moment. In a connected-folder chat, use its image tool, never a cloud shell file path. Do not print that local Markdown image expression, a text link, the word MINDY as a substitute, or the file path. If the host cannot display image bytes, continue without a picture. A text-only Terminal cannot display this PNG as an inline image; never print its path.

When it says `Build With Mindy is now in a folder called mindy in your home folder.`, relay it, then give this host's lines below exactly, one per line, in order. You cannot see the person's window, so in the ChatGPT app always give the anchor-icon line, before the next-step line, after a new install, an update, a repair, adding the app, and the already-installed outcome alike; it is worded so it applies only when they see the icon. Do not wait for a reply between the two lines. For an unknown or Codex-marked host, give the complete conditional ChatGPT block below, even if host detection did not identify ChatGPT. Omit that block only in a positively identified Claude host.

In Claude Code (the Claude app and the Terminal):

Next, start a new session and type /mindysetup

In the ChatGPT app:

If you see an anchor icon with a yellow dot under the message box, MINDY needs your okay to work in the background while you chat. Click it, then Allow all.
Open Customize, then Plugins, and click the refresh button beside Search plugins. Next, start a new chat with This computer selected and type /mindysetup

In an unknown or Codex-marked host, including Codex outside the ChatGPT app:

If you are in the ChatGPT app:
If you see an anchor icon with a yellow dot under the message box, MINDY needs your okay to work in the background while you chat. Click it, then Allow all.
Open Customize, then Plugins, and click the refresh button beside Search plugins. Next, start a new chat with This computer selected and type /mindysetup
In other apps, start a new chat and type /mindysetup

When the script also printed the line `MINDY's Codex pet is in place.` and you are in the ChatGPT app (Codex), then after the steps above say `MINDY's in your pets list now too, if you'd like to choose it.` Without that line from the script, say nothing about a pet. Never relay the script's pet line itself.

Never print the code back. Read only the local registration and install receipts for the early checks. Only the script reads this chat for the code. Do not read or change unrelated folders.
