import { render } from "ink";
import { spawnSync } from "node:child_process";
import { App } from "./App.tsx";
import type { Agent } from "./snapshot.ts";
import type { SnapshotSource } from "./useSnapshots.ts";

const fixtureIndex = process.argv.indexOf("--fixture");
const fixturePath = fixtureIndex >= 0 ? process.argv[fixtureIndex + 1] : undefined;
const source: SnapshotSource = fixturePath ? { kind: "fixture", path: fixturePath } : { kind: "watch" };

let jumpTarget: Agent | null = null;

process.stdout.write("\x1b[?1049h");
const app = render(<App source={source} onJump={(agent) => (jumpTarget = agent)} />);
await app.waitUntilExit();
process.stdout.write("\x1b[?1049l");

// Switching after Ink exits lets a surrounding `display-popup -E` close first.
const target = jumpTarget as Agent | null;
if (target?.tmux.pane) {
  spawnSync("tmux", ["switch-client", "-t", target.tmux.pane], { stdio: "inherit" });
}
