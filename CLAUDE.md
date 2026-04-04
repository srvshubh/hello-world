# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

UIGen is an AI-powered React component generator with live preview. Users describe UI components in natural language; Claude generates the code using tool calls, and the result is compiled and rendered in a sandboxed iframe preview — all without any disk writes.

## Commands

```bash
# First-time setup (install deps, generate Prisma client, run migrations)
npm run setup

# Development (Turbopack, with node-compat shim)
npm run dev

# Build for production
npm run build

# Lint
npm run lint

# Run all tests
npm test

# Run a single test file
npx vitest run src/lib/transform/__tests__/jsx-transformer.test.ts

# Reset database
npm run db:reset
```

> `NODE_OPTIONS='--require ./node-compat.cjs'` is prepended to all Next.js commands — required for Node.js compatibility shims.

## Architecture

### Data Flow: Component Generation

1. User submits prompt → `ChatInterface` → `/api/chat` (streaming via Vercel AI SDK)
2. Claude calls `str_replace_editor` tool (create/update/view files) or `file_manager` tool (rename/delete)
3. Tool calls are processed by `FileSystemContext.handleToolCall()` → mutates the in-memory `VirtualFileSystem`
4. `PreviewFrame` detects `refreshTrigger` changes → recompiles files with Babel → creates ES module import map with blob URLs → re-renders iframe
5. If user is authenticated and chat finishes: project is persisted to SQLite via Prisma server action

### Key Modules

- **`src/app/api/chat/route.ts`** — Streaming chat endpoint. Registers tool schemas (Zod), forwards to `getLanguageModel()`, streams tool call deltas back.
- **`src/lib/file-system.ts`** — In-memory `VirtualFileSystem` class. No disk I/O. Serializes to JSON for DB persistence.
- **`src/lib/transform/jsx-transformer.ts`** — Babel Standalone compilation pipeline. Converts JSX/TSX to ES modules, builds an import map (React → esm.sh CDN, user files → blob URLs, `@/` aliases resolved).
- **`src/lib/provider.ts`** — Returns `AnthropicProvider` (when `ANTHROPIC_API_KEY` is set) or `MockLanguageModel` (static fallback).
- **`src/lib/contexts/file-system-context.tsx`** — React context wrapping `VirtualFileSystem`. Executes AI tool calls and triggers preview refresh.
- **`src/lib/contexts/chat-context.tsx`** — Wraps Vercel AI SDK `useChat()`. Integrates tool call handling and anonymous work tracking.
- **`src/lib/prompts/generation.tsx`** — System prompt that instructs Claude how to use its tools to generate components.
- **`src/components/preview/PreviewFrame.tsx`** — Sandboxed iframe renderer. Generates HTML with `<script type="importmap">` for ES module resolution.

### Tool Use Architecture

Claude is given two tools (defined with Zod schemas in `/api/chat/route.ts`, implemented in `src/lib/tools/`):

| Tool | Commands | Purpose |
|------|----------|---------|
| `str_replace_editor` | `create`, `str_replace`, `insert`, `view` | Create and edit files |
| `file_manager` | `rename`, `delete` | Manage file names |

Tool calls are not executed server-side — they are streamed to the client and processed in `FileSystemContext`.

### Authentication

- JWT-based sessions via `jose` (no NextAuth)
- `src/middleware.ts` verifies session token for protected routes
- Server actions in `src/actions/` handle auth and project CRUD
- Anonymous usage is fully supported; projects are only persisted for authenticated users

### State Management

No Redux or Zustand. State flows through two React contexts:
- `FileSystemContext` — owns the `VirtualFileSystem` instance and refresh trigger
- `ChatContext` — owns chat messages, input, and status via Vercel AI SDK's `useChat()`

### Preview Isolation

- Preview renders in an `<iframe>` with `sandbox="allow-scripts allow-same-origin allow-forms"`
- Each user file is compiled to a JS blob URL and added to the importmap
- External packages resolved via `esm.sh` CDN at runtime (no bundling)
- Tailwind CSS injected via CDN script tag into the preview iframe

## Database

SQLite via Prisma. Schema: `User` (email/password) → `Project` (name, serialized file system JSON, serialized messages JSON).

```bash
npx prisma studio          # Browse DB
npx prisma migrate dev     # Apply schema changes
```

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_API_KEY` | Required for real AI generation; omit to use mock provider |
| `JWT_SECRET` | Secret for signing session tokens |
| `DATABASE_URL` | SQLite path (default: `file:./dev.db`) |

## Testing

Tests use Vitest with jsdom. Test files are colocated in `__tests__/` subdirectories. The test runner is configured in `vitest.config.mts` with `@vitejs/plugin-react` and `vite-tsconfig-paths`.
