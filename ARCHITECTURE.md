# ARCHITECTURE.md

# AI Course Builder Architecture

## 1. Architectural goal

Build a native learning app where:

- the UI shell is deterministic
- lesson rendering is block-based
- LLM output is structured content, not raw UI code
- attempts and progress are durable
- planning and adaptation are replaceable services

## 2. Guiding constraints

- Prefer SwiftUI-native rendering.
- Keep content generation separate from presentation.
- Keep planner/evaluator/adaptation logic testable and modular.
- Avoid hard-coding one subject into the architecture.
- Design for future retrieval without making it a dependency of v1.

## 3. High-level system split

Recommended subsystems:

- `AppShell`
- `LearningDomain`
- `LessonRendering`
- `PlanningEngine`
- `EvaluationEngine`
- `AdaptationEngine`
- `TutorEngine`
- `Persistence`

## 4. Suggested package/module boundaries

If this becomes a workspace with local packages, these are the best seams.

### 4.1 `LearningModels`

Core data types:

- `LearnerProfile`
- `LearningGoal`
- `ProgramBlueprint`
- `Stage`
- `Sprint`
- `Session`
- `SessionBlock`
- `ConceptNode`
- `Competency`
- `Attempt`
- `Artifact`
- `MasteryState`
- `ReviewItem`

This module should stay lightweight and dependency-free.

### 4.2 `LearningRepository`

Persistence-facing layer for:

- storing goals
- storing programs
- storing sessions
- storing attempts
- storing review state
- updating mastery state

Expose stable APIs so UI and engines never write storage directly.

### 4.3 `LessonRendering`

Responsible for:

- decoding/encoding session blocks
- rendering blocks via SwiftUI
- handling session flow state

Important rule:

- this module renders structured blocks
- it does not ask the model to generate view code

### 4.4 `PlanningEngine`

Responsible for:

- converting `LearningGoal` into `ProgramBlueprint`
- expanding near-term stages into detailed sessions
- applying defaults when user input is incomplete

This is the main goal-decomposition seam.

### 4.5 `EvaluationEngine`

Responsible for:

- scoring or classifying attempts
- turning attempts into structured result signals
- updating competency and mastery

Evaluation should be as deterministic as possible for v1.

### 4.6 `AdaptationEngine`

Responsible for:

- deciding what comes next
- inserting review
- slowing down or accelerating progression
- generating follow-up session requests

### 4.7 `TutorEngine`

Responsible for:

- hints
- reframing explanations
- encouragement
- contextual help

This should not own progress state.

### 4.8 `AppFeature`

The application shell and navigation layer:

- Goal Intake
- Home Dashboard
- Session Workspace
- Program Map
- Review Vault

## 5. Recommended data flow

Primary app loop:

1. user creates `LearningGoal`
2. `PlanningEngine` produces `ProgramBlueprint`
3. repository stores blueprint and current sessions
4. UI loads current session
5. user completes attempts
6. `EvaluationEngine` scores attempts
7. repository stores attempts/artifacts/mastery updates
8. `AdaptationEngine` determines next action
9. repository stores next session or review item

## 6. Block-based lesson rendering

The key design decision is block rendering.

### Session container

A session should contain:

- id
- title
- objective
- estimated duration
- stage/sprint references
- ordered block list

### Block examples

- `concept`
- `example`
- `codeExercise`
- `multipleChoice`
- `shortAnswer`
- `reflection`
- `checkpoint`

### Rendering rule

Every block type gets a native SwiftUI renderer.

Do not persist lesson UI as:

- SwiftUI source
- HTML page source
- arbitrary markdown with embedded behavior

Use a typed schema.

## 7. Suggested persistence model

Persistence can start local-first.

Suggested initial storage:

- SQLite or SwiftData-backed local persistence

Recommended tables/entities:

- `learnerProfiles`
- `learningGoals`
- `programBlueprints`
- `stages`
- `sprints`
- `sessions`
- `sessionBlocks`
- `attempts`
- `artifacts`
- `masteryStates`
- `reviewItems`

## 8. Engine contracts

Keep engine boundaries narrow and explicit.

### 8.1 Planning

Input:

- goal
- profile
- existing history

Output:

- blueprint
- near-term sessions

### 8.2 Evaluation

Input:

- session
- attempt
- optional expected answer metadata

Output:

- correctness/result classification
- feedback
- competency delta

### 8.3 Adaptation

Input:

- mastery snapshot
- recent attempts
- current blueprint position

Output:

- next session request
- review insertion
- remediation action

## 9. LLM integration strategy

LLM calls should be behind explicit clients/services.

Recommended seams:

- `GoalPlannerClient`
- `SessionAuthorClient`
- `TutorClient`
- `FeedbackWriterClient`

These can all point to one backend/model in MVP, but the interface should reflect distinct jobs.

### Important rule

Models should produce:

- structured content
- structured feedback
- structured planning outputs

Avoid returning raw UI implementations.

## 10. Retrieval strategy

Retrieval should be optional in v1 and pluggable later.

Future retrieval sources:

- official docs
- trusted tutorials
- curated examples

Recommended seam:

- `ReferenceRetriever`

The planner or session author can consume references, but the main app should not depend on retrieval always being available.

## 11. Suggested native app state slices

At the UI layer, state will likely cluster into:

- `GoalIntakeState`
- `DashboardState`
- `SessionWorkspaceState`
- `ProgramMapState`
- `ReviewVaultState`

Within `SessionWorkspaceState`, likely needs:

- active session
- current step index
- in-progress attempt input
- tutor panel state
- evaluation result
- pending next-step transition

## 12. MVP implementation order

Build in this sequence:

1. data models
2. session block schema
3. local repository
4. Goal Intake screen
5. Home Dashboard
6. Session Workspace with hardcoded data
7. session rendering from stored blocks
8. attempt capture
9. evaluation path
10. adaptation path
11. Program Map
12. Review Vault
13. LLM-backed planning/session generation

This order keeps the app functional even before the AI pieces are fully smart.

## 13. Testing priorities

Highest priority:

- session block serialization
- deterministic rendering of blocks
- repository read/write integrity
- evaluation result mapping
- mastery updates
- adaptation decisions

Medium priority:

- planning output schema validation
- navigation state
- dashboard composition

Lower priority:

- pixel-perfect snapshots early on

## 14. Anti-patterns to avoid

- storing generated HTML as the primary lesson model
- letting the LLM generate raw SwiftUI to define lessons
- combining planning, evaluation, and tutor logic in one god service
- making the session workspace behave like a generic chat screen
- generating months of detailed sessions up front

## 15. Minimal first subject assumptions

If the first subject is programming-oriented, the architecture should support:

- code examples
- code exercises
- text explanations
- short quizzes
- reflective prompts

This does not require a full remote code execution system in v1.

It is acceptable to start with:

- structured code exercises
- expected-answer metadata
- heuristic evaluation

## 16. Future-safe extension points

The architecture should leave room for:

- retrieval augmentation
- richer review scheduling
- multiple subject templates
- project-based learning
- stronger code execution/evaluation
- instructor-authored content packs

## 17. Final engineering heuristic

If a new implementation choice increases determinism, testability, and structured control over the learning loop, it is probably good.

If it pushes the app toward "LLM generates everything and the app just displays it," it is probably the wrong direction.
