import Foundation
import LearningModels

/// Seed data for the Haskell demo program installed on first launch
/// after Goal Intake. Lives in `LearningRepository` (not `LessonRendering`)
/// so the seed module doesn't transitively pull SwiftUI into engines —
/// `LessonRendering` depends on `LearningUI`/`Textual`, which are SwiftUI
/// graphs we don't want leaking into the planner / evaluator / adaptation
/// surface area.
///
/// Content here is intentionally a near-copy of
/// `LessonRendering.Fixtures.haskellSessionBlocks`. That file stays
/// internal to LessonRendering for SwiftUI Previews; this file is the
/// production source of truth for "what gets persisted on first run".
/// The duplication is small and stable — bump only when block payload
/// shapes change, which is itself a `BlockPayload.*` schema bump.
enum DemoBlueprint {
    static let summary = "A focused intro to Haskell: pure functions, types, pattern matching, and small composable programs."
    static let stageTitle = "Stage 1 · Expressions, Functions, Types"
    static let stageIntent = "Build comfort with the building blocks of every Haskell program."
    static let sprintTitle = "Sprint 1 · Reading and Writing Pure Functions"
    static let sprintFocus = "Tell pure from impure code; rewrite an impure example."
    static let sessionTitle = "Lesson 3 · Pure Functions"
    static let sessionObjective = "Distinguish pure from impure functions and rewrite a small example into a pure form."
    static let sessionEstimatedMinutes = 15

    /// Builds the 10 SessionBlock rows for the Haskell demo session.
    /// Block IDs are freshly generated on each call so re-installing
    /// after a goal reset produces clean rows; ordering is 1…10 so the
    /// Schema.swift INSERT trigger leaves block 1's order at 1 and lets
    /// blocks 2–10 pass through unchanged.
    static func blocks(forSession sessionID: Session.ID) -> [SessionBlock] {
        var blocks: [SessionBlock] = []
        var order = 1

        func append<P: Encodable>(kind: String, payload: P) {
            let json = (try? Self.encoded(payload)) ?? "{}"
            blocks.append(
                SessionBlock(
                    id: UUID(),
                    sessionID: sessionID,
                    order: order,
                    kind: kind,
                    schemaVersion: 1,
                    payloadJSON: json
                )
            )
            order += 1
        }

        append(
            kind: BlockKind.title,
            payload: BlockPayload.Title(text: "Lesson 3 · Pure Functions")
        )
        append(
            kind: BlockKind.objective,
            payload: BlockPayload.Objective(
                statement: "Distinguish pure from impure functions and rewrite a small example into a pure form."
            )
        )
        append(
            kind: BlockKind.concept,
            payload: BlockPayload.Concept(
                heading: "What makes a function pure?",
                body: "A function is pure when its result is determined entirely by its arguments and it produces no observable side effects — no writing to the outside world, no reading shared state. The same input always yields the same output, which makes pure functions easy to test, easy to compose, and safe to memoize.",
                callout: "A pure function depends only on its inputs and produces no observable side effects."
            )
        )
        append(
            kind: BlockKind.example,
            payload: BlockPayload.Example(
                heading: "Pure vs impure",
                prose: "The first version writes to standard output — that's a side effect. The second version returns a String, leaving the caller in control of what to do with it.",
                code: """
                -- Impure: side effect (IO)
                greet :: String -> IO ()
                greet name = putStrLn ("Hello, " ++ name)

                -- Pure: just data
                greeting :: String -> String
                greeting name = "Hello, " ++ name
                """,
                language: "haskell"
            )
        )
        append(
            kind: BlockKind.codeExercise,
            payload: BlockPayload.CodeExercise(
                prompt: "Rewrite `greet` so it returns a `String` instead of using `putStrLn`. Keep the greeting text identical.",
                language: "haskell",
                starterCode: """
                greet :: String -> IO ()
                greet name = putStrLn ("Hello, " ++ name)
                """,
                expectedSolution: """
                greet :: String -> String
                greet name = "Hello, " ++ name
                """,
                rubric: "Function must have type `String -> String` and contain no IO. Greeting text unchanged."
            )
        )
        append(
            kind: BlockKind.multipleChoice,
            payload: BlockPayload.MultipleChoice(
                question: "Which of these is a pure function?",
                options: [
                    "putStrLn \"hello\"",
                    "getCurrentTime",
                    "\\x -> x * x",
                    "readFile \"notes.txt\"",
                ],
                correctIndex: 2,
                explanation: "Only the third option is pure — it depends solely on its argument and returns the same value for the same input. The others touch the outside world."
            )
        )
        append(
            kind: BlockKind.shortAnswer,
            payload: BlockPayload.ShortAnswer(
                question: "Define referential transparency in your own words.",
                expectedAnswer: "An expression is referentially transparent when it can be replaced with its value without changing the program's behavior. This is a defining property of pure expressions.",
                rubric: "Mentions substitutability and absence of side effects. Bonus for connecting to pure functions."
            )
        )
        append(
            kind: BlockKind.reflection,
            payload: BlockPayload.Reflection(
                prompt: "Where in your own code have you mixed pure and impure logic? What's one place you could split them apart?"
            )
        )
        append(
            kind: BlockKind.checkpoint,
            payload: BlockPayload.Checkpoint(
                prompt: "How confident are you that you could write a pure function from scratch right now?",
                scaleMin: 1,
                scaleMax: 5,
                scaleLabels: ["Lost", "Shaky", "Okay", "Solid", "Could teach it"]
            )
        )
        append(
            kind: BlockKind.reviewCard,
            payload: BlockPayload.ReviewCard(
                conceptID: "11111111-1111-1111-1111-111111111111",
                front: "Define: pure function.",
                back: "A function whose output depends only on its inputs and which has no observable side effects."
            )
        )

        return blocks
    }

    private static func encoded<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }
}
