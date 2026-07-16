# Claude Code Guide

This folder owns pure parsing, indexing, retrieval, and prediction over the opted-in Personal Capture corpus.

- Keep indexes bounded and Codable.
- Index every daily journal file; decay and caps bound old data.
- Keep retrieval synchronous and deterministic.
- Keep a field's selected prompt context stable until focus or the memory snapshot changes.
- Preserve the journal writer's variable-length fenced-code contract.
- Add focused core tests for every behavior change.
