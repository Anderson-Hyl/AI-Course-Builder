# CLAUDE.md

This file is the engineering bible for **AI Course Builder**. Product/architecture decisions live in `PRD.md`, `ARCHITECTURE.md`, `AGENTS.md`, and `design/concept.png` — read those first when product intent is unclear, then come back here for *how* to build.

## Project purpose

Native iPad app (also runs on Mac via *Designed for iPad*) that turns a broad learning goal — e.g. *"I want to learn Haskell"* — into a structured, adaptive, session-based program. The session is the unit, **not the chat**. The LLM authors structured content blocks; the app owns layout, interaction, state, and progress tracking.

Core loop: `Goal → Program → Session → Practice → Check → Adapt`.

## Distribution & positioning

Primary delivery is the **iPad App Store binary**, which also runs on Apple Silicon Macs via "Mac (Designed for iPad)". A separate **native macOS dev target** exists for fast iteration with the Claude Code CLI subprocess (which the iPad sandbox cannot spawn). The macOS target is dev-only — never archived for distribution. Mac App Store is not a target initially.

**Sandbox-driven LLM split** (lands in a later pass):
- iPad target → Anthropic API direct via URLSession + SSE.
- macOS dev target → Claude Code CLI subprocess (`#if os(macOS)` gated).
- Both behind a single `ChatClient` abstraction returning `AsyncThrowingStream<ChatEvent>`.

## Architecture

One top-level `.xcworkspace` composing `AICourseBuilder.xcodeproj` (xcodegen-managed via `project.yml`) with one local SPM package `AICourseBuilderPackage`. Feature boundaries follow `ARCHITECTURE.md §4` — one library per module so engines stay swappable and testable.

- **`AICourseBuilderPackage/`**:
  - `LearningModels` — `@Table LearnerProfile / LearningGoal / ProgramBlueprint / Stage / Sprint / Session / SessionBlock / ConceptNode / Competency / Attempt / Artifact / MasteryState / ReviewItem`. Block payload structs (`ConceptPayload`, `MultipleChoicePayload`, …) versioned with `schemaVersion: Int` from day one. Lightweight + dependency-free aside from `SQLiteData`.
  - `LearningDatabase` — `bootstrapDatabase()`, `DatabaseMigrator`, custom `uuid()` `DatabaseFunction`, triggers for `createdAt` / `updatedAt` and ordered-list compaction.
  - `LearningRepository` — `Sendable struct LearningRepository`. Single source of mutation truth; fires `LearningMutationObserver` hooks from inside its own writes (mirrors SlideFlow's `DeckMutationObserver` discipline). Engines + UI write through this seam, never directly to `database`.
  - `LearningUI` — app-specific design extras (placeholders for now; full design system arrives with the next pass when UIComponents wires in).
  - `LessonRendering` — block-to-SwiftUI renderers. **Placeholder this pass** — implementation lands when block types are exercised end-to-end.
  - `PlanningEngine` — goal → blueprint, stage expansion. **Placeholder this pass** — wires to LLM next pass.
  - `EvaluationEngine` — attempt scoring + competency delta. **Placeholder this pass**.
  - `AdaptationEngine` — next-step decisions, review insertion, recovery sessions. **Placeholder this pass**.
  - `TutorEngine` — `TutorEngine.ask(turns:context:)` streams hints / reframings / encouragement from `ChatClient` for the Session Workspace's slide-over panel. Plain prose (no forced tool call). System prompt at `Resources/TutorPrompt.txt` enforces "guide, don't reveal answers."
  - `ChatClients` — `ChatClient` abstraction over Anthropic API + Claude Code CLI. Live: both providers + `APIKeyStore`. `PlanningEngine` and `TutorEngine` both call through here.
  - `AppFeature` — coordinator reducer and all screen-level views. Routes by an `AppScope` enum (`.library` / `.newCourse` / `.course(goalID)`) on top of the transient bootstrap / planning / outline gates. Hosts: `LibraryView`, `NewCourseSheetView`, `CourseHomeView`, `SessionWorkspaceView`, `APIKeySheetView`. Plus the legacy `PlanningProgressView` + `PlanningErrorView` + `ProgramPreviewView` for non-modal planning paths.

## Data model

Tables (full schema seeded in `LearningDatabase.Schema`; entities defined in `LearningModels`):

| Table | Contents |
|---|---|
| `learnerProfiles` | id, displayName?, startingLevel, weeklyTimeBudgetHours, learningStyles (JSON array), targetOutcome?, createdAt, updatedAt |
| `learningGoals` | id, profileID FK, text, normalizedTopic?, status, createdAt, updatedAt |
| `programBlueprints` | id, goalID FK, summary, durationWeeks?, createdAt, updatedAt |
| `stages` | id, programID FK, order, title, intent, status, createdAt, updatedAt |
| `sprints` | id, stageID FK, order, title, focus, status, createdAt, updatedAt |
| `sessions` | id, sprintID FK, order, title, objective, estimatedMinutes, status, createdAt, updatedAt |
| `sessionBlocks` | id, sessionID FK, order, kind, schemaVersion, payloadJSON, createdAt, updatedAt |
| `conceptNodes` | id, programID FK, title, prerequisites (JSON ID array), createdAt |
| `competencies` | id, programID FK, title, description?, createdAt |
| `attempts` | id, blockID FK, kind, inputJSON, resultJSON?, scoredAt?, createdAt |
| `artifacts` | id, sessionID FK?, attemptID FK?, kind, contentJSON, createdAt |
| `masteryStates` | id, conceptID FK, level (0..1), confidence (0..1), lastReviewedAt?, nextReviewAt? |
| `reviewItems` | id, conceptID FK, dueAt, intervalDays, lapseCount, createdAt |

Key invariants:

- **`SessionBlock` is one row per block** (not a JSON blob in `Session`). Reordering and per-block status update one row, not the whole session. `INSERT` trigger auto-assigns `order = MAX+1`; `AFTER DELETE` trigger compacts siblings so badges stay 01, 02, 03 contiguously. Same pattern as SlideFlow's `slideInstances`.
- **`schemaVersion: Int` is mandatory** on every `SessionBlock.payloadJSON` payload. The renderer reads it before decoding; an unknown version renders an "Update app to view this block" placeholder rather than silently failing. **Don't bump `schemaVersion` for additive optional fields** — only for breaking changes that the prior renderer can't safely degrade.
- **Block kinds use snake_case strings** (`title`, `objective`, `concept`, `example`, `code_exercise`, `multiple_choice`, `short_answer`, `reflection`, `checkpoint`, `review_card`) so they round-trip cleanly with the JSON the LLM eventually produces. Swift mirrors them via a `BlockKind` enum with explicit `rawValue`.
- **DEBUG runs with `migrator.eraseDatabaseOnSchemaChange = true`** (mirrors SlideFlow). Schema edits wipe the local DB on next launch — warn the user to expect a one-time wipe.
- **Cascade rules**: deleting a `LearningGoal` cascades to its `ProgramBlueprint` → stages → sprints → sessions → blocks. Deleting a `LearnerProfile` cascades to its goals. `Attempt`, `Artifact`, `MasteryState`, `ReviewItem` reference parents by FK with `ON DELETE CASCADE`. `Conversation` analogue (if added) would `SET NULL` so chat survives, but no chat schema yet.
- **IDs are UUIDs throughout**, generated via the registered `uuid()` `DatabaseFunction` so the column default fires at the SQL layer and IDs survive cross-device sync.

## Mutation observer (single source of truth)

`LearningRepository` holds `@Dependency(\.learningMutationObserver) private var observer` and fires `didCreateGoal` / `didCreateProgram` / `didChangeSession` / `didRecordAttempt` / etc. from inside its own writes. **Every write origin — engines (Planning / Evaluation / Adaptation / Tutor), UI handlers, future MCP/CLI tool calls — converges on one observer.** The app target implements `AppLearningMutationObserver` (in `AICourseBuilderApp.swift`) to dispatch TCA actions: route to a new program after goal creation, refresh the session list when a session changes, drive the "tutor thinking" indicator during adaptation, etc.

**Do NOT add `await observer.didX()` calls from outside `LearningRepository`.** Any new mutation method on the repository MUST fire the appropriate hook after the DB write. Default-impl new protocol methods so `NoOpLearningMutationObserver` keeps compiling.

## Tech stack

- **TCA** (`swift-composable-architecture`) — feature logic and navigation. User-facing state in reducers; views are thin.
- **SQLiteData** (Point-Free) — persistence. Schemas drive the data model; views observe live queries via `@FetchAll` / `@FetchOne`.
- **StructuredQueries** — type-safe SQL. Multi-table joins need explicit `.select { Row.Columns(...) }` with `@Selection` projection.
- **swift-dependencies** — DI for repositories, clients, observers via `@Dependency` + `DependencyKey`.
- **SwiftUI** — primary UI. AppKit / UIKit interop only when platform forces it (`#if os(macOS)` gates).
- **UIComponents** (remote design system, `github.com/Anderson-Hyl/UIComponents.git`) — wires in **next pass** along with the `LearningUI` polish. Will thread tokens through `@Environment(\.theme)` (colors / typography / radius / spacing / motion / elevation).
- **Anthropic SDK + Claude Code CLI** — both behind `ChatClient` (next pass).
- **Open-source Apple-platform components** welcome — prefer battle-tested libraries to hand-rolled implementations when one fits. Record the source in the commit message.

## Platform targets

iPadOS 26 + macOS 26 (matches SlideFlow's `.v26` floors), Swift 6.2 with `SWIFT_STRICT_CONCURRENCY: complete`. Two Xcode targets share the `AICourseBuilder/` source directory:

- `AICourseBuilder` — native macOS dev (`platform: macOS`). Includes the Claude Code CLI provider when ChatClients lands. Never archived for distribution.
- `AICourseBuilder-iPad` — iPadOS shipping (`platform: iOS`, `TARGETED_DEVICE_FAMILY = "2"`, `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = YES`). Runs natively on iPad and on Apple Silicon Macs via *Mac (Designed for iPad)*. CLI provider is filtered out via `#if os(macOS)` gates.

Both `AICourseBuilderPackage` libraries list `[.macOS(.v26), .iOS(.v26)]` as supported platforms. Don't add `tvOS` / `watchOS` / `visionOS` unless the user explicitly asks.

**Platform-split files (when they land)**: anything spawning `Process` (Claude Code CLI subprocess) is `#if os(macOS)`-only — `Process` exists on iOS in name but every working method requires entitlements the App Store sandbox blocks. SwiftUI APIs that are macOS-only (`Window` scene type, `.windowResizability`, `.defaultSize`, `NSCursor`) are gated inline at each use site.

## LLM surface (planned, not yet implemented)

When the next pass lands:

- One `ChatClient` abstraction returning `AsyncThrowingStream<ChatEvent>` where `ChatEvent` is `.text(String) | .toolCall(...) | .done(TurnSummary)`.
- Two providers behind it: **`AnthropicChatClient`** (URLSession + SSE, runs everywhere, used by the iPad shipping target) and **`ClaudeCodeChatClient`** (`#if os(macOS)`, spawns `claude --print --output-format stream-json --mcp-config <inline>`, dev convenience). Same provider-agnostic tool catalog on both.
- **Engines own LLM calls.** `PlanningEngine.generateBlueprint(goal:)`, `EvaluationEngine.score(attempt:against:)`, `AdaptationEngine.next(after:)`, `TutorEngine.ask(turns:context:)` each call the relevant `ChatClient` method internally. **There is NO chat drawer.** The LLM is invisible to the user except through the structured content it produces and the tutor-panel responses inside the Session Workspace.
- **Structured outputs are mandatory.** Every LLM response is a typed JSON object validated against the block schema (`schemaVersion` enforced, unknown block kinds rejected). Hallucinated structure surfaces a parse error and a retry, not a silent fallback.
- **Provider keys** live in UserDefaults under `com.aicoursebuilder.provider-keys.<id>` initially (matches SlideFlow rationale: ad-hoc-signed dev builds get volatile code identities that orphan Keychain items). Migrate to Keychain once Developer ID lands.

## UI / design system

Calm, focused, structured. Per PRD §7 / AGENTS §UI principles:

- Strong center-stage learning surface; tutor/help panels visible but secondary.
- Progress visible without gamified noise.
- Minimal chrome; clear hierarchy via typography and spacing, not borders.

This pass uses plain SwiftUI + system colors so the bootstrap stays small. The next pass wires `UIComponents` and a `aiCourseBuilder` theme through `@Environment(\.theme)`. When that lands, follow the SlideFlow UI conventions in `~/Desktop/SlideFlow/CLAUDE.md` (theme thread-through, no inline color literals, `LearningUI` for app-specific extras).

## Build commands

- **Generate the Xcode project** after editing `project.yml`:
  ```sh
  cd /Users/anderson/Desktop/AI-Course-Builder && xcodegen generate
  ```
- **Build the SPM package only** (fast feedback for non-app code):
  ```sh
  cd /Users/anderson/Desktop/AI-Course-Builder/AICourseBuilderPackage && swift build
  ```
- **Build the macOS dev scheme**:
  ```sh
  xcodebuild -workspace /Users/anderson/Desktop/AI-Course-Builder/AICourseBuilder.xcworkspace \
    -scheme AICourseBuilder -configuration Debug build
  ```
- **Build the iPad shipping scheme** (specify a destination):
  ```sh
  xcodebuild -workspace /Users/anderson/Desktop/AI-Course-Builder/AICourseBuilder.xcworkspace \
    -scheme AICourseBuilder-iPad -configuration Debug \
    -destination 'generic/platform=iOS Simulator' build
  ```
- **Local-dev workflow**: build in Xcode (`⌘B`), then launch the built `.app` directly from DerivedData via `open <path>` rather than `⌘R`. Xcode's Run re-signs through a debug-attach shim that macOS treats as a distinct TCC identity — Screen Recording / Accessibility / Automation re-prompt on every launch. Launching the built `.app` keeps the signature stable. Becomes moot once Developer ID lands.

## Conventions

- **Prefer editing existing files** to creating new ones. Don't add abstractions, error handling, or fallbacks until a second caller actually exists. Three similar lines is better than a premature abstraction.
- **`@Shared(.appStorage(...))`** keys must be identifier-safe (no dots) — dots degrade `swift-sharing` to notification-center observation. Writes inside reducers use `state.$name.withLock { $0 = value }`; direct assignment doesn't compile.
- **Snake_case for LLM-facing JSON keys** via explicit `CodingKeys`; Swift structs keep camelCase internally. Same split SlideFlow uses for tool DTOs.
- **Block schema discipline**: `schemaVersion` lives on the payload, not the row. Bump only for breaking changes. New block kinds are additive; the renderer renders an "Unknown block kind" placeholder for any kind it doesn't recognize.
- **New SPM packages, products, dependencies** go through the `pfw-spm` skill. After adding a local package: update `project.yml` AND `AICourseBuilder.xcworkspace/contents.xcworkspacedata` AND run `xcodegen generate`.
- **Engines never write to `database` directly** — always through `LearningRepository` so the mutation observer fires uniformly.
- **Test fixtures use stable UUIDs** with readable suffixes (e.g. `…0001` = first goal, `…AAAA` = primary profile) so test failures point at the seeded row immediately.

## Artifact format

**The rule**: if a human is going to read it, render it as HTML. If the same content could've been a markdown file, render it as HTML *instead*. Markdown is reserved for artifacts that only a model will read.

This is a hard rule, not a suggestion. Reports, plans, walkthroughs, status updates, design proposals, comparison tables, post-pass summaries, anything you'd otherwise hand the user as a `.md` — write it as a self-contained HTML file. Reaching for markdown when the user is the audience is a regression; if you catch yourself doing it, stop and convert before surfacing.

**Audience test**:
- *Human* will read it → **HTML**.
- *Model* will read it (future session, prompt, tool schema) → **markdown**.

**Human-audience artifacts → HTML**:
- Plans (planning-mode deliverables, refinement notes, before/after design proposals).
- End-of-pass landing reports and walkthroughs ("here's what shipped").
- Status reports, feature briefs, decision memos.
- Comparison tables, before/after diagrams, screen mockups.
- Anything the user will *read once and react to* — even a one-page progress summary.

**Model-audience artifacts → markdown**:
- Engineering bibles (this file), `ARCHITECTURE.md`, `PRD.md`, `AGENTS.md`.
- Prompts, system instructions, tool schemas (when not JSON).
- Code comments, in-source docs.
- Task lists used as harness scratchpads (TaskCreate-style).
- Anything a future session will grep, diff, or splice into a tool call.

### Where the HTML lives

- **Project deliverables** (anything tied to repo work): `design/` inside the project, e.g. `design/session-summary-surface.html`. These get committed.
- **Plan-mode deliverables**: alongside the markdown plan in `~/.claude/plans/`, same basename + `.html` extension, e.g. `~/.claude/plans/<slug>.html`. The `.md` is the harness contract; the `.html` is what the user actually reads. Mention the HTML path in your post-plan summary so the user knows where to open it. These do NOT get committed (they live outside the repo).

### HTML file requirements

Match `design/mvp-design-board.html` and `design/session-summary-surface.html` for the canonical shape:

- One inline `<style>` block driven by CSS custom properties whose names mirror `LearningUI/Theme/CourseBuilderThemePalette.swift` (`--app-canvas`, `--page`, `--sidebar`, `--card`, `--accent`, `--text-primary`, `--text-secondary`, `--success`, `--warning`, `--danger`, …). No inline color literals — always reach for the token.
- Light/dark via a `data-theme="light"` attribute on `<html>`; provide both swatches in `:root` and `[data-theme="dark"]`. Include a small toggle button so the user can flip themes inline.
- System fonts only (`ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`; `ui-monospace, "JetBrains Mono", Menlo, monospace` for code). No Google Fonts, no CDN, no JS dependencies (a tiny inline `onclick` for the theme toggle is fine; nothing more) — the file must open offline.
- Typography-driven hierarchy, generous whitespace, restrained accents, soft elevation (subtle shadow + 22–28pt corner radii). Elegance over information density.
- Visual mock-ups, callouts, flow strips, anatomy diagrams welcome — a great deliverable shows the surface, not just describes it.

Markdown deliverables that slip past this rule are a regression — call it out and convert before sharing.

## Build gotchas

- **`xcodegen generate` does NOT update `AICourseBuilder.xcworkspace/contents.xcworkspacedata`.** Adding a new local SPM package requires (1) editing `project.yml`, (2) hand-adding a `<FileRef location="group:Pkg"/>` to the workspace contents, (3) running `xcodegen generate`. Symptom of the missed step: blue folder vs. brown-cube SPM icon in Xcode's navigator. Quit Xcode + delete DerivedData if the workspace doesn't re-parse.
- **SPM resource additions don't auto-register.** Edit `Package.swift`'s `resources: []` AND drop the file into `Sources/<Target>/Resources/`, then `swift build` once so SPM regenerates `Bundle.module`. SourceKit errors about `Bundle.module` before the build finishes are transient.
- **Schema migration edits trigger DEBUG DB wipes.** If you edit a `CREATE TABLE` statement in `LearningDatabase.Schema`, expect a one-time wipe on the next launch. Tell the user before touching any seeded data.
- **`swift-composable-architecture` has a ~300k-object history that intermittently fails mid-clone** (`curl 18 Transferred a partial file`). Once the SwiftPM cache at `~/Library/Caches/org.swift.swiftpm/repositories/swift-composable-architecture-*` is populated and healthy, prefer `swift build --skip-update` to avoid re-fetching.
- **Xcode rebuild invalidates TCC** — see "Build commands" above. Workaround: build once (`⌘B`), launch the `.app` directly from DerivedData. Permanent fix gated on Developer ID signing.

## Point-Free skills (`~/.pfw/skills/`)

A full set of Point-Free skills lives at `~/.pfw/skills/`, covering the libraries this project is built on:

- `composable-architecture/` — TCA usage (reducers, stores, navigation)
- `sqlite-data/` — SQLite schema, fetching, observation
- `structured-queries/` — type-safe SQL
- `dependencies/` — `@Dependency` and `prepareDependencies`
- `swift-navigation/`, `modern-swiftui/`, `observable-models/`, `perception/`
- `sharing/`, `identified-collections/`, `case-paths`, `custom-dump`
- `issue-reporting/`, `snapshot-testing/`, `testing/`, `macro-testing/`
- `spm/` — making changes to `Package.swift`
- `pfw/` — the meta-skill; always consult this first

**Always consult the relevant `pfw-*/SKILL.md` before touching the corresponding library.** Don't freehand `Package.swift` edits — use the SPM skill.

**The `$skill` shorthand**: when the user writes `$<name> <instructions>` (e.g. `$spm create a library named LessonRendering`), treat it as a directive to load `~/.pfw/skills/<name>/SKILL.md` and follow its guidance.

## Reference docs

- `PRD.md` — product requirements, target user, MVP scope, success criteria.
- `ARCHITECTURE.md` — module boundaries, engine contracts, persistence model, MVP implementation order.
- `AGENTS.md` — coding-agent guidance, product non-goals, content model, learning logic.
- `design/concept.png` — original Figma-style visual reference; superseded by the v2 deliverables below but kept for token / palette history.
- `design/mvp-design-board.html` — v1 four-screen mockup (Goal Intake / Home Dashboard / Session Workspace / Program Map) aligned to `LearningUI/Theme/CourseBuilderThemePalette.swift`. Useful for token reference; the v1 screens themselves are gone.
- `design/App Structure _standalone_.html` — the App Structure v2 design (Library → Course → Session, persistent topbar, contextual sidebar, focus-mode Session, modal New Course). This is the **current** source of truth for IA + layout; the running SwiftUI app mirrors its four screens.

CLAUDE.md is the **engineering** bible; the four above are the **product/architecture** bibles. When intent is unclear, those are the source of truth.

## Known open items

Carried over from the bootstrap pass:

- **AdaptationEngine** (HIGH). `PlanningEngine`, `EvaluationEngine`, and `TutorEngine` ship live; AdaptationEngine stays placeholder. Wires after a few sessions worth of attempts exist to drive next-step decisions, review insertion, and recovery sessions.
- **Review Vault** (MEDIUM). The Course Home rail shows a placeholder "no items yet" card; spaced-repetition queue logic lands when `ReviewItem` is wired through.
- **`UIComponents` design system** (MEDIUM). The new `LearningUI/Shell` primitives (Shell / Topbar / Sidebar / NavItem) cover the v2 chrome. Wider design-system adoption (deep Theme bindings, motion tokens) lands when the remote UIComponents library is integrated.
- **Tests** (MEDIUM). Test target stub exists in `Package.swift` but no test bodies. First tests cover `SessionBlock` payload encode/decode + `LearningRepository` round-trips per `ARCHITECTURE.md §13`.
- **CloudKit sync** (LOW). SQLiteData supports it (see SlideFlow's `Schema.swift` for the wiring); add after the local-first loop is solid.
- **App icon, brand assets, marketing copy** (LOW). Placeholder accent color only.
- **Bundle ID confirmation**: defaulted to `com.stareraadaspace.ai-course-builder` mirroring SlideFlow's prefix. Confirm with the developer team owner before App Store submission.
