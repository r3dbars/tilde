# Local Tools

Keep machine-local research and proof helpers here when they must not ship in a SwiftPM product.

- Do not add this directory to the `SteadyType` product dependency graph.
- Keep user-data handling local, explicit, and covered by tests or proof scripts.
- Put reusable shipping behavior in `AutocompleteLabCore`; put research behavior in `Sources/AutocompleteLabResearch`.
