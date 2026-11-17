import { Box, Text } from "ink";
import type { Agent, TimelineEvent } from "../snapshot.ts";
import { COLORS, RECAP_LABELS, STATUS_COLORS } from "../theme.ts";
import { ago, clock, prLabel, prRef, truncate } from "../format.ts";
import { ProgressBar } from "./ProgressBar.tsx";

export type Columns = { width: number; indent: number };

export function columnsFor(width: number): Columns {
  return { width, indent: 4 };
}

const ACTIVITY_LINES = 2;

// Mirrors the line count AgentRow renders, for scrolling.
export function rowHeight(agent: Agent): number {
  const activity = activityEvents(agent).length > 0 ? 1 : 0;
  return 1 + (decideLine(agent) ? 1 : 0) + (headlineLine(agent) ? 1 : 0) + (agent.plan ? 1 : 0) + (reportLine(agent) ? 1 : 0) + activity + (metaLine(agent) ? 1 : 0);
}

// The question, dialog or wait, unless the title already says it.
function headlineLine(agent: Agent): string | null {
  return agent.headline && agent.headline !== agent.title && agent.headline !== agent.goal ? agent.headline : null;
}

// What the agent's last report says the user must decide, unless the headline already asks it.
function decideLine(agent: Agent): string | null {
  const decide = agent.last_report?.digest?.decide;
  return decide && !["asking", "blocked"].includes(agent.status) ? decide : null;
}

function reportLine(agent: Agent): string | null {
  const digest = agent.last_report?.digest;
  if (digest) return [digest.did && `did: ${digest.did}`, digest.now && `now: ${digest.now}`].filter(Boolean).join("  ·  ") || null;
  const text = agent.last_report?.brief;
  return text && !agent.headline.includes(text.slice(0, 40)) ? text : null;
}

// The latest outcomes, skipping the report the row already shows.
function activityEvents(agent: Agent): TimelineEvent[] {
  return agent.recap.filter((e) => !["did", "report"].includes(e.kind)).slice(0, ACTIVITY_LINES);
}

function metaLine(agent: Agent): string | null {
  const parts = [
    agent.branch,
    agent.cwd?.split("/").filter(Boolean).at(-1),
    agent.edited_files > 0 ? `${agent.edited_files} files edited` : null,
    agent.lane,
  ].filter((p): p is string => Boolean(p));
  return parts.length > 0 ? parts.join(" · ") : null;
}

function currentStep(agent: Agent): string | null {
  const step = agent.plan?.steps.find((s) => s.status === "doing") ?? agent.plan?.steps.find((s) => s.status === "todo");
  return step ? `${step.status === "doing" ? "now" : "next"}: ${step.title}` : null;
}

function ageLabel(agent: Agent, now: Date): string {
  if (agent.status === "working") return agent.stale ? "stale?" : "working";
  return ago(agent.since, now);
}

function Sep() {
  return <Text color={COLORS.rule}> · </Text>;
}

export function AgentRow({ agent, columns, isSelected, now }: { agent: Agent; columns: Columns; isSelected: boolean; now: Date }) {
  const headline = headlineLine(agent);
  const report = reportLine(agent);
  const activity = activityEvents(agent);
  const meta = metaLine(agent);
  const step = currentStep(agent);
  const pr = agent.pr ? prLabel(agent.pr) : null;
  const isParked = agent.status === "parked";
  const textColor = isParked ? COLORS.muted : COLORS.text;
  const needsYou = ["blocked", "asking", "error", "done"].includes(agent.status);
  const body = columns.width - columns.indent - 1;
  return (
    <Box flexDirection="column" width={columns.width}>
      <Box>
        <Text wrap="truncate-end">
          <Text color={isSelected ? COLORS.text : COLORS.rule}>{isSelected ? "› " : "  "}</Text>
          <Text color={STATUS_COLORS[agent.status]}>● </Text>
          <Text bold inverse={isSelected} color={textColor}>
            {agent.label}
          </Text>
          {agent.issue && (
            <>
              <Sep />
              <Text color={COLORS.blue}>{agent.issue.short}</Text>
            </>
          )}
          <Sep />
          <Text bold color={textColor}>
            {agent.title ?? "(untitled)"}
          </Text>
          {agent.pr && pr && (
            <>
              <Sep />
              <Text color={COLORS.blue}>{prRef(agent.pr)}</Text> <Text color={pr.color}>{pr.text}</Text>
            </>
          )}
          <Sep />
          <Text color={COLORS.muted}>{ageLabel(agent, now)}</Text>
        </Text>
      </Box>
      <Box flexDirection="column" paddingLeft={columns.indent}>
        {headline && <Text color={needsYou ? COLORS.orange : textColor}>{truncate(headline, body)}</Text>}
        {agent.plan && (
          <Box>
            <ProgressBar plan={agent.plan} width={16} isBlocked={agent.status === "blocked"} />
            <Text color={COLORS.muted}>
              {` ${agent.plan.done}/${agent.plan.total}`}
              {step ? `  ${truncate(step, body - 24)}` : ""}
            </Text>
          </Box>
        )}
        {decideLine(agent) && <Text color={COLORS.orange}>{truncate(`decide: ${decideLine(agent)}`, body)}</Text>}
        {report && <Text color={COLORS.muted}>{truncate(`↳ ${report}`, body)}</Text>}
        {activity.length > 0 && (
          <Text color={COLORS.muted}>{truncate(activity.map((e) => `${clock(e.at)} ${RECAP_LABELS[e.kind] ? `${RECAP_LABELS[e.kind]} ` : ""}${e.text}`).join("  ·  "), body)}</Text>
        )}
        {meta && <Text color={COLORS.rule}>{truncate(meta, body)}</Text>}
      </Box>
    </Box>
  );
}
