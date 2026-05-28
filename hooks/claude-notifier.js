#!/usr/bin/env node
// Claude Notifier — Unified hook dispatcher
// Consolidates 4 original hooks (on-question, on-stop, on-permission, on-prompt)
// into a single entry point dispatched via CLI argument.

const { isMuted, readConfig } = require("./_lib/config");
const { resolveSound, BUNDLED_FALLBACK } = require("./_lib/sounds");
const { playSound } = require("./_lib/play");
const { showNotification } = require("./_lib/notify");
const { writeSignal } = require("./_lib/signal");
const { buildClickAction, GENERIC_ACTIVATE } = require("./_lib/click");
const { extensionOwnsCwd } = require("./_lib/active");
const { getAncestorPids } = require("./_lib/pid");

function handleQuestion(input) {
  if (input.tool_name !== "AskUserQuestion") process.exit(0);
  if (isMuted()) process.exit(0);
  const config = readConfig();
  const cfg = config?.asksQuestion ?? {};
  const level = cfg.level ?? "sound+popup";
  const volume = config?.soundVolume ?? 1;
  if (level === "off") process.exit(0);
  if (level === "sound+popup" || level === "sound") {
    const sound = resolveSound(cfg.sound, "/System/Library/Sounds/Funk.aiff", "C:\\Windows\\Media\\Windows Notify.wav");
    playSound(sound, BUNDLED_FALLBACK.asksQuestion, volume);
  }
  if (level === "sound+popup" || level === "popup") {
    const cwd = (input && input.cwd) || process.cwd() || "";
    showNotification("Claude is asking you a question.", { preferTerminalNotifier: true, executeCmd: buildClickAction(cwd) || GENERIC_ACTIVATE });
  }
  writeSignal("question", input.session_id);
}

function handleStop(input) {
  if (input.stop_hook_active) process.exit(0);
  if (isMuted()) process.exit(0);
  const cwd = (input && input.cwd) || process.cwd() || "";
  const pidChain = getAncestorPids();
  writeSignal("done", input.session_id, cwd, pidChain);
  if (extensionOwnsCwd(cwd)) process.exit(0);
  const config = readConfig();
  const cfg = config?.taskCompleted ?? {};
  const level = cfg.level ?? "sound+popup";
  const volume = config?.soundVolume ?? 1;
  if (level === "off") process.exit(0);
  if (level === "sound+popup" || level === "sound") {
    const sound = resolveSound(cfg.sound, "/System/Library/Sounds/Hero.aiff", "C:\\Windows\\Media\\tada.wav");
    playSound(sound, BUNDLED_FALLBACK.taskCompleted, volume);
  }
  if (level === "sound+popup" || level === "popup") {
    showNotification("Claude has finished the task.", { preferTerminalNotifier: true, executeCmd: buildClickAction(cwd) || GENERIC_ACTIVATE });
  }
}

function handlePermission(input) {
  if (isMuted()) process.exit(0);
  if (input.tool_name === "AskUserQuestion") process.exit(0);
  const config = readConfig();
  const cfg = config?.needsPermission ?? {};
  const level = cfg.level ?? "sound+popup";
  const volume = config?.soundVolume ?? 1;
  if (level === "off") process.exit(0);
  if (level === "sound+popup" || level === "sound") {
    const sound = resolveSound(cfg.sound, "/System/Library/Sounds/Glass.aiff", "C:\\Windows\\Media\\Windows Notify.wav");
    playSound(sound, BUNDLED_FALLBACK.needsPermission, volume);
  }
  if (level === "sound+popup" || level === "popup") {
    const tool = input.tool_name || "a tool";
    const cwd = (input && input.cwd) || process.cwd() || "";
    showNotification(`Claude needs permission to use ${tool}.`, { preferTerminalNotifier: true, executeCmd: buildClickAction(cwd) || GENERIC_ACTIVATE });
  }
  writeSignal("input", input.session_id);
}

function handlePrompt(input) {
  writeSignal("prompt", input.session_id);
}

const HANDLERS = { question: handleQuestion, stop: handleStop, permission: handlePermission, prompt: handlePrompt };
const mode = process.argv[2];
const handler = HANDLERS[mode];
if (!handler) process.exit(0);

let raw = "";
process.stdin.setEncoding("utf-8");
process.stdin.on("data", (chunk) => (raw += chunk));
process.stdin.on("end", () => {
  let input = {};
  try { input = JSON.parse(raw); } catch { process.exit(0); }
  try { handler(input); } catch { process.exit(0); }
  process.exit(0);
});
