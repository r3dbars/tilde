# Personalization Guide

- Keep personalization pure, local-first, and opt-in at the app boundary.
- Never put remembered text in trace metadata.
- Filter secret-shaped text before indexing or suggesting it.
- Personal context is for phrase and sentence continuation only, never word completion.
- Read the full opted-in journal corpus; use decay and hard caps instead of a date cutoff.
- Keep the retrieved context stable within a focused field so prompt-prefix caching can work.
