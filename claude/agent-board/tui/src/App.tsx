import { Box, Text, useApp, useInput, useStdout } from "ink";
import { useEffect, useRef, useState } from "react";
import type { Agent, Group, Snapshot } from "./snapshot.ts";
import { COLORS, GROUP_COLORS } from "./theme.ts";
import { ago } from "./format.ts";
import { spawnSync } from "node:child_process";
import { BOARD_BIN, useSnapshots, type SnapshotSource } from "./useSnapshots.ts";
import { AgentRow, columnsFor, rowHeight } from "./components/AgentRow.tsx";
import { AgentDetail, detailHeight } from "./components/AgentDetail.tsx";

type Item = { kind: "group"; group: Group } | { kind: "agent"; agent: Agent };

const CHROME_ROWS = 3;

function summary(snapshot: Snapshot): string {
  const c = snapshot.counts;
  const parts = [
    c.needs_you && `${c.needs_you} need${c.needs_you === 1 ? "s" : ""} you`,
    c.waiting && `${c.waiting} waiting`,
    c.working && `${c.working} working`,
    c.idle && `${c.idle} idle`,
    c.parked && `${c.parked} parked`,
    snapshot.chief && `chief-of-staff ${snapshot.chief.status}`,
  ];
  return parts.filter(Boolean).join(" · ") || "no agents";
}

function useTerminalSize(): { columns: number; rows: number } {
  const { stdout } = useStdout();
  const [size, setSize] = useState({ columns: stdout.columns || 120, rows: stdout.rows || 40 });
  useEffect(() => {
    const onResize = () => setSize({ columns: stdout.columns, rows: stdout.rows });
    stdout.on("resize", onResize);
    return () => {
      stdout.off("resize", onResize);
    };
  }, [stdout]);
  return size;
}

function useNow(intervalMs: number): Date {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const timer = setInterval(() => setNow(new Date()), intervalMs);
    return () => clearInterval(timer);
  }, [intervalMs]);
  return now;
}

function currentSocket(): string | undefined {
  return process.env.TMUX?.split(",")[0];
}

export function App({ source, onJump }: { source: SnapshotSource; onJump: (agent: Agent) => void }) {
  const { exit } = useApp();
  const { snapshot, error } = useSnapshots(source);
  const { columns, rows } = useTerminalSize();
  const now = useNow(5000);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [isTimelineExpanded, setIsTimelineExpanded] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [pendingArchive, setPendingArchive] = useState<Agent | null>(null);
  const [lastArchived, setLastArchived] = useState<Agent | null>(null);
  const topRef = useRef(0);

  const groups = snapshot?.groups.filter((g) => g.agents.length > 0) ?? [];
  const agents = groups.flatMap((g) => g.agents);
  const selectedIndex = Math.max(0, agents.findIndex((a) => a.id === selectedId));
  const selected = agents[selectedIndex];

  const board = (args: string[], done: string) => {
    const result = spawnSync(BOARD_BIN, args, { encoding: "utf8" });
    setMessage(result.status === 0 ? done : (result.stderr || `${args[0]} failed`).trim());
    return result.status === 0;
  };

  useInput((input, key) => {
    setMessage(null);
    if (pendingArchive) {
      setPendingArchive(null);
      if (input === "y" && board(["archive", pendingArchive.id], `Archived ${pendingArchive.label}. u: undo`)) {
        setLastArchived(pendingArchive);
      } else if (input !== "y") {
        setMessage("Not archived.");
      }
      return;
    }
    const move = (delta: number) => {
      const next = agents[Math.min(agents.length - 1, Math.max(0, selectedIndex + delta))];
      if (next) setSelectedId(next.id);
    };
    if (input === "j" || key.downArrow) move(1);
    else if (input === "k" || key.upArrow) move(-1);
    else if (key.return && selected) {
      setExpandedId(expandedId === selected.id ? null : selected.id);
      setIsTimelineExpanded(false);
    } else if (input === "m") setIsTimelineExpanded(!isTimelineExpanded);
    else if (input === "g" && selected) {
      const socket = selected.tmux.socket;
      if (!socket || !selected.tmux.pane || selected.status === "parked") setMessage("No live tmux pane for this agent.");
      else if (socket !== currentSocket()) setMessage(`Agent runs on another tmux server (${socket}).`);
      else {
        onJump(selected);
        exit();
      }
    } else if (input === "a" && selected) {
      setPendingArchive(selected);
      setMessage(`Archive ${selected.label}? It leaves the board until unarchived. y: archive, any other key: cancel`);
    } else if (input === "u" && lastArchived) {
      if (board(["unarchive", lastArchived.id], `Restored ${lastArchived.label}.`)) setLastArchived(null);
    } else if (input === "r" && selected) {
      if (selected.status !== "parked") setMessage("Only parked agents can be resumed.");
      else board(["resume", selected.id], `Resumed ${selected.label} in a new tmux window.`);
    } else if (input === "q" || key.escape) exit();
  });

  if (!snapshot) {
    return <Text color={COLORS.muted}>{error ?? "Loading…"}</Text>;
  }

  const width = columns - 1;
  const cols = columnsFor(width);
  const items: Item[] = groups.flatMap((group) => [{ kind: "group", group } as Item, ...group.agents.map((agent) => ({ kind: "agent", agent }) as Item)]);
  const heightOf = (item: Item) => {
    if (item.kind === "group") return 3;
    const extra = item.agent.id === expandedId ? detailHeight(item.agent, width >= 100, isTimelineExpanded) : 0;
    return rowHeight(item.agent) + extra;
  };

  // Keeps the selected row (and its group heading when it fits) inside the viewport.
  const budget = rows - CHROME_ROWS;
  const selectedItem = items.findIndex((i) => i.kind === "agent" && i.agent.id === selected?.id);
  let top = Math.min(topRef.current, Math.max(0, selectedItem - 1));
  const span = (from: number) => items.slice(from, selectedItem + 1).reduce((sum, i) => sum + heightOf(i), 0);
  while (top < selectedItem && span(top) > budget) top += 1;
  topRef.current = top;
  const visible: Item[] = [];
  let used = 0;
  for (const item of items.slice(top)) {
    used += heightOf(item);
    if (used > budget && visible.length > 0) break;
    visible.push(item);
  }

  return (
    <Box flexDirection="column" width={width}>
      <Box justifyContent="space-between">
        <Text>
          <Text bold>Agent Board</Text>
          <Text color={COLORS.muted}>{`  ${summary(snapshot)}`}</Text>
        </Text>
        <Text color={COLORS.muted}>{`updated ${ago(snapshot.generated_at, now)} ago`}</Text>
      </Box>
      {visible.map((item) =>
        item.kind === "group" ? (
          <Box key={`g-${item.group.key}`} flexDirection="column" marginTop={1}>
            <Text bold color={GROUP_COLORS[item.group.key]}>
              {`${item.group.title.toUpperCase()} `}
              <Text color={COLORS.muted}>{item.group.agents.length}</Text>
            </Text>
            <Text color={COLORS.rule}>{"─".repeat(width)}</Text>
          </Box>
        ) : (
          <Box key={item.agent.id} flexDirection="column">
            <AgentRow agent={item.agent} columns={cols} isSelected={item.agent.id === selected?.id} now={now} />
            {item.agent.id === expandedId && <AgentDetail agent={item.agent} width={width} now={now} isTimelineExpanded={isTimelineExpanded} />}
          </Box>
        ),
      )}
      <Box marginTop={1}>
        <Text color={message || error ? COLORS.orange : COLORS.muted}>
          {message ?? error ?? "j/k move · enter expand · m more · g go to pane · r resume · a archive · q quit"}
        </Text>
      </Box>
    </Box>
  );
}
