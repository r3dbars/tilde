# Runtime App Guide

App-owned native runtime bootstrap code lives here.

- Keep real native bindings outside `AutocompleteLabCore`.
- Do not require user-managed model servers.
- Fall back visibly and safely when the native runtime or model asset is missing.
