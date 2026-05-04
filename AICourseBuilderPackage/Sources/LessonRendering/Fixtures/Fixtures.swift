import Foundation
import LearningModels

/// Hardcoded `SessionBlock` rows for Previews and tests. Three domain
/// fixtures (Haskell programming, high-school Math, high-school
/// Chemistry) prove the renderer is subject-agnostic; three edge-case
/// fixtures exercise the placeholder paths.
///
/// Stable readable UUIDs (`…0001`, `…00FFFF`) per CLAUDE.md test fixture
/// convention so test failures point at the right row immediately.
enum Fixtures {
    static let haskellSessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let mathSessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let chemistrySessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    // MARK: - Haskell session (programming)

    static let haskellSessionBlocks: [SessionBlock] = [
        block(
            id: 0x01, sessionID: haskellSessionID, order: 1, kind: BlockKind.title,
            payload: BlockPayload.Title(text: "Lesson 3 · Pure Functions")
        ),
        block(
            id: 0x02, sessionID: haskellSessionID, order: 2, kind: BlockKind.objective,
            payload: BlockPayload.Objective(
                statement: "Distinguish pure from impure functions and rewrite a small example into a pure form."
            )
        ),
        block(
            id: 0x03, sessionID: haskellSessionID, order: 3, kind: BlockKind.concept,
            payload: BlockPayload.Concept(
                heading: "What makes a function pure?",
                body: "A function is pure when its result is determined entirely by its arguments and it produces no observable side effects — no writing to the outside world, no reading shared state. The same input always yields the same output, which makes pure functions easy to test, easy to compose, and safe to memoize.",
                callout: "A pure function depends only on its inputs and produces no observable side effects."
            )
        ),
        block(
            id: 0x04, sessionID: haskellSessionID, order: 4, kind: BlockKind.example,
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
        ),
        block(
            id: 0x05, sessionID: haskellSessionID, order: 5, kind: BlockKind.codeExercise,
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
        ),
        block(
            id: 0x06, sessionID: haskellSessionID, order: 6, kind: BlockKind.multipleChoice,
            payload: BlockPayload.MultipleChoice(
                question: "Which of these is a pure function?",
                options: [
                    "putStrLn \"hello\"",
                    "getCurrentTime",
                    "\\x -> x * x",
                    "readFile \"notes.txt\""
                ],
                correctIndex: 2,
                explanation: "Only the third option is pure — it depends solely on its argument and returns the same value for the same input. The others touch the outside world."
            )
        ),
        block(
            id: 0x07, sessionID: haskellSessionID, order: 7, kind: BlockKind.shortAnswer,
            payload: BlockPayload.ShortAnswer(
                question: "Define referential transparency in your own words.",
                expectedAnswer: "An expression is referentially transparent when it can be replaced with its value without changing the program's behavior. This is a defining property of pure expressions.",
                rubric: "Mentions substitutability and absence of side effects. Bonus for connecting to pure functions."
            )
        ),
        block(
            id: 0x08, sessionID: haskellSessionID, order: 8, kind: BlockKind.reflection,
            payload: BlockPayload.Reflection(
                prompt: "Where in your own code have you mixed pure and impure logic? What's one place you could split them apart?"
            )
        ),
        block(
            id: 0x09, sessionID: haskellSessionID, order: 9, kind: BlockKind.checkpoint,
            payload: BlockPayload.Checkpoint(
                prompt: "How confident are you that you could write a pure function from scratch right now?",
                scaleMin: 1,
                scaleMax: 5,
                scaleLabels: ["Lost", "Shaky", "Okay", "Solid", "Could teach it"]
            )
        ),
        block(
            id: 0x0A, sessionID: haskellSessionID, order: 10, kind: BlockKind.reviewCard,
            payload: BlockPayload.ReviewCard(
                conceptID: "11111111-1111-1111-1111-111111111111",
                front: "Define: pure function.",
                back: "A function whose output depends only on its inputs and which has no observable side effects."
            )
        ),
    ]

    // MARK: - High-school Math session (Pythagorean Theorem)

    static let mathSessionBlocks: [SessionBlock] = [
        block(
            id: 0xB1, sessionID: mathSessionID, order: 1, kind: BlockKind.title,
            payload: BlockPayload.Title(text: "Lesson · The Pythagorean Theorem")
        ),
        block(
            id: 0xB2, sessionID: mathSessionID, order: 2, kind: BlockKind.objective,
            payload: BlockPayload.Objective(
                statement: "Use a² + b² = c² to find the unknown side length of a right triangle."
            )
        ),
        block(
            id: 0xB3, sessionID: mathSessionID, order: 3, kind: BlockKind.concept,
            payload: BlockPayload.Concept(
                heading: "Right triangles and the theorem",
                body: "In any right triangle, the square of the hypotenuse (the side opposite the right angle) equals the sum of the squares of the other two sides. If the legs have lengths a and b and the hypotenuse has length c, then a² + b² = c². The relationship runs both ways: any triangle whose sides satisfy a² + b² = c² is a right triangle.\n\n(Future renderer: a dedicated `equation` block kind will render this with proper math typesetting. For now, plain text with Unicode superscripts.)",
                callout: "The hypotenuse is always the longest side and sits opposite the right angle."
            )
        ),
        block(
            id: 0xB4, sessionID: mathSessionID, order: 4, kind: BlockKind.example,
            payload: BlockPayload.Example(
                heading: "Worked example: find the hypotenuse",
                prose: "Suppose a right triangle has legs of length 3 and 4. We want to find the hypotenuse c.\n\nApplying the theorem:\n  a² + b² = c²\n  3² + 4² = c²\n  9 + 16 = c²\n  25 = c²\n  c = 5\n\nThe famous 3–4–5 right triangle. Notice all three sides are whole numbers — that's a Pythagorean triple."
            )
        ),
        block(
            id: 0xB5, sessionID: mathSessionID, order: 5, kind: BlockKind.multipleChoice,
            payload: BlockPayload.MultipleChoice(
                question: "A right triangle has legs of length 6 and 8. What is the length of the hypotenuse?",
                options: ["10", "12", "14", "√48"],
                correctIndex: 0,
                explanation: "6² + 8² = 36 + 64 = 100, so c = √100 = 10. This is a 6–8–10 triangle (a scaled-up 3–4–5)."
            )
        ),
        block(
            id: 0xB6, sessionID: mathSessionID, order: 6, kind: BlockKind.shortAnswer,
            payload: BlockPayload.ShortAnswer(
                question: "State the Pythagorean Theorem in your own words.",
                expectedAnswer: "In a right triangle, the square of the hypotenuse equals the sum of the squares of the other two sides.",
                rubric: "Mentions right triangle, hypotenuse, and the squared-sum relationship."
            )
        ),
        block(
            id: 0xB7, sessionID: mathSessionID, order: 7, kind: BlockKind.reflection,
            payload: BlockPayload.Reflection(
                prompt: "Where outside of math class might you use the Pythagorean Theorem? (Hint: think about distance, building, or screens.)"
            )
        ),
        block(
            id: 0xB8, sessionID: mathSessionID, order: 8, kind: BlockKind.checkpoint,
            payload: BlockPayload.Checkpoint(
                prompt: "How confident are you that you could find a missing side of a right triangle right now?",
                scaleMin: 1,
                scaleMax: 5,
                scaleLabels: ["Lost", "Shaky", "Okay", "Solid", "Could teach it"]
            )
        ),
        block(
            id: 0xB9, sessionID: mathSessionID, order: 9, kind: BlockKind.reviewCard,
            payload: BlockPayload.ReviewCard(
                conceptID: "22222222-2222-2222-2222-222222222222",
                front: "State the Pythagorean Theorem.",
                back: "In a right triangle with legs a and b and hypotenuse c: a² + b² = c²."
            )
        ),
    ]

    // MARK: - High-school Chemistry session (Balancing Equations)

    static let chemistrySessionBlocks: [SessionBlock] = [
        block(
            id: 0xC1, sessionID: chemistrySessionID, order: 1, kind: BlockKind.title,
            payload: BlockPayload.Title(text: "Lesson · Balancing Chemical Equations")
        ),
        block(
            id: 0xC2, sessionID: chemistrySessionID, order: 2, kind: BlockKind.objective,
            payload: BlockPayload.Objective(
                statement: "Balance simple chemical equations by applying the law of conservation of mass."
            )
        ),
        block(
            id: 0xC3, sessionID: chemistrySessionID, order: 3, kind: BlockKind.concept,
            payload: BlockPayload.Concept(
                heading: "Conservation of mass",
                body: "Atoms are not created or destroyed in a chemical reaction — they're rearranged. So the same number of each atom must appear on both sides of the equation. We balance equations by placing whole-number coefficients in front of each formula until the atom counts match. We never change subscripts inside a formula — that would change which substance we're describing.\n\n(Future renderer: a dedicated `chem_equation` block will use mhchem-style notation with arrows and subscripts. For now, plain text with Unicode subscripts.)",
                callout: "Coefficients balance equations. Subscripts define substances. Don't confuse the two."
            )
        ),
        block(
            id: 0xC4, sessionID: chemistrySessionID, order: 4, kind: BlockKind.example,
            payload: BlockPayload.Example(
                heading: "Worked example: hydrogen + oxygen → water",
                prose: "Start with the unbalanced equation:\n  H₂ + O₂ → H₂O\n\nCount atoms:\n  Left:  H = 2, O = 2\n  Right: H = 2, O = 1     (oxygen is off)\n\nPlace a 2 in front of H₂O to balance oxygen:\n  H₂ + O₂ → 2 H₂O\n  Left:  H = 2, O = 2\n  Right: H = 4, O = 2     (now hydrogen is off)\n\nPlace a 2 in front of H₂ to balance hydrogen:\n  2 H₂ + O₂ → 2 H₂O\n  Left:  H = 4, O = 2\n  Right: H = 4, O = 2     ✓ balanced"
            )
        ),
        block(
            id: 0xC5, sessionID: chemistrySessionID, order: 5, kind: BlockKind.multipleChoice,
            payload: BlockPayload.MultipleChoice(
                question: "Which is the correctly balanced form of methane combustion: CH₄ + O₂ → CO₂ + H₂O?",
                options: [
                    "CH₄ + O₂ → CO₂ + H₂O",
                    "CH₄ + 2 O₂ → CO₂ + 2 H₂O",
                    "2 CH₄ + O₂ → 2 CO₂ + H₂O",
                    "CH₄ + 3 O₂ → CO₂ + 2 H₂O"
                ],
                correctIndex: 1,
                explanation: "Carbon balances 1↔1. Hydrogen needs 2 H₂O on the right (4 H). That makes oxygen 4 (from H₂O) + 2 (from CO₂) = 4 on each side, so 2 O₂ on the left."
            )
        ),
        block(
            id: 0xC6, sessionID: chemistrySessionID, order: 6, kind: BlockKind.shortAnswer,
            payload: BlockPayload.ShortAnswer(
                question: "Why must a chemical equation be balanced?",
                expectedAnswer: "Because atoms are conserved in a chemical reaction — they're only rearranged, never created or destroyed. The same count of each atom must appear on both sides of the arrow.",
                rubric: "Mentions conservation of mass / atoms. Bonus for distinguishing rearrangement from creation/destruction."
            )
        ),
        block(
            id: 0xC7, sessionID: chemistrySessionID, order: 7, kind: BlockKind.reflection,
            payload: BlockPayload.Reflection(
                prompt: "Pick a chemical reaction that happens in everyday life (cooking, rusting, photosynthesis…). What's being conserved when it happens?"
            )
        ),
        block(
            id: 0xC8, sessionID: chemistrySessionID, order: 8, kind: BlockKind.checkpoint,
            payload: BlockPayload.Checkpoint(
                prompt: "How confident are you that you could balance a simple equation on your own?",
                scaleMin: 1,
                scaleMax: 5,
                scaleLabels: ["Lost", "Shaky", "Okay", "Solid", "Could teach it"]
            )
        ),
        block(
            id: 0xC9, sessionID: chemistrySessionID, order: 9, kind: BlockKind.reviewCard,
            payload: BlockPayload.ReviewCard(
                conceptID: "33333333-3333-3333-3333-333333333333",
                front: "Why do chemical equations need to be balanced?",
                back: "Atoms are conserved — the same number of each element must appear on both sides of the equation."
            )
        ),
    ]

    // MARK: - Edge-case fixtures

    static let unknownKindBlock = SessionBlock(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000FFFF")!,
        sessionID: haskellSessionID,
        order: 99,
        kind: "alien",
        schemaVersion: 1,
        payloadJSON: "{}"
    )

    static let unsupportedVersionTitle: SessionBlock = {
        let json = (try? Self.encoded(BlockPayload.Title(text: "From the future"))) ?? "{}"
        return SessionBlock(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000FFFE")!,
            sessionID: haskellSessionID,
            order: 98,
            kind: BlockKind.title,
            schemaVersion: 99,
            payloadJSON: json
        )
    }()

    static let malformedConcept = SessionBlock(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000FFFD")!,
        sessionID: haskellSessionID,
        order: 97,
        kind: BlockKind.concept,
        schemaVersion: 1,
        payloadJSON: "{not-valid-json"
    )

    // MARK: - Helpers

    private static func block<P: Encodable>(
        id: Int,
        sessionID: UUID,
        order: Int,
        kind: String,
        payload: P
    ) -> SessionBlock {
        SessionBlock(
            id: makeID(id),
            sessionID: sessionID,
            order: order,
            kind: kind,
            schemaVersion: 1,
            payloadJSON: (try? encoded(payload)) ?? "{}"
        )
    }

    private static func makeID(_ tail: Int) -> UUID {
        let suffix = String(format: "%012X", tail & 0xFFFFFFFFFFFF)
        return UUID(uuidString: "00000000-0000-0000-0000-\(suffix)")!
    }

    static func encoded<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }
}
