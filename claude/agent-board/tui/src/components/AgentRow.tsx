import { Box, Text } from "ink";
import type { Agent, TimelineEvent } from "../snapshot.ts";
import { COLORS, STATUS_COLORS } from "../theme.ts";
import { ago, clock, prLabel, prRef, truncate } from "../format.ts";
import { ProgressBar } from "./ProgressBar.tsx";

export type Columns = { name: number; headline: number; links: number; right: number };

export function columnsFor(width: number): Columns {
  const name = 22;
  const right = 9;
  const links = Math.min(30, Math.max(16, Math.floor(width * 0.22)));
  return { name, right, links, headline: Math.max(10, width - name - links - right - 4) };
}

// Mirrors the line count AgentRow renders, for scrolling.
export function rowHeight(agent: Agent): number {
  return 1 + (secondLine(agent) || agent.issue ? 1 : 0) + (agent.plan ? 1 : 0) + (reportLine(agent) ? 1 : 0) + (activityLine(agent) ? 1 : 0);
}

function reportLine(agent: Agent): string | null {
  const text = agent.last_report?.text;
  return text && !agent.headline.includes(text.slice(0, 40)) ? text : null;
}

// The newest timeline event that adds something beyond the prompt and the report line.
function activityLine(agent: Agent): TimelineEvent | null {
  return agent.timeline.find((e) => !["prompt", "summary", "report"].includes(e.kind)) ?? null;
}

function secondLine(agent: Agent): string | null {
  return agent.goal && agent.goal !== agent.headline ? agent.goal : null;
}

function rightLabel(agent: Agent, now: Date): string {
  if (agent.status === "working") return agent.stale ? "stale?" : "working";
  return ago(agent.since, now);
}

export function AgentRow({ agent, columns, isSelected, now }: { agent: Agent; columns: Columns; isSelected: boolean; now: Date }) {
  const goal = secondLine(agent);
  const report = reportLine(agent);
  const activity = activityLine(agent);
  const label = agent.pr ? prLabel(agent.pr) : null;
  const isParked = agent.status === "parked";
  const headlineColor = isParked ? COLORS.muted : COLORS.text;
  return (
    <Box flexDirection="column">
      <Box>
        <Box width={columns.name}>
          <Text color={isSelected ? COLORS.text : COLORS.rule}>{isSelected ? "› " : "  "}</Text>
          <Text color={STATUS_COLORS[agent.status]}>● </Text>
          <Text bold={isSelected} inverse={isSelected} color={headlineColor}>
            {truncate(agent.name, columns.name - 5)}
          </Text>
        </Box>
        <Box width={columns.headline}>
          <Text color={headlineColor}>{truncate(agent.headline, columns.headline - 1)}</Text>
        </Box>
        <Box width={columns.links}>
          {agent.pr && label ? (
            <Text>
              <Text color={COLORS.blue}>{prRef(agent.pr)}</Text> <Text color={label.color}>{truncate(label.text, columns.links - prRef(agent.pr).length - 2)}</Text>
            </Text>
          ) : (
            <Text color={COLORS.muted}>{agent.issue ? "" : "—"}</Text>
          )}
        </Box>
        <Box width={columns.right} justifyContent="flex-end">
          <Text color={COLORS.muted}>{rightLabel(agent, now)}</Text>
        </Box>
      </Box>
      {(goal || agent.issue) && (
        <Box>
          <Box width={columns.name} />
          <Box width={columns.headline}>
            <Text color={COLORS.muted}>{goal ? truncate(goal, columns.headline - 1) : ""}</Text>
          </Box>
          <Box width={columns.links}>
            <Text color={COLORS.blue}>{agent.issue ? truncate(agent.issue.key, columns.links - 1) : ""}</Text>
          </Box>
        </Box>
      )}
      {agent.plan && (
        <Box>
          <Box width={columns.name} />
          <ProgressBar plan={agent.plan} width={20} isBlocked={agent.status === "blocked"} />
          <Text color={COLORS.muted}>
            {" "}
            {agent.plan.done}/{agent.plan.total}
          </Text>
        </Box>
      )}
      {report && (
        <Box>
          <Box width={columns.name} />
          <Text color={COLORS.muted}>{truncate(`↳ ${report}`, columns.headline + columns.links - 1)}</Text>
        </Box>
      )}
      {activity && (
        <Box>
          <Box width={columns.name} />
          <Text color={COLORS.muted}>{truncate(`${clock(activity.at)} ${activity.kind} ${activity.text}`, columns.headline + columns.links - 1)}</Text>
        </Box>
      )}
    </Box>
  );
}
