# Dasher (MacKay and the Inference Group)

**Source:** https://dasher.at/ (project); MacKay, Ball & Donegan, "Efficient communication by breathing," and the Dasher papers linked from the site.
**License:** Project site and papers vary; treat as link-and-attribute. Do not vendor Dasher.

## What it does (plain words)

Dasher turns writing into steering through a probability landscape. Likely next letters take more screen space. You point; the interface zooms. The information-theoretic claim is the part Tilde needs: every gesture should buy bits, and the interface should spend the user's attention in proportion to surprise.

## Method

A language model paints letter boxes sized by probability. Users write by flying into the box they want. Evaluations historically focused on bits per second and words per minute for pointer, eye-gaze, and switch users — often people for whom a keyboard is costly.

## Key findings

- Keystrokes-saved is an information measure in disguise: you are trying to transmit the next characters with fewer decisions.
- A wrong large target is worse than a missing one, because the user has already steered toward it.
- Personal language models matter because the landscape should match this writer, not English-in-general.

## What Tilde should take from it

Tilde's north-star (retained useful characters, interruption-adjusted) is Dasher's bits-per-decision test without the zooming UI. Do not build Dasher inside macOS.

The design rule that transfers: spend the owner's glance only when the ghost removes many bits. A one-character completion of a common word fails that test (Quinn said the same with taps). A three-word phrase the owner was about to type passes it.

Personal History is how Tilde warps the landscape. Interpolation (Smart Compose / Shao 2020) is the boring implementation; Dasher is the reason it matters.

## Limits and caveats

Dasher is a replacement keyboard, not an IME overlay. Its users often cannot touch-type at 70 WPM. Screen-space-as-probability does not map onto marked text. Use the information argument, not the widget.
