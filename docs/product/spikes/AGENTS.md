# Spikes Agent Guide

This folder holds **spikes**: throwaway-friendly design docs plus minimal
proof-of-concept code for ideas we want to de-risk before committing.

- A spike is an experiment, not a shipping feature. Each doc must end with a
  clear **graduate or discard** recommendation.
- Keep spike code small and isolated behind a flag or protocol seam so it is
  cheap to delete. Say exactly which files to remove to throw it away.
- Privacy is still a product requirement here. A spike may not relax the
  local-first, opt-in stance, and it must name the proof gates graduation would
  need (it does not get to skip them).
- Separate what the spike actually proved from what is still a guess.
- Name docs `*-spike` or keep them in this folder; date them.
