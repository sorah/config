import { Box, Text } from "ink";
import type { Agent, TimelineEvent } from "../snapshot.ts";
import { COLORS, STATUS_COLORS } from "../theme.ts";
import { ago, clock, prLabel, prRef, truncate } from "../format.ts";
import { ProgressBar } from "./ProgressBar.tsx";

export type Columns = { label: number; issue: number; title: number; links: number; right: number; body: number };

export function columnsFor(width: number): Columns {
  const label = 22;
  const issue = 24;
  const right = 9;
  const links = Math.min(28, Math.max(16, Math.floor(width * 0.2)));
  const title = Math.max(10, width - label - issue - links - right - 2);
  return { label, issue, title, links, right, body: issue + title + links };
}

// Mirrors the line count AgentRow renders, for scrolling.
export function rowHeight(agent: Agent): number {
  return 1 + (headlineLine(agent) ? 1 : 0) + (agent.plan ? 1 : 0) + (reportLine(agent) ? 1 : 0) + (activityLine(agent) ? 1 : 0);
}

// The status line under the header: the question, dialog or wait, unless the title already says it.
function headlineLine(agent: Agent): string | null {
  return agent.headline && agent.headline !== agent.title && agent.headline !== agent.goal ? agent.headline : null;
}

function reportLine(agent: Agent): string | null {
  const text = agent.last_report?.brief;
  return text && !agent.headline.includes(text.slice(0, 40)) ? text : null;
}

// The newest timeline event that adds something beyond the prompt and the report line.
function activityLine(agent: Agent): TimelineEvent | null {
  return agent.timeline.find((e) => !["prompt", "summary", "report"].includes(e.kind)) ?? null;
}

function rightLabel(agent: Agent, now: Date): string {
  if (agent.status === "working") return agent.stale ? "stale?" : "working";
  return ago(agent.since, now);
}

function BodyLine({ columns, color, text }: { columns: Columns; color: string; text: string }) {
  return (
    <Box>
      <Box width={columns.label} />
      <Text color={color}>{truncate(text, columns.body - 1)}</Text>
    </Box>
  );
}

export function AgentRow({ agent, columns, isSelected, now }: { agent: Agent; columns: Columns; isSelected: boolean; now: Date }) {
  const headline = headlineLine(agent);
  const report = reportLine(agent);
  const activity = activityLine(agent);
  const label = agent.pr ? prLabel(agent.pr) : null;
  const isParked = agent.status === "parked";
  const textColor = isParked ? COLORS.muted : COLORS.text;
  const needsYou = ["blocked", "asking", "error", "done"].includes(agent.status);
  return (
    <Box flexDirection="column">
      <Box>
        <Box width={columns.label}>
          <Text color={isSelected ? COLORS.text : COLORS.rule}>{isSelected ? "› " : "  "}</Text>
          <Text color={STATUS_COLORS[agent.status]}>● </Text>
          <Text bold={isSelected} inverse={isSelected} color={textColor}>
            {truncate(agent.label, columns.label - 5)}
          </Text>
        </Box>
        <Box width={columns.issue}>
          <Text color={COLORS.blue}>{agent.issue ? truncate(agent.issue.short, columns.issue - 1) : ""}</Text>
        </Box>
        <Box width={columns.title}>
          <Text bold color={textColor}>
            {truncate(agent.title ?? "(untitled)", columns.title - 1)}
          </Text>
        </Box>
        <Box width={columns.links}>
          {agent.pr && label ? (
            <Text>
              <Text color={COLORS.blue}>{prRef(agent.pr)}</Text> <Text color={label.color}>{truncate(label.text, columns.links - prRef(agent.pr).length - 2)}</Text>
            </Text>
          ) : (
            <Text color={COLORS.muted}>—</Text>
          )}
        </Box>
        <Box width={columns.right} justifyContent="flex-end">
          <Text color={COLORS.muted}>{rightLabel(agent, now)}</Text>
        </Box>
      </Box>
      {headline && <BodyLine columns={columns} color={needsYou ? COLORS.orange : textColor} text={headline} />}
      {agent.plan && (
        <Box>
          <Box width={columns.label} />
          <ProgressBar plan={agent.plan} width={20} isBlocked={agent.status === "blocked"} />
          <Text color={COLORS.muted}>
            {" "}
            {agent.plan.done}/{agent.plan.total}
          </Text>
        </Box>
      )}
      {report && <BodyLine columns={columns} color={COLORS.muted} text={`↳ ${report}`} />}
      {activity && <BodyLine columns={columns} color={COLORS.muted} text={`${clock(activity.at)} ${activity.kind} ${activity.text}`} />}
    </Box>
  );
}
