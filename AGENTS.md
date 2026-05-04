# AGENTS.md

This file provides guidance to Codex and other coding agents when working on **AI Course Builder**.

## Project purpose

AI Course Builder is a native learning app that turns a large user goal, such as "I want to learn Haskell", into a structured, adaptive learning program.

The product is **not** a generic chatbot and **not** a slide generator. Its core job is to continuously compress a broad goal into:

- a program
- a current sprint
- today's session
- concrete practice
- actionable feedback
- the next best step

The product should feel like a **learning workspace** rather than a course marketplace.

## Product thesis

The most important product loop is:

`Plan -> Teach -> Practice -> Check -> Adapt`

The system should not try to generate an entire long-form course up front and freeze it forever. Instead:

- generate a high-level program blueprint first
- expand only the near-term sessions in detail
- collect user attempts and artifacts
- adapt future sessions based on performance

## Core product shape

The MVP is a native app with a stable shell and a structured content renderer.

Do **not** make the product depend on hand-authored front-end pages or model-generated UI code.

Preferred approach:

- SwiftUI app shell
- structured lesson/session schema
- LLM generates content data, not raw UI layout
- app renders blocks with deterministic native components

In short:

`LLM writes content; the app owns layout, interaction, state, and progress tracking.`

## Non-goals

For MVP, avoid turning this into:

- a general LMS
- a marketplace of user-published courses
- a free-form note-taking app
- a generic chat app with a learning theme
- a full web-page builder
- a massive visual knowledge graph editor

## Primary user promise

When the user enters a large goal like "Learn Haskell", the app should:

1. accept the goal without forcing the user to rewrite it
2. infer reasonable defaults
3. generate a program blueprint
4. expand only the current stage and near-term sessions
5. deliver a focused learning session with practice
6. assess performance
7. adapt what comes next

## MVP surfaces

The initial app should focus on these screens:

### 1. Goal Intake

Captures:

- learning goal
- user starting level
- weekly time budget
- preferred learning style
- target outcome

### 2. Home Dashboard

Shows:

- current journey
- current stage
- current sprint
- today's session
- weak spots
- recommended review
- milestone progress

### 3. Session Workspace

The main work surface. This is the most important screen in the product.

Recommended structure:

- left column: lesson flow / session steps
- center column: content and practice
- right column: AI tutor, hints, mistakes, notes

### 4. Program Map

Shows the larger route:

- stages
- sessions inside the current stage
- locked future stages
- graduation goal

### 5. Review Vault

Tracks:

- weak concepts
- repeated mistakes
- due-for-review items

## Session design principle

Each learning session should use a stable structure. Avoid arbitrary page composition.

Preferred session sequence:

1. Why
2. Concept
3. Example
4. Practice
5. Check
6. Reflect

This sequence should be represented as structured data and rendered through native components.

## Content model

The content system should be block-based.

Do not ask the model to produce full view code, HTML, or handcrafted UI layout for each lesson.

Preferred block types for MVP:

- `title`
- `objective`
- `concept`
- `example`
- `code_exercise`
- `multiple_choice`
- `short_answer`
- `reflection`
- `checkpoint`
- `review_card`

Each session should be an ordered list of blocks plus metadata.

## Recommended data model

The schema can evolve, but the core concepts should stay stable:

- `LearnerProfile`
- `LearningGoal`
- `ProgramBlueprint`
- `Stage`
- `Sprint`
- `Session`
- `Block`
- `ConceptNode`
- `Competency`
- `Attempt`
- `Artifact`
- `MasteryState`
- `ReviewItem`

### Intent of the model

- `LearningGoal` stores the user request
- `ProgramBlueprint` stores the long-range route
- `Stage` and `Sprint` control sequencing
- `Session` stores one teachable unit
- `Block` powers deterministic rendering
- `Attempt` stores user answers and code work
- `Artifact` stores durable outputs such as notes, explanations, and solved exercises
- `MasteryState` represents evolving competence
- `ReviewItem` powers spaced repetition and recovery

## Learning logic

The app should maintain three internal views of progress:

### 1. Concept graph

Tracks concept dependencies.

Example for Haskell:

- expressions
- functions
- types
- pattern matching
- algebraic data types
- recursion
- higher-order functions
- typeclasses
- monads

### 2. Competency graph

Tracks what the user can actually do.

Examples:

- read a type signature
- write a recursive function
- define a simple algebraic data type
- explain `Maybe`

### 3. Artifact history

Tracks what the user has produced.

Examples:

- code attempts
- written explanations
- incorrect answers
- reflection notes

Future planning should use all three, not just "which chapter was completed."

## LLM responsibilities

LLMs are important, but they are not the whole system.

### Use LLMs for:

- goal decomposition
- near-term session generation
- exercise drafting
- hint generation
- feedback phrasing
- reflection prompt generation
- adapting future session plans

### Do not rely on LLMs alone for:

- long-range planning with no revision loop
- source verification
- deterministic scoring
- UI layout generation
- progress state integrity

## Retrieval and references

For technical subjects, the product should eventually support retrieval from trusted sources.

Use a retrieval pipeline for:

- official documentation
- trusted tutorials
- curated examples
- glossary material

Avoid letting the model invent references from memory when accuracy matters.

For MVP, it is acceptable to start with internally generated content and add retrieval later, but the system should be designed so retrieval can slot in cleanly.

## Rendering strategy

The app should be native-first.

Recommended stack:

- SwiftUI for the app shell and lesson rendering
- local persistence for goals, sessions, attempts, and review state
- structured lesson blocks rendered by reusable native views

Avoid:

- free-form model-generated SwiftUI for every lesson
- dynamic HTML page generation as the primary content path
- tightly coupling content generation to presentation code

## Editing philosophy

Users should be able to edit or regenerate content at the content level, not the raw layout level.

Examples of allowed changes:

- regenerate this session
- simplify this concept
- add one more example
- make this exercise easier
- add another checkpoint

These should operate on structured session data, not arbitrary page code.

## Personalization rules

The app should assume large goals need staged compression.

When the user enters a broad goal:

- accept it
- infer a default timeline
- generate a rough program
- expand only the next one or two weeks

Do not fully elaborate months of detailed sessions before the user has begun.

## Adaptation rules

The app should adapt based on:

- correctness
- time spent
- retry count
- error patterns
- self-reported confidence
- review performance

Future sessions should be able to:

- move forward
- slow down
- insert recovery sessions
- schedule review
- introduce a mini-project

## UI principles

The product should feel calm, focused, and structured.

Preferred traits:

- clear hierarchy
- minimal chrome
- strong center-stage learning surface
- tutor assistance visible but secondary
- progress visible without gamified noise

Avoid:

- overwhelming dashboards
- marketplace visual language
- chat-first layout
- excessive badges and rewards

## Suggested implementation strategy

Build in this order:

1. Goal Intake
2. Home Dashboard
3. Session Workspace renderer
4. Session block schema
5. Attempt capture and evaluation
6. Mastery tracking
7. Program Map
8. Review Vault
9. Adaptation engine

This order ensures the core loop works before secondary surfaces expand.

## Coding guidance

- Prefer editing existing files over creating abstractions too early.
- Keep schema small and explicit.
- Default to deterministic native rendering.
- Separate content generation from view composition.
- Avoid model-generated raw UI code as a persistence format.
- Build with testable seams around planning, evaluation, and adaptation.

## Testing priorities

Prioritize tests around:

- session block decoding/encoding
- session rendering from structured blocks
- program blueprint generation contracts
- mastery state updates
- review scheduling
- adaptation decisions
- attempt evaluation behavior

UI snapshot coverage is useful, but the highest-value tests are the ones protecting learning-state correctness and content-structure stability.

## Architecture direction

The best architectural split is:

- `App shell`: navigation, persistence, stable UI
- `Content schema`: structured learning blocks and metadata
- `Planner`: turns goals into blueprints and sessions
- `Evaluator`: checks attempts and updates state
- `Adaptation engine`: decides what comes next
- `Tutor`: explains, hints, reframes, and encourages

Try to keep these separable from day one.

## Final product heuristic

If a proposed feature makes the app feel more like "a chatbot that happens to talk about learning," it is probably the wrong direction.

If a proposed feature makes the app better at turning a huge goal into today's achievable session, it is probably the right direction.
