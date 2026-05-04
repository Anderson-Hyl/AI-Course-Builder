/// Hint / reframing / encouragement engine. Lives in the Session Workspace's
/// secondary panel. Owns LLM calls via `ChatClients` for contextual help.
/// Crucially, does NOT own progress state — that's the repository's job.
///
/// **Placeholder this pass** — first hint path lands when the Session
/// Workspace renderer is wired up (after `LessonRendering`). Per
/// `ARCHITECTURE.md §4.7` this engine handles hints, reframed
/// explanations, encouragement, and contextual help.
public enum TutorEngine {}
