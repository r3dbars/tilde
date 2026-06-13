# KV Prefix Cache + Stream-First Spike

Date: 2026-06-12

## Verdict

`mlx-swift-lm` 3.31.3 exposes real KV cache surfaces, but SteadyType should not
reuse prefix state in the autocomplete runtime until the cache owner can prove an
exact token-prefix match for the current edit.

Stream-first display is already the safer latency win. The app streams MLX
chunks, cleans the growing text, and presents only useful partials after the same
request, field, text freshness, placement, repetition, and display-score gates as
final suggestions. This spike adds explicit first-useful-partial latency metadata
so local reports can tell whether streaming helped before final output arrived.

## Current MLX Surfaces

Pinned dependency:

- `mlx-swift-lm` 3.31.3 at `1c05248bb0899e2a7a4962b84d319cf12f4e12aa`
- `mlx-swift` 0.31.3 at `61b9e011e09a62b489f6bd647958f1555bdf2896`

Useful APIs in this version:

- `ChatSession(_:cache:generateParameters:)`
- `ChatSession.saveCache(to:)`
- `loadPromptCache(url:)`
- `savePromptCache(url:cache:metadata:)`
- `KVCache.copy()`
- `trimPromptCache(_:numTokens:)`
- lower-level `TokenIterator(input:model:cache:parameters:)`

Important behavior:

- `ChatSession` is not thread-safe.
- Its cache is mutable and continues from prior generations.
- A cache restored from a session that already encoded system instructions must
  not receive those same instructions again.
- The current SteadyType runtime builds a fresh `ChatSession` per request and
  only caches the static system prompt string, not KV state.

## Why KV Reuse Is Nontrivial

Autocomplete requests are edits, not chat turns. The dynamic prompt includes
current `textBeforeCursor`, `textAfterCursor`, field kind, behavior profile, and
visible context. Reusing a cache after the user edits earlier text, switches
fields, changes text after the cursor, or receives generated output would make
the model continue from stale state.

The existing `RuntimeSessionCachePolicy` is a good eligibility signal, but it is
metadata-only today. It says when a request grew in the same app, field,
paragraph, sentence, and mode. It does not prove that MLX chat-template tokens
match an existing cache prefix.

## Safe KV Design

Implement only after a narrow cache owner can prove all of this:

- Cache key includes model revision, prompt style, system prompt fingerprint,
  app, field identity, field kind, behavior profile, request mode, and text after
  cursor.
- Reuse requires current prompt tokens to have the cached prompt tokens as an
  exact prefix.
- Generated assistant/output tokens are never reused as input prefix for a later
  autocomplete edit.
- Cache values are copied per request before generation.
- Cancellation waits for MLX cache use to stop before returning a cache to the
  pool.
- Edits that do not strictly append to the same sentence reset the cache.
- Memory is bounded by cache count, token count, and active MLX memory.

## Tests Before Runtime Surgery

Add tests before enabling KV reuse:

- same-field append can reuse only when token prefix matches exactly,
- middle edit resets,
- text-after-cursor change resets,
- field/app/mode/profile change resets,
- generated output is not reused across requests,
- cancellation cannot publish a half-mutated cache,
- cache copy isolation proves one request cannot mutate another request,
- soak test records active memory across repeated request/cancel cycles.

## Stream-First Metadata Added

Streaming partial presentation now records:

- `streamingPartialIndex`
- `streamingPartialVisibleCharacters`
- `streamingFirstPartialLatencyMilliseconds`
- `streamingLastPartialLatencyMilliseconds`

These values are attached only after the existing streaming partial gate approves
the partial, and before `presentSuggestion` runs the normal freshness and display
safety checks. This does not make unsafe or stale text visible sooner.

## Next Spike Command

Use a local model run to compare first-useful partial latency against final
latency:

```sh
./script/fresh_latency_proof.sh
```

If a model asset is not installed, use the runtime/performance report path and
look for `model-stream` presentations plus the new streaming metadata in the raw
trace.
