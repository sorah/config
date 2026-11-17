import type { GroupKey, Status } from "./snapshot.ts";

export const COLORS = {
  orange: "#f0883e",
  purple: "#a371f7",
  blue: "#58a6ff",
  green: "#3fb950",
  red: "#f85149",
  grey: "#6e7681",
  muted: "#8b949e",
  text: "#e6edf3",
  rule: "#30363d",
} as const;

export const GROUP_COLORS: Record<GroupKey, string> = {
  needs_you: COLORS.orange,
  waiting: COLORS.purple,
  working: COLORS.blue,
  idle: COLORS.grey,
  parked: COLORS.grey,
};

export const STATUS_COLORS: Record<Status, string> = {
  blocked: COLORS.orange,
  asking: COLORS.orange,
  error: COLORS.red,
  done: COLORS.orange,
  waiting: COLORS.purple,
  working: COLORS.blue,
  idle: COLORS.grey,
  parked: COLORS.grey,
};

// How recap kinds read in the timeline, matching the board's reference layout.
export const RECAP_LABELS: Record<string, string> = {
  started: "Started",
  answered: "You",
  ask: "Asked",
  decide: "Needs decision",
  did: "Report",
  report: "Report",
  message: "",
  step: "",
  plan: "",
  commit: "Commit",
  pr: "",
  check: "Check",
  link: "Linked",
  wait: "Waiting on",
  parked: "Parked",
  error: "Error",
  dispatch: "Dispatched",
  cleared: "Cleared",
};

export const TIMELINE_COLORS: Record<string, string> = {
  started: COLORS.blue,
  answered: COLORS.purple,
  did: COLORS.orange,
  decide: COLORS.orange,
  step: COLORS.blue,
  plan: COLORS.blue,
  summary: COLORS.green,
  report: COLORS.orange,
  ask: COLORS.orange,
  blocked: COLORS.orange,
  error: COLORS.red,
  wait: COLORS.purple,
  message: COLORS.purple,
  dispatch: COLORS.purple,
  pr: COLORS.text,
  commit: COLORS.green,
  check: COLORS.muted,
  link: COLORS.muted,
  prompt: COLORS.muted,
};
