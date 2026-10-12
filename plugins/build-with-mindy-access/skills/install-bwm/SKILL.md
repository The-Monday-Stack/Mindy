---
name: install-bwm
description: Use /install-bwm to set up Build With Mindy with your access code.
user-invocable: true
---

In the Claude app outside a Local Code session, do not run setup or ask for an access code. Say exactly: `Click the </> button and choose Local. Type /install-bwm with your access code there.` Then stop.

AI-facing triggers: /install-bwm, install MINDY, set up MINDY, or my MINDY access code.

Invoke this skill with no arguments. Never put an access code in the Skill tool's arguments, including when a code sent on its own triggers this skill. The code stays only in the person's chat message; only the setup script reads it.

Before asking for a code, saying anything about Manual, requesting permission or running the setup script, check the Mac with the ordinary file tools, or this plain read-only shell command inside the sandbox. It only reads the local registration and install receipts. It downloads nothing, runs no plugin script, writes nothing and needs no permission request. Never substitute a setup-script call for these reads. Keep its paths and markers internal.

```sh
bwm_root="$HOME/mindy"
bwm_record="$HOME/.mindy/install-state.json"
if [ -f "$bwm_record" ] && [ ! -L "$bwm_record" ] && grep -q '"format"[[:space:]]*:[[:space:]]*"mindy.delivery-install-state.v1"' "$bwm_record"; then
 bwm_recorded=$(sed -n 's/.*"baseRoot"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$bwm_record" | head -n 1)
 case "$bwm_recorded" in /*) bwm_root=$bwm_recorded ;; esac
fi
bwm_memory=false
for bwm_registration in "$HOME/Library/Application Support/MINDY/memories/"*.json; do
 if [ -f "$bwm_registration" ] && [ ! -L "$bwm_registration" ] && grep -q '"role"[[:space:]]*:[[:space:]]*"capture"' "$bwm_registration"; then bwm_memory=true; break; fi
done
if [ "$bwm_memory" = false ]; then
 printf '%s\n' BWM_MEMORY_FIRST
elif [ -f "$bwm_root/.mindy/release-selection/active-release.json" ] && [ ! -L "$bwm_root/.mindy/release-selection/active-release.json" ] && grep -q '"version"[[:space:]]*:[[:space:]]*"[^"]\{1,\}"' "$bwm_root/.mindy/release-selection/active-release.json"; then
 printf '%s\n' BWM_ALREADY_INSTALLED
else
 printf '%s\n' BWM_INSTALL_READY
fi
```

If using file tools, read `<home>/.mindy/install-state.json` and the active receipt it names (or `<home>/mindy/.mindy/release-selection/active-release.json` when there is no home record), and the regular JSON files in `<home>/Library/Application Support/MINDY/memories`. Apply the same tests as the command. When the capture registration is gone, TimeSaver must be set up again even if the Build With Mindy folder remains. Do not print the home folder path into a tool result.

For `BWM_MEMORY_FIRST`, use the line for this host below, then stop. No mode switch, permission request or setup call.

In the ChatGPT app, identified by `CODEX_INTERNAL_ORIGINATOR_OVERRIDE` containing `ChatGPT`: `Install MINDY TimeSaver first. Open Customize, then Plugins, then Personal, click + beside MINDY TimeSaver Setup, and type /install-mts with your access code. When it has finished, type /install-bwm with your code again.`

In Local Code in the Claude app: `Install MINDY TimeSaver first. On the speech-bubble side of the Claude app, open Customize, then Plugins, then Discover, add MINDY TimeSaver Setup, and type /install-mts with your access code on the Local Code side. When it has finished, type /install-bwm with your code again.`

In the Terminal or when the host is not known: `Install MINDY TimeSaver first. Add MINDY TimeSaver Setup where you add plugins, and type /install-mts with your access code. When it has finished, type /install-bwm with your code again.`

Check the person's latest /install-bwm message for a code before any Manual-mode step. The command may be a slash command, a plugin-prefixed slash command, or an install-bwm skill mention chip. A code has a membership number of 3 to 32 letters, digits or hyphens, a dot, and at least 40 signature characters (letters, digits, underscores or hyphens). A signature made of one repeated character counts only when it is at least 80 characters long. Let the server decide which product the code belongs to. A code sent on its own, without /install-bwm in that message, does not count.

If the person's latest message holds a code but no /install-bwm command or install-bwm skill mention, say exactly `I've received your code. Send it together with the command as one message: /install-bwm, a space and your code.` Then stop, before any Manual-mode step, permission request or setup call. Never repeat their code, and do not give the no-code sentence for this case.

For `BWM_ALREADY_INSTALLED` with no code in that message, say exactly `MINDY is already installed.` Then give only this host's next-step line to start a new chat or session and type /mindysetup from below. No mode switch, permission request or setup call.

With a code in that message, continue to the setup script for updates, repairs or adding an app, even when the folder or release receipt says MINDY is installed. Do not short-circuit this route on either file. The script checks the latest release and the apps in its record before deciding there is nothing to do.

Otherwise, if there is no code in the /install-bwm message, say exactly `This needs your MINDY access code, which came in the message with your install steps. Type /install-bwm, a space and your code, all on one line.` Then stop, before any Manual-mode step, permission request or setup call.

Only in Local Code in the Claude app, before the install command or any permission request, say exactly: `We're about to install Build With Mindy on this computer, and Auto mode can stop an install part way. So switch the mode at the bottom of the window to Manual for now, and tell me when it shows Manual. Once it's installed, you can switch back to Auto.` If the host does not already show Manual, stop this turn and wait until the person confirms Manual or the host shows it. The script will read the code from the person's earlier install message after the switch. After the successful install command, stop for the person to switch back to Auto before giving the next step below. Do not give the mode instruction in the ChatGPT app or the command-line app.

The setup script reads the newest code-shaped token from the person's own messages in this chat's file on the Mac, locating it by the current host session id as /mindysave does. It ignores assistant and tool text, and earlier-session rows in a resumed Claude file. A newer /install-bwm message with no code clears an earlier code. Never read that message through an AI tool, print the code, construct a here-document with it, put it in arguments, tool stdin, an environment assignment, a justification, a description or a log. Run this one command and relay its sentences:

```sh
<script> --code-from-chat
```

The script uses `CLAUDE_CODE_SESSION_ID` (or `CLAUDE_SESSION_ID`) in Claude Code, and `CODEX_THREAD_ID` (or `CODEX_SESSION_ID`) in the ChatGPT app. If the host supplies its current session id separately instead, append `--session-id "<current session id>"`. Use only this chat's host-provided id, never the newest file, a guessed id, another chat, or a search for the code. With no code, the script gives the no-code sentence above. When the chat file cannot be found or read, or its format is unsuitable, it says `Setup could not read your code from this chat. Start a new chat and type /install-bwm with your code there.` Relay that one sentence and stop. Never fall back to putting the code in a command or a permission request.

The script tries TimeSaver's Bun first, then the Mac's built-in JavaScript reader if Bun is missing, not executable, a symlink or unable to run. If neither reader can run, it says `MINDY TimeSaver needs repairing. Install MINDY TimeSaver again with /install-mts and your TimeSaver access code, then type /install-bwm with your code again.` Relay that sentence and stop; a new chat cannot repair TimeSaver.

Every permission title, Bash description and running line you supply is `Install Build With Mindy`. After success, use `Installed Build With Mindy`. Never call this step a download.

In Claude Code, `<script>` is `"${CLAUDE_PLUGIN_ROOT}/scripts/mindy-setup.sh"`. In Local Code in the Claude app, append `--claude-local` after `--code-from-chat`. This registers the private full plugin at user scope, using the CLI when present and the same local records when it is absent.

In the ChatGPT app (Codex), this skill's `SKILL.md` was given to you by its absolute path, and the plugin folder is two levels above the `install-bwm` skill folder, so `<script>` is `<plugin folder>/scripts/mindy-setup.sh`.

The script must run with network access and outside the sandbox: it installs Build With Mindy from MINDY's server and saves it in the person's home folder, outside the current folder. Inside the sandbox it cannot reach the server, and it would then wrongly tell the person to check they are online. Never run it inside the sandbox first to see whether it works. Run it outside the sandbox from the first try, by your app's own way of doing that: in Claude Code, whose sandbox is off unless the person turned it on, run the command with the sandbox disabled (`dangerouslyDisableSandbox: true`) only when your Bash tool's instructions describe a sandbox, and otherwise run it as an ordinary command without `dangerouslyDisableSandbox`; in the ChatGPT app (Codex), make the one request the next paragraph describes. If your app will ask the person before it runs the command, first say exactly `Setup needs to reach the internet and save MINDY in your home folder. When your app asks, allow it this once.` In Local Code in the Claude app when the current mode is Manual, always say that allow-it-this-once sentence immediately before the install command or its permission request. Otherwise, if your app can run the command outside the sandbox without asking (Codex set to never ask or to full access), just run it, without that sentence. Only if the person declines, do not run it, and say exactly `Setup needs that permission to install MINDY. Ask me again when you're ready.` In Claude Code, if the tool result says the setup command was denied by the auto mode classifier, do not run it again and do not suggest adding permission rules or changing settings; say exactly `Claude Code's auto mode stopped setup. Press Shift and Tab together until the line under the box says manual mode on. Then press the up arrow, press Return, and choose Yes (not the don't ask again option) when Claude Code asks.`

In the ChatGPT app (Codex), the app lets the command reach the internet and edit only the folders you ask for, and setup edits three folders in the person's home folder: `mindy`, where MINDY goes; `.mindy`, where setup keeps its install files and its notes; and `.codex`, where setup adds MINDY to this app. Asking for fewer stops setup part way, and asking again for each missing folder means another stop each time. So make one request, before setup runs, for the internet and all of these folders together. Resolve `<home>` from the host-provided environment or ordinary file-tool path metadata, keeping it internal. Do not run a command that prints the home folder path. Check whether Claude Code is on this Mac with this ordinary sandbox command: `if command -v claude >/dev/null 2>&1; then printf '%s\n' BWM_CLAUDE_PRESENT; fi`. That marker means setup adds MINDY to Claude Code as well, so `<home>/.claude` is a fourth folder in the same request. Then call the `request_permissions` tool once, with `{"network": {"enabled": true}, "file_system": {"write": ["<home>/mindy", "<home>/.mindy", "<home>/.codex"]}}`, adding `"<home>/.claude"` to that list when Claude Code is on this Mac. Say the sentence above about allowing it this once just before this call. The app then asks the person once to let it connect to the internet and edit those folders. Never ask for the folders one at a time. When the person allows it, run the setup command straight away, in the same turn, as an ordinary command with no `sandbox_permissions`. Only if the `request_permissions` tool is not offered to you, instead run the setup command once with escalated permissions (`sandbox_permissions: "require_escalated"`) and a one-line justification, such as `Install Build With Mindy`, which never contains the code. When Codex is set to never ask or to full access, request nothing, give no `sandbox_permissions` and just run it, as the paragraph above says.

When the script stops before it finishes, relay every line it printed, exactly as printed and in order. If it says `MINDY is already installed.`, relay that sentence and give only this host's next-step line to start a new chat or session and type /mindysetup from below.

When the script's sentence is `Build With Mindy is now in a folder called mindy in your home folder.`, relay it, then say the lines under your app's heading below, exactly, one per line, and nothing else but the pets line described after them. Relay no other line the script printed.

In Claude Code:

Next, start a new session and type /mindysetup

In the ChatGPT app (Codex):

If an anchor icon with a yellow dot shows under the message box, click it and choose Allow all.
Next, start a new chat with This computer selected and type /mindysetup

Allow all approves Build With Mindy's hooks. Keep that explanation internal unless the person asks what Allow all does.

When the script also printed the line `MINDY's Codex pet is in place.` and you are in the ChatGPT app (Codex), then after the steps above say `MINDY is now in your Codex pets list, and you can choose it there.` Without that line from the script, say nothing about a pet. Never relay the script's pet line itself.

Never print the code back. Read only the local registration and install receipts for the early checks. Only the script reads this chat for the code. Do not read or change unrelated folders.
