import type { PullRequest } from "./snapshot.ts";
import { COLORS } from "./theme.ts";

export function ago(iso: string | null, now: Date): string {
  if (!iso) return "";
  const seconds = Math.max(0, (now.getTime() - new Date(iso).getTime()) / 1000);
  if (seconds < 60) return `${Math.floor(seconds)}s`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`;
  return `${Math.floor(seconds / 86400)}d`;
}

export function clock(iso: string): string {
  const d = new Date(iso);
  return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}

export function truncate(text: string, width: number): string {
  const line = text.replace(/\s+/g, " ").trim();
  if (width <= 1) return "";
  return line.length > width ? `${line.slice(0, width - 1)}…` : line;
}

export function prLabel(pr: PullRequest): { text: string; color: string } {
  if (pr.state === "MERGED") return { text: "merged", color: COLORS.purple };
  if (pr.state === "CLOSED") return { text: "closed", color: COLORS.muted };
  if (pr.review === "CHANGES_REQUESTED") return { text: "changes requested", color: COLORS.red };
  if (pr.ci.failed > 0) return { text: `CI ${pr.ci.failed} failed`, color: COLORS.red };
  if (pr.draft) return { text: "draft", color: COLORS.muted };
  if (pr.ci.pending > 0) return { text: "CI pending", color: COLORS.muted };
  if (pr.review === "APPROVED") return { text: "approved", color: COLORS.green };
  const total = pr.ci.passed + pr.ci.failed + pr.ci.pending;
  if (total > 0) return { text: `CI ${pr.ci.passed}/${total}`, color: COLORS.green };
  if (pr.review === "REVIEW_REQUIRED") return { text: "review requested", color: COLORS.muted };
  return { text: "open", color: COLORS.muted };
}

export function prRef(pr: PullRequest): string {
  const repo = pr.repo?.split("/")[1] ?? "";
  return `${repo}#${pr.number}`;
}
