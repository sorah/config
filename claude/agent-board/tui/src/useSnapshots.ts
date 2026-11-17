import { useEffect, useState } from "react";
import { createInterface } from "node:readline";
import { spawn } from "node:child_process";
import { readFileSync } from "node:fs";
import type { Snapshot } from "./snapshot.ts";

export const BOARD_BIN = new URL("../../../../bin/sorah-agent-board", import.meta.url).pathname;

export type SnapshotSource = { kind: "watch" } | { kind: "fixture"; path: string };

// Live snapshots stream from `sorah-agent-board watch --json`; a fixture file renders its last line.
export function useSnapshots(source: SnapshotSource): { snapshot: Snapshot | null; error: string | null } {
  const [snapshot, setSnapshot] = useState<Snapshot | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (source.kind === "fixture") {
      const last = readFileSync(source.path, "utf8").trim().split("\n").at(-1) ?? "";
      setSnapshot(JSON.parse(last) as Snapshot);
      return;
    }

    const child = spawn(BOARD_BIN, ["watch", "--json"], { stdio: ["ignore", "pipe", "pipe"] });
    child.on("exit", (code) => {
      if (code) setError(`watch exited with status ${code}`);
    });
    child.stderr.on("data", (chunk: Buffer) => setError(chunk.toString().trim()));
    const lines = createInterface({ input: child.stdout });
    lines.on("line", (line) => {
      if (!line.trim()) return;
      try {
        setSnapshot(JSON.parse(line) as Snapshot);
      } catch (e) {
        setError(`unreadable snapshot: ${(e as Error).message}`);
      }
    });
    return () => {
      lines.close();
      child.kill();
    };
  }, [source]);

  return { snapshot, error };
}
