import { Box, Text } from "ink";
import type { AttentionItem } from "../snapshot.ts";
import { COLORS } from "../theme.ts";
import { ago, truncate } from "../format.ts";

const KIND_COLORS: Record<AttentionItem["kind"], string> = {
  decide: COLORS.orange,
  draft: COLORS.purple,
  suggest: COLORS.blue,
};

// What the chief of staff wants from the user; answered by messaging the chief ("post 4").
export function ChiefSection({ items, width, now }: { items: AttentionItem[]; width: number; now: Date }) {
  return (
    <Box flexDirection="column" marginTop={1}>
      <Text bold color={COLORS.purple}>
        {"FROM CHIEF "}
        <Text color={COLORS.muted}>{items.length}</Text>
      </Text>
      <Text color={COLORS.rule}>{"─".repeat(width)}</Text>
      {items.map((item) => (
        <Text key={item.id} wrap="truncate-end">
          <Text color={COLORS.muted}>{`  #${item.id} `}</Text>
          <Text color={KIND_COLORS[item.kind]}>{item.kind.padEnd(8)}</Text>
          <Text>{truncate(item.text, Math.max(20, width - 40))}</Text>
          {item.agent && <Text color={COLORS.muted}>{` · ${item.agent}`}</Text>}
          {item.ref && <Text color={COLORS.blue}>{` · ${item.ref}`}</Text>}
          <Text color={COLORS.muted}>{` · ${ago(item.at, now)}`}</Text>
        </Text>
      ))}
    </Box>
  );
}
