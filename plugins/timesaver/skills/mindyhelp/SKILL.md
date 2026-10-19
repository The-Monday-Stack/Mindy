---
name: mindyhelp
description: Use /mindyhelp for the short how-to, what MINDY TimeSaver can do or moving your saves folder.
user-invocable: true
---

Use commas, colons or full stops in every reply to the person. Never use an em dash.

When the person asks in plain words to move their saves folder, ask for the destination if they have not given it. In the Claude app outside Local Code, say exactly: `Moving your saves folder has to happen on your own computer, and this chat runs somewhere else. Click the </> button, choose This computer, and ask me there.` Keep their destination for that step and stop. In a local session, run `"$HOME/.timesaver/plugin-marketplace/plugins/timesaver/scripts/bun-runtime.sh" timesaver-install/runtime/move.ts "<destination>"`. Request write permission for the current saves folder, its parent, the destination's parent and the home folder's `.timesaver` folder before running in a restricted session. The destination can be outside the home folder, on another disk or inside a cloud-synced folder. Its parent must be reachable. If the destination holds other files, the saves go in a timesaver folder inside it. A timesaver folder already there stops the move. The command waits for active workers. Its success line names the new location as a full path: keep that path internal. Say `Your saves are now <folder-place>.` and relay any other line it prints exactly. Only in Local Code in the Claude app, append `In any NEW chat, click + beside the message box, choose Add folder, and pick your saves folder <folder-place>.` Replace `<folder-place>` with the new location in plain words, the way setup says it: `in a folder called timesaver in your home folder`, `on your Desktop, in a folder called timesaver`, `in your Documents, in a folder called timesaver`, `in your Google Drive, inside Work, in a folder called timesaver`, or `on <disk name>, in a folder called timesaver`. Never print a full path. Stop without setup or saving. Never move the folder by hand.

If the person asks what MINDY TimeSaver can do, or chooses "show me what it can do", say exactly:

> MINDY TimeSaver saves what you asked, decided and did, so your AI can pick up earlier work.
>
> Type /mindyend at the end of a session to save it.
> Use /mindysave to keep the words of a chat.
> Use /mindyload to give your AI all the context it needs for any work you've saved.
> Use /mindysearch to search for anything in your TimeSaver.
> Use /mindyteam to send a bug report, give feedback or ask a question.
> Use /mindyhelp for a reminder of these instructions.
>
> Use /timesaver-off to stop saving, /timesaver-on to switch it back on, or /timesaver-remove to remove MINDY TimeSaver.
>
> 1. It's simple - just one command at the end of the chat and everything you and your AI needs to remember is right there whenever you need it.
> 2. The more sessions you TimeSave, the more time you save to get a fresh AI chat up to speed. One quick /mindyload and Mindy finds all the crucial context.
> 3. Your TimeSaver is a carefully curated set of files on your computer which you can copy, sync and save anywhere. Your context remains yours alone.
> 4. Mindy TimeSaver works with Claude, ChatGPT Work/Codex, Pi and Hermes (more coming soon.) So you can use the same TimeSaves with any AI and you're not held captive by any corporation's context capture policy.
>
> All your TimeSaves stay in your own folder on this computer.

 Stop without running a command or describing another app.

For /mindyhelp, show only these lines, exactly. Do not run a command or change anything.

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

<!-- MIKE'S WEBSITE AND OFFERS: BEGIN -->

<!-- MIKE'S WEBSITE AND OFFERS: END -->
