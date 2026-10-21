---
name: timesaver-remove
description: Use /timesaver-remove to remove MINDY TimeSaver and choose whether to keep your saved sessions.
user-invocable: true
---

Never use an em dash. Name no app the person is not in. First ask exactly: `Do you want to keep your saved sessions or delete them?` Stop and wait. Make no change until they answer clearly.

In the Claude app outside Local Code, do not remove files through the cloud shell or promise that the Mac engine has been removed. Say `Removing MINDY TimeSaver has to happen on your own computer, and this chat runs somewhere else. Click the </> button, choose This computer and type /timesaver-remove there.` Retain their keep or delete choice for that step and stop.

In a local session, start the plugin's absolute `scripts/timesaver-remove.ts` path through the sh step below with `keep` or `delete`, matching their answer. This plugin script runs `scripts/bun-runtime.sh timesaver-install/runtime/remove.ts` first and performs plugin cleanup only after that succeeds. If only a confirmed `removed.json` remains, it cleans the earlier removal without running the engine or changing kept saves. Start it before removal because the runtime removes the installed Bun. In Claude Code, the app substitutes `${CLAUDE_PLUGIN_ROOT}`. In the ChatGPT app or Codex, obtain the absolute plugin path from this skill's location. When `install-state.json` is absent, use `kept-saves.json` to locate kept saves, or the default saves folder otherwise. Before this command in a restricted local session, request write access together for the recorded saves folder, its parent, the home folder's `.timesaver`, `.claude` and `.codex` folders, `~/Library/Application Support/MINDY`, and the parent of every redirect recorded in `install-state.json`. In the ChatGPT app or Codex, use `request_permissions` with those folders if offered; otherwise run with `sandbox_permissions: "require_escalated"`. In Claude Code, disable the sandbox for this command. The reason is `Remove MINDY TimeSaver and update its app settings.` Before removal in Claude Code, read `CLAUDE_CODE_ENTRYPOINT` with one ordinary command inside the sandbox (`printenv CLAUDE_CODE_ENTRYPOINT || :`) and retain the result for the closing sentence. Example for keeping saves:

```sh
/bin/sh -c '
state="${MTS_STATE_ROOT:-$HOME/.timesaver}"
bun="$state/bin/bun"
if [ ! -f "$bun" ] || [ -L "$bun" ] || [ ! -x "$bun" ]; then
 bun=$(command -v bun || :)
fi
if [ -z "$bun" ]; then
 if [ ! -e "$state/install-state.json" ] && [ ! -L "$state/install-state.json" ] && [ -f "$state/removed.json" ] && [ ! -L "$state/removed.json" ] && [ "$(/usr/bin/plutil -extract removed raw -expect bool -o - "$state/removed.json" 2>/dev/null)" = true ]; then
  printf "%s\n" "MINDY TimeSaver was already removed from this computer."
  exit 0
 fi
 exec /bin/sh "${CLAUDE_PLUGIN_ROOT}/scripts/bun-runtime.sh" timesaver-install/runtime/remove.ts "$1"
fi
exec "$bun" "${CLAUDE_PLUGIN_ROOT}/scripts/timesaver-remove.ts" "$1"
' sh keep
```

For deletion, replace `keep` with `delete`. Never delete anything by hand on a failure. Keep script diagnostics and the path-free `TIMESAVER_CLEANUP_COMPLETE` or `TIMESAVER_CLEANUP_INCOMPLETE` result internal. Only `TIMESAVER_CLEANUP_COMPLETE` confirms that cleanup left no TimeSaver remnants beyond the removal marker and any chosen kept saves. If cleanup is incomplete or no result is returned, never say that nothing of TimeSaver is left. Relay the script's already-removed sentence exactly when it prints one, followed by the existing account-step line below; on an already-removed run with incomplete cleanup, relay only `MINDY TimeSaver was already removed from this computer.` before that account step. Always relay the runtime's removal outcome when the script prints it, even if later cleanup reports a problem. When only the launcher's setup sentence is returned, relay that sentence. An earlier removal can be cleaned again using Bun on PATH; it must preserve that earlier keep or delete choice.

Keep the runtime's paths internal. Relay its removal outcome using this computer and the saves folder's plain place. Removing the engine cannot remove a plugin from a Claude account. For the closing sentence in Claude Code, use the entry point retained before removal. Only `cli` means Claude Code in the Terminal; any other value, or none, means Local Code in the Claude app. Do not choose the Terminal line merely because the host calls itself Claude Code. In the Claude app, then say: `Open Customize, then Plugins. Open MINDY TimeSaver, open its menu and choose Remove. Do the same for MINDY TimeSaver Setup. Disconnect your saves folder from this chat.` In Claude Code in the Terminal, say `Remove MINDY TimeSaver and MINDY TimeSaver Setup from your account's Plugins page too, if you added them there.` Then, only in this Terminal branch and only when the script reports `TIMESAVER_CLEANUP_COMPLETE`, say exactly: `If Claude Code still lists MINDY TimeSaver under Synced from claude.ai with Path not found, that's only Claude Code's list of your account's plugins catching up. TimeSaver itself is no longer on this computer.` Do not say this sentence when cleanup reports any part it could not remove. In the ChatGPT app or Codex, say `Remove MINDY TimeSaver and MINDY TimeSaver Setup from Plugins if they are still listed. Disconnect your saves folder from this chat if it is connected.` Never name another app. Do not claim removal is complete until the person has completed the account or app step. The shared marketplace and unrelated plugins stay in place.
