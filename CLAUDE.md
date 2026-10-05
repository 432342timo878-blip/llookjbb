# Track & Field Career Game (Godot)

In-depth career mode track and field (yleisurheilu) game, built in Godot together with the user.

**Status:** design phase — gathering requirements. No code yet. Design doc will live in `docs/GDD.md`.

## Working rules
- **Model recommendation:** start every reply with a line saying which model the user should use for their *next* message:
  `**Next message: Opus** / **Next message: Sonnet**` (+ suggested effort: low / medium / high).
  - Opus: design discussions, architecture, complex systems, hard bugs.
  - Sonnet: routine GDScript implementation, small features, fixes.
- Keep sessions focused on one task; record decisions in docs, not just chat.
- Commit and push at the end of every work session.
