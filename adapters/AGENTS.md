# Adapter Guide

Adapters belong here when the universal macOS overlay is not the right way to make autocomplete feel native.

- Keep adapter code small and experimental.
- Do not move local model execution into adapters.
- Treat the macOS app as the local runtime and policy owner.
- Prefer editor-native rendering APIs over DOM or Accessibility hacks when available.
- Do not capture or persist typed text in adapter code.
