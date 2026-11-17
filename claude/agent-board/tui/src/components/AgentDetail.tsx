import { Box, Text } from "ink";
import type { ReactNode } from "react";
import type { Agent } from "../snapshot.ts";
import { COLORS, TIMELINE_COLORS } from "../theme.ts";
import { ago, clock, prLabel, prRef, truncate } from "../format.ts";
import { ProgressBar } from "./ProgressBar.tsx";

const TIMELINE_ROWS = 8;
const STEP_MARKS = { done: "✓", doing: "◐", todo: "○" } as const;
const STEP_COLORS = { done: COLORS.green, doing: COLORS.blue, todo: COLORS.muted } as const;

export function detailHeight(agent: Agent, isWide: boolean, isTimelineExpanded: boolean): number {
  const plan = agent.plan ? agent.plan.steps.length + 2 : 0;
  const reportText = agent.last_report ? (isTimelineExpanded ? agent.last_report.text : agent.last_report.brief) : "";
  const report = agent.last_report ? Math.ceil(reportText.length / 60) + reportText.split("\n").length + 2 : 0;
  const timeline = Math.min(agent.timeline.length, isTimelineExpanded ? agent.timeline.length : TIMELINE_ROWS) + 2;
  const facts = 7;
  return (isWide ? Math.max(plan + report, timeline + facts) : plan + report + timeline + facts) + 1;
}

function Heading({ children }: { children: string }) {
  return (
    <Text bold color={COLORS.muted}>
      {children}
    </Text>
  );
}

function PlanSection({ agent, now }: { agent: Agent; now: Date }) {
  const plan = agent.plan;
  if (!plan) return null;
  const percent = Math.round((plan.done / Math.max(plan.total, 1)) * 100);
  return (
    <Box flexDirection="column" marginBottom={1}>
      <Box>
        <Heading>PLAN </Heading>
        <ProgressBar plan={plan} width={24} isBlocked={agent.status === "blocked"} />
        <Text>
          {" "}
          {percent}% <Text color={COLORS.muted}>
            {plan.done}/{plan.total} · {ago(plan.started_at, now)}
          </Text>
        </Text>
      </Box>
      {plan.steps.map((step, i) => (
        <Box key={i} marginLeft={step.depth * 2}>
          <Text color={STEP_COLORS[step.status]}>{STEP_MARKS[step.status]} </Text>
          <Text color={step.status === "done" ? COLORS.muted : COLORS.text}>{step.title}</Text>
        </Box>
      ))}
    </Box>
  );
}

function ReportSection({ agent, isExpanded }: { agent: Agent; isExpanded: boolean }) {
  const report = agent.last_report;
  if (!report) return null;
  const isShortened = report.brief !== report.text.replace(/\s+/g, " ").trim();
  return (
    <Box flexDirection="column">
      <Heading>{`LAST REPORT · ${clock(report.at)}`}</Heading>
      {isExpanded || !report.digest ? (
        <Text>{isExpanded ? report.text : report.brief}</Text>
      ) : (
        <>
          {report.digest.did && <Text>{`did: ${report.digest.did}`}</Text>}
          {report.digest.now && <Text>{`now: ${report.digest.now}`}</Text>}
          {report.digest.decide && <Text color={COLORS.orange}>{`decide: ${report.digest.decide}`}</Text>}
        </>
      )}
      {!isExpanded && isShortened && <Text color={COLORS.muted}>m: full report</Text>}
    </Box>
  );
}

function TimelineSection({ agent, width, isExpanded }: { agent: Agent; width: number; isExpanded: boolean }) {
  const shown = isExpanded ? agent.timeline : agent.timeline.slice(0, TIMELINE_ROWS);
  const hidden = agent.timeline.length - shown.length;
  return (
    <Box flexDirection="column" marginBottom={1}>
      <Heading>TIMELINE</Heading>
      {shown.map((event, i) => (
        <Box key={i}>
          <Text color={TIMELINE_COLORS[event.kind] ?? COLORS.muted}>● </Text>
          <Text color={COLORS.muted}>{clock(event.at)} </Text>
          <Text>{truncate(`${event.kind === "summary" ? "" : `${event.kind} `}${event.text}`, width - 9)}</Text>
        </Box>
      ))}
      {hidden > 0 && <Text color={COLORS.muted}>{`  m: show ${hidden} more`}</Text>}
    </Box>
  );
}

function Fact({ label, children }: { label: string; children: ReactNode }) {
  return (
    <Box>
      <Box width={9}>
        <Text color={COLORS.muted}>{label}</Text>
      </Box>
      <Text>{children}</Text>
    </Box>
  );
}

function FactsSection({ agent, now }: { agent: Agent; now: Date }) {
  const label = agent.pr ? prLabel(agent.pr) : null;
  return (
    <Box flexDirection="column">
      <Heading>FACTS</Heading>
      {agent.pr && label && (
        <Fact label="PR">
          <Text color={COLORS.blue}>{prRef(agent.pr)}</Text> · <Text color={label.color}>{label.text}</Text>
        </Fact>
      )}
      {agent.issue && (
        <Fact label="Issue">
          <Text color={COLORS.blue}>{agent.issue.key}</Text>
          {agent.issue.title ? ` ${agent.issue.title}` : ""}
          <Text color={COLORS.muted}> ({agent.issue.source})</Text>
        </Fact>
      )}
      {agent.lane && <Fact label="Lane">{agent.lane}</Fact>}
      {agent.branch && <Fact label="Branch">{agent.branch}</Fact>}
      {agent.edited_files > 0 && <Fact label="Edited">{`${agent.edited_files} files`}</Fact>}
      <Fact label="Status">{`${agent.status} · updated ${ago(agent.updated_at, now)} ago (${clock(agent.updated_at)})`}</Fact>
    </Box>
  );
}

export function AgentDetail({ agent, width, now, isTimelineExpanded }: { agent: Agent; width: number; now: Date; isTimelineExpanded: boolean }) {
  const isWide = width >= 100;
  const right = isWide ? Math.floor(width * 0.4) : width - 4;
  const left = (
    <Box flexDirection="column" width={isWide ? width - right - 6 : width - 4}>
      <PlanSection agent={agent} now={now} />
      <ReportSection agent={agent} isExpanded={isTimelineExpanded} />
    </Box>
  );
  const side = (
    <Box flexDirection="column" width={right}>
      <TimelineSection agent={agent} width={right} isExpanded={isTimelineExpanded} />
      <FactsSection agent={agent} now={now} />
    </Box>
  );
  return (
    <Box flexDirection={isWide ? "row" : "column"} paddingLeft={2} marginBottom={1} gap={isWide ? 2 : 1}>
      {left}
      {side}
    </Box>
  );
}
