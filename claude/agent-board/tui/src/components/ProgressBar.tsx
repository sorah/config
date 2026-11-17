import { Text } from "ink";
import type { Plan } from "../snapshot.ts";
import { COLORS } from "../theme.ts";

export function ProgressBar({ plan, width, isBlocked }: { plan: Plan; width: number; isBlocked?: boolean }) {
  const cells = (count: number) => Math.round((count / Math.max(plan.total, 1)) * width);
  const done = cells(plan.done);
  const doing = Math.min(width - done, cells(plan.steps.filter((s) => s.status === "doing").length));
  const rest = Math.max(0, width - done - doing);
  return (
    <Text>
      <Text color={COLORS.green}>{"━".repeat(done)}</Text>
      <Text color={isBlocked ? COLORS.red : COLORS.blue}>{"━".repeat(doing)}</Text>
      <Text color={COLORS.rule}>{"━".repeat(rest)}</Text>
    </Text>
  );
}
