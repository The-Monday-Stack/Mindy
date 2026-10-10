---
name: install-bwm
description: Use when the person says /install-bwm, install MINDY, set up MINDY, or my MINDY access code.
---

In the Claude app outside a Local Code session, do not run setup or ask for an access code. Say exactly: `Click the </> button and choose Local. Type /install-bwm with your access code there.` Then stop.

If the person has not given a code, say exactly one of these and stop.

In Claude Code: `This needs your MINDY access code, which came in the message with your install steps. Type /install-bwm, a space and your code, all on one line.`

In the ChatGPT app (Codex): `This needs your MINDY access code, which came in the message with your install steps. Type /install-bwm, a space and your code, all on one line.`

Only in Local Code in the Claude app, before the download command or any permission request, say exactly: `Switch the mode at the bottom of the window to Manual for the download step, then back to Auto straight after the download finishes.` If the host does not already show Manual, stop this turn and wait until the person confirms Manual or the host shows it. Retain the supplied code for that download. After the successful download and install command, stop for the person to switch back to Auto before giving the next step below. Do not give the mode instruction in the ChatGPT app or the command-line app.

With a code, the script reads it from standard input, so the code never appears in its arguments. Run this through the ordinary shell tool as one command of three lines, with the code alone on the middle line, and relay its sentences:

```
<script> --code-on-stdin <<'MINDY_CODE'
<code>
MINDY_CODE
```

In Claude Code, `<script>` is `"${CLAUDE_PLUGIN_ROOT}/scripts/mindy-setup.sh"`. In Local Code in the Claude app, append `--claude-local` after `--code-on-stdin`. This registers the private full plugin at user scope, using the CLI when present and the same local records when it is absent.

In the ChatGPT app (Codex), this skill's `SKILL.md` was given to you by its absolute path, and the plugin folder is two levels above the `install-bwm` skill folder, so `<script>` is `<plugin folder>/scripts/mindy-setup.sh`.

The script must run with network access and outside the sandbox: it downloads MINDY from MINDY's download server and saves it in the person's home folder, outside the current folder. Inside the sandbox it cannot reach the server, and it would then wrongly tell the person to check they are online. Never run it inside the sandbox first to see whether it works. Run it outside the sandbox from the first try, by your app's own way of doing that: in Claude Code, whose sandbox is off unless the person turned it on, run the command with the sandbox disabled (`dangerouslyDisableSandbox: true`) only when your Bash tool's instructions describe a sandbox, and otherwise run it as an ordinary command without `dangerouslyDisableSandbox`; in the ChatGPT app (Codex), make the one request the next paragraph describes. If your app will ask the person before it runs the command, first say exactly `Setup needs to reach the internet and save MINDY in your home folder. When your app asks, allow it this once.` In Local Code in the Claude app when the current mode is Manual, always say that allow-it-this-once sentence immediately before the download command or its permission request. Otherwise, if your app can run the command outside the sandbox without asking (Codex set to never ask or to full access), just run it, without that sentence. Only if the person declines, do not run it, and say exactly `Setup needs that permission to install MINDY. Ask me again when you're ready.` In Claude Code, if the tool result says the setup command was denied by the auto mode classifier, do not run it again and do not suggest adding permission rules or changing settings; say exactly `Claude Code's auto mode stopped setup. Press Shift and Tab together until the line under the box says manual mode on. Then press the up arrow, press Return, and choose Yes (not the don't ask again option) when Claude Code asks.`

In the ChatGPT app (Codex), the app lets the command reach the internet and edit only the folders you ask for, and setup edits three folders in the person's home folder: `mindy`, where MINDY goes; `.mindy`, where setup keeps its download and its notes; and `.codex`, where setup adds MINDY to this app. Asking for fewer stops setup part way, and asking again for each missing folder means another stop each time. So make one request, before setup runs, for the internet and all of these folders together. First, with one ordinary command inside the sandbox, which asks the person nothing, find the full path of the person's home folder and whether Claude Code is on this Mac too: `printf '%s\n' "$HOME"; command -v claude || :`. Its first line is `<home>`. A second line means Claude Code is on this Mac and setup adds MINDY to it as well, so `<home>/.claude` is a fourth folder in the same request. Then call the `request_permissions` tool once, with `{"network": {"enabled": true}, "file_system": {"write": ["<home>/mindy", "<home>/.mindy", "<home>/.codex"]}}`, adding `"<home>/.claude"` to that list when Claude Code is on this Mac. Say the sentence above about allowing it this once just before this call. The app then asks the person once to let it connect to the internet and edit those folders. Never ask for the folders one at a time. When the person allows it, run the setup command straight away, in the same turn, as an ordinary command with no `sandbox_permissions`. Only if the `request_permissions` tool is not offered to you, instead run the setup command once with escalated permissions (`sandbox_permissions: "require_escalated"`) and a one-line justification, such as `Install MINDY: download it and save it in the home folder.`, which never contains the code. When Codex is set to never ask or to full access, request nothing, give no `sandbox_permissions` and just run it, as the paragraph above says.

When the script stops before it finishes, or says MINDY is already installed, relay every line it printed, exactly as printed and in order.

When the script's sentence is `MINDY is now in <folder>`, relay it, then say the lines under your app's heading below, exactly, one per line, and nothing else but the pets line described after them. Relay no other line the script printed.

In Claude Code:

Next, start a new session and type /mindysetup

In the ChatGPT app (Codex):

Click the anchor icon at the bottom of the chat, then Allow all to approve Build With MINDY's hooks. Let me know when you've done that.
Next, start a new chat with This computer selected and type /mindysetup

When the script also printed the line `MINDY's Codex pet is in place.` and you are in the ChatGPT app (Codex), then after the steps above say `MINDY is now in your Codex pets list, and you can choose it there.` Without that line from the script, say nothing about a pet. Never relay the script's pet line itself.

Never print the code back. Never read or change any other folder.
