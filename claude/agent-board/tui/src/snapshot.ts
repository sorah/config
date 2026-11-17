// Mirrors AgentBoard::Snapshot#to_h in ../../lib/agent_board/snapshot.rb.

export type Status = "blocked" | "asking" | "error" | "done" | "waiting" | "working" | "idle" | "parked";

export type GroupKey = "needs_you" | "waiting" | "working" | "idle" | "parked";

export type TimelineEvent = {
  at: string;
  kind: string;
  text: string;
};

export type PlanStep = {
  title: string;
  status: "todo" | "doing" | "done";
  depth: number;
};

export type Plan = {
  steps: PlanStep[];
  started_at: string;
  done: number;
  total: number;
};

export type PullRequest = {
  number: number;
  url: string;
  repo: string | null;
  state: "OPEN" | "CLOSED" | "MERGED";
  draft: boolean;
  review: "APPROVED" | "CHANGES_REQUESTED" | "REVIEW_REQUIRED" | null;
  ci: { passed: number; failed: number; pending: number };
};

export type Agent = {
  id: string;
  short_id: string;
  name: string;
  label: string;
  title: string | null;
  lane: string | null;
  cwd: string | null;
  branch: string | null;
  status: Status;
  stale: boolean;
  since: string | null;
  updated_at: string;
  headline: string;
  goal: string | null;
  blockers: { kind: string; summary: string; at: string }[];
  ask: string | null;
  wait: { on: string; text: string } | null;
  error: string | null;
  plan: Plan | null;
  last_report: { text: string; at: string; source: string } | null;
  issue: { key: string; url: string | null; tracker: string; source: string; title: string | null } | null;
  pr: PullRequest | null;
  edited_files: number;
  timeline: TimelineEvent[];
  tmux: { socket: string | null; pane: string | null };
};

export type Group = {
  key: GroupKey;
  title: string;
  agents: Agent[];
};

export type Snapshot = {
  generated_at: string;
  counts: Record<GroupKey, number>;
  chief: { status: Status; since: string | null } | null;
  groups: Group[];
};
