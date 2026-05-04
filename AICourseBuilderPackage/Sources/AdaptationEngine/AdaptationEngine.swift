/// Next-step decision engine. Takes a mastery snapshot + recent attempts
/// + current blueprint position and decides what comes next: advance,
/// insert a simpler follow-up, insert a review card, schedule a recovery
/// session, delay the next stage.
///
/// **Placeholder this pass** — first adaptation logic lands once
/// `EvaluationEngine` is producing real signal. Per `ARCHITECTURE.md
/// §4.6` outputs are: next session request, review insertion,
/// remediation action. Per `PRD §12` the inputs are: correctness, retry
/// count, time spent, confidence, recent mistake patterns, review
/// success.
public enum AdaptationEngine {}
