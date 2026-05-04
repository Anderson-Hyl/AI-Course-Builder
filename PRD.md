# PRD.md

# AI Course Builder

## 1. Summary

AI Course Builder is a native learning app that transforms a broad learning goal into an adaptive, session-based program.

Example:

- user goal: "I want to learn Haskell"
- product output: a structured journey with stages, near-term sessions, practice, review, and adaptation

This product is not a course marketplace and not a chat app with educational branding. It is a focused learning workspace.

## 2. Problem

Most learners can state a meaningful goal, but they cannot reliably translate that goal into a practical daily plan.

Existing products often fail in one of these ways:

- they give too much static content
- they depend too much on passive reading
- they do not validate learning
- they do not adapt after the learner struggles
- they ask the user to do too much planning

## 3. Product thesis

The product should continuously compress a large goal into a manageable next step.

Core loop:

`Goal -> Program -> Session -> Practice -> Check -> Adapt`

The user should feel:

- I know what to do today
- I know why I am doing it
- I can verify whether I understood it
- the app is adjusting to me

## 4. Target user

Primary user:

- self-directed learner
- motivated but inconsistent
- wants structure, not just information
- comfortable with software, not necessarily technical

Initial ideal use case:

- technical or knowledge-heavy topics
- examples: Haskell, SQL, networking, algorithms, statistics

## 5. Primary use case

### Input

The user enters a broad goal:

- "I want to learn Haskell"

### System response

The app:

1. accepts the goal
2. infers defaults
3. generates a high-level program
4. expands only near-term sessions
5. starts today's lesson
6. evaluates performance
7. adapts future work

## 6. MVP scope

The MVP should focus on one strong path only.

### In scope

- goal intake
- program blueprint generation
- home dashboard
- session workspace
- structured lesson blocks
- practice capture
- lightweight evaluation
- review recommendations
- basic adaptation
- progress tracking

### Out of scope

- course marketplace
- collaborative classrooms
- social/community features
- rich content authoring by end users
- visual graph editors
- credentialing/certificates
- multi-subject branded asset systems

## 7. UX principles

- session-first, not chat-first
- adaptive, not static
- structured, not open-ended
- calm and focused, not gamified noise
- progress visible, but secondary to learning

## 8. Core screens

### 8.1 Goal Intake

Purpose:

- capture the goal
- capture initial assumptions
- reduce setup friction

User actions:

- enter goal
- pick starting level
- pick time budget
- preview plan
- start learning

### 8.2 Home Dashboard

Purpose:

- orient the learner quickly
- show what matters today

Content:

- current journey title
- current stage
- current sprint
- today's session card
- weak spots
- recommended review
- weekly milestone

### 8.3 Session Workspace

Purpose:

- be the main learning surface

Structure:

- lesson flow
- learning content
- practice
- tutor/help
- result/feedback

### 8.4 Program Map

Purpose:

- show the route
- show where the learner is
- make future stages visible without overwhelming detail

### 8.5 Review Vault

Purpose:

- surface mistakes
- recover weak concepts
- drive spaced review

## 9. Session model

Each session should be a structured sequence, not a free-form page.

Recommended sequence:

1. Why
2. Concept
3. Example
4. Practice
5. Check
6. Reflect

Each session should end with:

- user attempts
- system assessment
- next-step decision

## 10. Content model

The app should render lessons from structured content blocks.

Initial block types:

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

The system should store content as structured data, not raw page code.

## 11. Personalization model

The system should track three things:

### 11.1 Concept state

What concepts has the learner encountered?

### 11.2 Competency state

What can the learner actually do?

### 11.3 Artifact state

What has the learner produced?

Examples:

- code attempts
- explanations
- solved exercises
- reflection notes

## 12. Adaptation logic

The app should adapt using:

- correctness
- retry count
- time spent
- confidence
- recent mistake patterns
- review success

Possible system actions:

- advance normally
- insert a simpler follow-up
- insert a review card
- schedule a recovery session
- delay the next stage

## 13. LLM responsibilities

### Use the LLM for

- decomposing goals
- generating program blueprints
- drafting sessions
- drafting exercises
- generating hints
- writing feedback
- adapting near-term plans

### Do not rely on the LLM for

- UI layout
- deterministic scoring
- durable progress state
- source truth for references

## 14. Success criteria for MVP

The MVP is successful if a learner can:

1. enter a large goal
2. receive a believable plan
3. start a session immediately
4. complete practice inside the app
5. receive clear feedback
6. return tomorrow and get a sensible next session

## 15. MVP example: Learn Haskell

### High-level program

- Stage 1: expressions, functions, types
- Stage 2: pattern matching and algebraic data types
- Stage 3: recursion and higher-order functions
- Stage 4: typeclasses and functional abstractions
- Stage 5: I/O and errors
- Stage 6: mini project

### Near-term expansion

Only Stage 1 and the current sprint are detailed in full.

### Session example

Session title:

- Reading Type Signatures

Blocks:

- concept
- example
- code exercise
- checkpoint
- reflection

## 16. Open product decisions

These do not block MVP but should be tracked:

- how much retrieval is needed in v1
- whether coding exercises run locally, remotely, or in a mocked evaluator
- whether sessions are fixed-length or elastic
- how strongly review should interrupt forward progress
- whether the first technical vertical should be "programming languages" only

## 17. Product heuristic

If a feature helps the app reliably convert a broad goal into today's achievable session, it is likely on strategy.

If a feature mainly makes the app feel like a generic AI chat product, it is likely off strategy.
