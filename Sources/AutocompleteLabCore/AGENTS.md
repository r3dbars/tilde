# AutocompleteLabCore Guide

This target holds pure Swift behavior.

- No AppKit.
- No Accessibility APIs.
- No model runtime process management.
- Add unit tests for every behavior change.
- Runtime choice policy can live here, but native runtime bindings belong outside pure product logic.
- Text handling should preserve Unicode correctly.
