---
name: timesaver-reports-on
description: Use /timesaver-reports-on to allow MINDY TimeSaver bug reports while saving is on.
---

Use commas, colons or full stops in every reply to the person. Never use an em dash, including in lists and save confirmations.

In the Claude app outside Local Code, say `This chat never sends bug reports by itself, so there's nothing to switch here.` and stop without running a local command.

In Claude Code, run the commands below as written: the app replaces `${CLAUDE_PLUGIN_ROOT}` in this skill's text with the installed plugin's absolute path before you see it. It is not a Bash environment variable. In the ChatGPT app and Codex, replace `${CLAUDE_PLUGIN_ROOT}` in each command with the absolute plugin path obtained by moving up two directories from the folder containing this `SKILL.md` supplied by the app. Run that quoted absolute command directly, without setting a shell variable or changing folders.

Permission reason: `Change your MINDY TimeSaver bug reports setting on this computer.`

In the ChatGPT app and Codex with workspace file restrictions, request write permission before the first engine command, never after a blocked attempt. Read the full home path with `printf '%s\n' "$HOME"` and the current saves path with `(cd "$HOME/.timesaver" && "$HOME/.timesaver/bin/bun" -e 'process.stdout.write((await Bun.file(process.argv[1]).json()).contentRoot)' "$HOME/.timesaver/install-state.json")`. If `request_permissions` is available, request only `{"file_system":{"write":["<home>/.timesaver"]}}`. The saves path is read only; this command writes only the local reports setting and its lock and temporary file. Use the Permission reason above as the request reason. After approval, run the engine command normally in the same turn. If the tool is unavailable, run the first engine command with `sandbox_permissions: "require_escalated"` and that same justification. When file access is already unrestricted, run normally without another request. Never request network access for changing this setting. A declined permission is not an engine failure: do not report a bug or claim success. Say exactly: `No problem, nothing has been changed, so your bug reports setting is still just as it was. Whenever you'd like to switch bug reports on, simply type /timesaver-reports-on again and allow it when asked.` Then stop.

Run:

```sh
"${CLAUDE_PLUGIN_ROOT}/scripts/bun-runtime.sh" timesaver-install/runtime/privacy.ts reports-on
```

Relay the result exactly. If the result has a line that is only `MTS_SAVE_REFUSED`, leave that line out and relay every other line exactly. This changes the setting for both apps and every folder. Nothing already saved is deleted. Do not read or save the session as part of this command.
