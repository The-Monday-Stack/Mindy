// Start with the installed Bun, before the engine removes that executable.
// All cleanup code and built-in imports are loaded before invoking removal.
import { lstatSync, readFileSync, readdirSync, rmSync, rmdirSync, writeFileSync } from "node:fs";
import { dirname, join, resolve, sep } from "node:path";

function info(path: string) {
 try { return lstatSync(path); }
 catch (error) { if ((error as NodeJS.ErrnoException).code === "ENOENT") return undefined; throw error; }
}
function noLinkedParents(path: string): void {
 for (let parent = dirname(path); ; parent = dirname(parent)) {
  const entry = info(parent);
  if (entry && (entry.isSymbolicLink() || !entry.isDirectory())) throw new Error(`TIMESAVER_CLEANUP_UNSAFE_PARENT: ${parent}`);
  if (parent === dirname(parent)) return;
 }
}
function emptyDirectory(path: string, owned: boolean): void {
 noLinkedParents(path);
 const entry = info(path);
 if (!entry || entry.isSymbolicLink() || !entry.isDirectory()) return;
 const names = readdirSync(path);
 if (owned && names.length === 1 && names[0] === ".DS_Store" && info(join(path, ".DS_Store"))?.isFile()) rmSync(join(path, ".DS_Store"));
 try { rmdirSync(path); }
 catch (error) { if (!["ENOENT", "ENOTEMPTY", "EEXIST"].includes((error as NodeJS.ErrnoException).code!)) throw error; }
}

// Preserve every byte outside our complete hook-approval tables. Compare the
// parsed result too, so a header inside a multiline TOML string cannot qualify.
function withoutHookApprovals(before: string): string {
 const expected = Bun.TOML.parse(before) as any;
 const owned = /^(?:timesaver@(?:mindy|mindy-memory)|mindy-timesaver-access@mindy):hooks\/hooks-codex\.json:(?:pre_compact|session_start):\d+:\d+$/;
 for (const key of Object.keys(expected.hooks?.state ?? {})) if (owned.test(key)) delete expected.hooks.state[key];
 const lines = before.match(/[^\n]*\n|[^\n]+$/g) ?? [];
 let skipping = false;
 const kept: string[] = [];
 for (const line of lines) {
  if (/^\s*\[/.test(line)) {
   const header = line.trim().match(/^\[\s*hooks\s*\.\s*state\s*\.\s*("(?:[^"\\]|\\.)*"|'[^']*')\s*\]\s*(?:#.*)?$/);
   const key = header ? (header[1]!.startsWith('"') ? JSON.parse(header[1]!) : header[1]!.slice(1, -1)) : "";
   skipping = owned.test(key);
  }
  if (!skipping) kept.push(line);
 }
 const after = kept.join("");
 const actual = Bun.TOML.parse(after) as any;
 // TOML's implicit parent tables disappear when their last child is removed.
 function dropEmptyHookParents(value: any) {
  if (value.hooks?.state && !Object.keys(value.hooks.state).length) delete value.hooks.state;
  if (value.hooks && !Object.keys(value.hooks).length) delete value.hooks;
 }
 dropEmptyHookParents(expected); dropEmptyHookParents(actual);
 if (JSON.stringify(actual) !== JSON.stringify(expected)) throw new Error("TIMESAVER_CLEANUP_HOOK_TABLE_NOT_ISOLATED");
 return after;
}

function run(): void {
 const mode = process.argv[2];
 if (mode !== "keep" && mode !== "delete") throw new Error("Do you want to keep your saved sessions or delete them?");
 if (!process.env.HOME) throw new Error("TIMESAVER_CLEANUP_HOME_MISSING");
 const home = resolve(process.env.HOME), stateRoot = resolve(process.env.MTS_STATE_ROOT ?? join(home, ".timesaver"));
 const statePath = join(stateRoot, "install-state.json");
 noLinkedParents(statePath);
 if (info(statePath)?.isSymbolicLink()) throw new Error("TIMESAVER_CLEANUP_LINKED_STATE");
 const removedPath = join(stateRoot, "removed.json");
 const retry = !info(statePath);
 if (retry && (!info(removedPath) || info(removedPath)?.isSymbolicLink() || JSON.parse(readFileSync(removedPath, "utf8")).removed !== true)) {
  throw new Error("MINDY TimeSaver isn't fully set up on this computer yet. Type /install-mts to finish, then try again.");
 }
 // An earlier removal has no install record. Never run the engine again or
 // apply the new answer to kept saves. Only prune known plugin remnants.
 const keptPath = join(stateRoot, "kept-saves.json");
 noLinkedParents(keptPath);
 if (info(keptPath)?.isSymbolicLink()) throw new Error("TIMESAVER_CLEANUP_LINKED_STATE");
 const kept = retry && info(keptPath) ? JSON.parse(readFileSync(keptPath, "utf8")) : undefined;
 const state = retry ? { contentRoot: kept?.contentRoot ?? join(home, "timesaver"), managedPaths: [] } : JSON.parse(readFileSync(statePath, "utf8"));
 // The engine validates the install snapshot before deleting. A cleanup-only
 // retry has no engine, so check its kept-folder record here.
 if (retry && kept && (kept.product !== "mts" || typeof kept.contentRoot !== "string" || !kept.contentRoot.startsWith("/"))) throw new Error("TIMESAVER_CLEANUP_INVALID_KEPT_SAVES");
 const content = resolve(state.contentRoot);
 if (retry) {
  if (content === home || content === dirname(content) || content === stateRoot || content.startsWith(stateRoot + sep) || stateRoot.startsWith(content + sep)) throw new Error("TIMESAVER_CLEANUP_INVALID_CONTENT_ROOT");
  if (kept) {
   const marker = join(content, "timesaver.json");
   noLinkedParents(marker);
   if (info(marker)?.isSymbolicLink()) throw new Error("TIMESAVER_CLEANUP_LINKED_STATE");
   const value = JSON.parse(readFileSync(marker, "utf8"));
   if (value.product !== "mts" || value.format !== "mts.connected-folder.v1") throw new Error("TIMESAVER_CLEANUP_INVALID_KEPT_SAVES");
  }
 }
 const targets = [join(content, ".timesaver/settings.local.json")];
 const empty = new Set<string>([join(content, ".timesaver"), join(content, "MY-MIND/MY-PERCEPTION"), join(content, "MY-MIND"), ...((retry ? !kept : mode === "delete") ? [content] : [])]);
 if (retry) {
  // Old engines removed their files but left the surrounding folders.
  function collectEmpty(folder: string): void {
   noLinkedParents(folder);
   const entry = info(folder);
   if (!entry?.isDirectory() || entry.isSymbolicLink()) return;
   empty.add(folder);
   for (const name of readdirSync(folder)) if (info(join(folder, name))?.isDirectory()) collectEmpty(join(folder, name));
  }
  for (const relative of ["bin", "timesaver-install", "MY-MIND/MY-SYSTEM"]) collectEmpty(join(content, relative));
 }
 for (const relative of state.managedPaths) {
  let parent = dirname(resolve(content, relative));
  while (parent.startsWith(content + sep)) { empty.add(parent); parent = dirname(parent); }
 }
 for (const app of [".claude", ".codex"]) for (const market of ["mindy", "mindy-memory", "timesaver-marketplace", "timesaver"]) {
  const parent = join(home, app, "plugins/cache", market);
  for (const plugin of ["timesaver", "mindy-timesaver-access"]) targets.push(join(parent, plugin));
  empty.add(parent);
 }
 for (const id of ["timesaver-mindy", "timesaver-inline", "timesaver-synced", "mindy-timesaver-access-synced"]) targets.push(join(home, ".claude/plugins/data", id));
 const synced = join(home, ".claude/plugins/synced");
 noLinkedParents(join(synced, "entry"));
 if (info(synced)?.isDirectory()) for (const id of readdirSync(synced)) {
  const account = join(synced, id);
  if (info(account)?.isSymbolicLink() || !info(account)?.isDirectory()) continue;
  // Leave Claude Code's manifest, marketplace and sync-round records alone.
  for (const name of readdirSync(account)) {
   const match = name.match(/^((?:timesaver|mindy-timesaver-access)(?:~g[0-9]+)?)(?:\.meta\.json)?$/);
   if (!match) continue;
   const plugin = join(account, match[1]!), meta = plugin + ".meta.json";
   try {
    if (!info(meta)?.isFile() || info(meta)?.isSymbolicLink()) continue;
    if (JSON.parse(readFileSync(meta, "utf8")).marketplace_name?.toLowerCase() === "mindy") targets.push(plugin, meta);
   } catch { /* An unconfirmed copy belongs to the app, not to this cleanup. */ }
  }
 }
 const memories = join(home, "Library/Application Support/MINDY/memories");
 empty.add(memories); empty.add(dirname(memories));
 const config = join(home, ".codex/config.toml");
 for (const path of [...targets, ...empty, config]) noLinkedParents(path);
 if (info(config)?.isSymbolicLink()) throw new Error("TIMESAVER_CLEANUP_LINKED_CONFIG");
 const configBefore = info(config) ? readFileSync(config, "utf8") : undefined;
 const configAfter = configBefore === undefined ? undefined : withoutHookApprovals(configBefore);
 const removed = retry ? undefined : Bun.spawnSync(["/bin/sh", join(import.meta.dir, "bun-runtime.sh"), "timesaver-install/runtime/remove.ts", mode], { stdout: "pipe", stderr: "pipe" });
 if (removed && removed.exitCode !== 0) {
  process.stdout.write(removed.stdout); process.stderr.write(removed.stderr); process.exit(removed.exitCode || 1);
 }
 // Once the marker confirms removal, cleanup cannot change that outcome.
 if (info(removedPath)?.isSymbolicLink() || JSON.parse(readFileSync(removedPath, "utf8")).removed !== true) throw new Error("TIMESAVER_CLEANUP_REMOVAL_NOT_CONFIRMED");
 let cleanupComplete = true;
 function bestEffort(action: () => void): void {
  try { action(); }
  catch (error) { cleanupComplete = false; process.stderr.write(`TIMESAVER_CLEANUP: ${(error as Error).message}\n`); }
 }
 if (removed) { process.stdout.write(removed.stdout); process.stderr.write(removed.stderr); }
 // The app's plugin manager may have edited config during removal. Re-read it
// now and remove only our approvals from that current version.
 bestEffort(() => {
 if (configAfter !== undefined && info(config)) {
  noLinkedParents(config);
  if (info(config)?.isSymbolicLink()) throw new Error("TIMESAVER_CLEANUP_LINKED_CONFIG");
  const current = readFileSync(config, "utf8"), cleaned = withoutHookApprovals(current);
  if (cleaned !== current) writeFileSync(config, cleaned);
 }
 });
 for (const path of new Set(targets)) bestEffort(() => { noLinkedParents(path); rmSync(path, { recursive: true, force: true }); });
 for (const path of [...empty].sort((a, b) => b.split(sep).length - a.split(sep).length)) bestEffort(() => emptyDirectory(path, path === content || path.startsWith(content + sep) || path === memories || path === dirname(memories)));
 // Path-free, internal result for the skill's conditional closing sentence.
 process.stderr.write(cleanupComplete ? "TIMESAVER_CLEANUP_COMPLETE\n" : "TIMESAVER_CLEANUP_INCOMPLETE\n");
 if (retry) process.stdout.write(cleanupComplete
  ? "MINDY TimeSaver was already removed from this computer, and I've now cleared what it left behind.\n"
  : "MINDY TimeSaver was already removed from this computer.\n");
}
try { run(); }
catch (error) { process.stderr.write(`${(error as Error).message}\n`); process.exit(1); }
