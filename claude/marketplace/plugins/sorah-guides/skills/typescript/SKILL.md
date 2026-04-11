---
name: typescript
description: This skill should be used when writing or reviewing TypeScript or TSX code, or when the project uses "TypeScript", "React", "tsx", "SWR", "Vite", "Next.js", or TypeScript type patterns. Provides TypeScript coding conventions, React patterns, and best practices. Project-specific conventions always take priority.
version: 0.1.0
---

# TypeScript Conventions

Coding conventions and best practices for TypeScript projects. Project-specific conventions (CLAUDE.md, style guides) always take priority over this guidance.

## Type Definitions

- **Use `type` over `interface`** for object shapes, API responses, props, and general type aliases
- `interface` is acceptable only when declaration merging or `extends` is specifically needed
- Use discriminated unions with a `kind` or similar literal field for variant types
- String literal unions over enums: `type Status = "INIT" | "READY" | "ERROR"`
- Use `Pick`, `Omit`, and mapped types to derive types rather than duplicating fields
- Mark optional fields with `?` — avoid `| undefined` unless semantically distinct

```typescript
type Config = {
  region: string;
  tracks: TrackSlug[];
};

type ApiResponse =
  | { kind: "success"; data: Item }
  | { kind: "error"; message: string };
```

## Type Safety

- Enable strict mode (`"strict": true` in tsconfig)
- Write type guard functions for runtime narrowing: `function isScreenMode(v: string): v is ScreenMode`
- Avoid `any` — use `unknown` when the type is truly uncertain, then narrow
- Use `import type { ... }` for type-only imports

## Naming Conventions

- **Files**: PascalCase for components (`TrackPage.tsx`), camelCase for utilities and libraries (`api.ts`, `models.ts`)
- **Types**: PascalCase (`ChatMessage`, `ScreenControl`)
- **Variables/Functions**: camelCase (`trackSlug`, `onSubmit`)
- **Constants**: `UPPER_SNAKE_CASE` (`HISTORY_LENGTH`, `ALL_TRACKS`)
- **Booleans**: Prefix with `is` or `should` (`isRequesting`, `shouldShowTopic`)

## React Components

- Functional components only — no class components
- Use `ReactNode` for children type
- Prefer named exports; use default exports for route-level pages or lazy-loaded components

### Hooks

- `useState` for local state, React Context for shared/global state
- SWR (`useSWR`, `useSWRInfinite`) for server data fetching — no Redux/Zustand
- `react-hook-form` (`useForm`) for form state management
- Extract reusable logic into custom hooks (`use*` prefix)
- Always specify dependency arrays correctly in `useEffect`, `useMemo`, `useCallback`

### Server Components (Next.js App Router)

- Default to server components; add `"use client"` only when interactivity is needed
- Server components can be `async` and fetch data directly
- Use `server-only` package to enforce server-only modules

## Data Fetching & Async

- SWR for data fetching with automatic caching and revalidation
- `async`/`await` over raw Promise chains
- Guard duplicate submissions with an `isRequesting` state flag in form handlers
- Type API responses explicitly — name response types with descriptive suffixes (e.g., `GetConferenceResponse`)

## Error Handling

- Discriminated unions for success/error states in API responses
- Custom error classes extending `Error` with additional context fields
- Error boundary components (`react-error-boundary`) at route level
- `console.error()` for critical failures; `console.log()` acceptable for development debugging

## Styling

Follow the project's chosen approach — common patterns:

- **Chakra UI**: Inline style props, responsive array syntax (`w={["100%", "100%", "auto"]}`), centralized theme with `extendTheme()`
- **Vanilla Extract**: `.css.ts` files co-located with components, `createTheme()` for tokens, `globalStyle()` for resets

Centralize color palettes and font definitions in a `theme.ts` or `fundamental.css.ts` file.

## Module & Import Style

- Named imports for libraries and internal modules
- Path aliases (`@/components/`, `@/lib/`) when configured — prefer over deep relative paths
- Lazy loading with `@loadable/component` or `React.lazy` for route-level code splitting
