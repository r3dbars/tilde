# AutocompleteLabResearch Guide

This non-shipping target owns experiments, proof harnesses, replay logic, and research-only helpers.

- Depend on `AutocompleteLabCore`; never make the shipping app depend on this target.
- Keep local tools and deterministic tests working.
- Do not add AppKit, Accessibility, MLX bindings, or private user data.
