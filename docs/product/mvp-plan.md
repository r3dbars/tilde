# MVP Plan

## Goal

Build the smallest Mac autocomplete prototype that can prove or disprove the user experience.

The first prototype should feel like a quiet writing assist, not a chatbot.

## User Loop

1. User types in an allowed app.
2. App reads nearby text and cursor position.
3. Local model predicts a short continuation.
4. Suggestion appears near the cursor.
5. User presses `Tab` to accept the next word.
6. User presses `Esc` or keeps typing to dismiss/refresh.

## Prototype Milestones

### 1. Mac Plumbing

- menu bar app
- Accessibility onboarding
- frontmost app detection
- focused text element detection
- caret rectangle detection
- small floating panel

### 2. Insertion

- accept next word with `Tab`
- dismiss with `Esc`
- insert through AX selected text when possible
- fall back to clipboard paste when needed
- preserve clipboard when possible

### 3. Completion Engine

- start with a mock/static completion engine
- then use Ollama or local llama.cpp for real continuations
- keep output short
- hard cap latency target under 700ms for the first useful build

### 4. Private Beta

- test with 3-5 people
- log only local aggregate counters at first
- collect qualitative feedback manually

## Things To Watch

- Accessibility APIs vary a lot by app.
- Password fields and secure fields must suppress suggestions.
- Browser and Electron apps may need extra AX nudges.
- Clipboard fallback can annoy people if it corrupts clipboard state.
- True inline ghost text is much harder than a floating suggestion panel.

