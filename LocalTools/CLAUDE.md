# Claude Code Guide

This tree holds local-only helpers that are intentionally outside the shipping package targets.

Preserve the shipping boundary when editing here. If a helper becomes a package source, update `Package.swift`, the shipping-boundary checker, and its coverage ownership in the same change.
