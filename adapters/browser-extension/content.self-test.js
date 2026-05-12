const assert = require("node:assert/strict");
const extension = require("./content.js")._test;

function fakeElement(overrides = {}) {
  const attrs = overrides.attrs || {};
  return {
    tagName: overrides.tagName || "INPUT",
    type: overrides.type || "text",
    isContentEditable: overrides.isContentEditable || false,
    getAttribute(name) {
      return attrs[name] || "";
    }
  };
}

function fakeContext(overrides = {}) {
  return {
    beforeLength: 12,
    afterLength: 0,
    trimmedBeforeLength: 12,
    totalLength: 12,
    selectedLength: 0,
    hasSelection: false,
    selectionStart: 12,
    selectionEnd: 12,
    rect: { left: 1, right: 2, top: 3, bottom: 4, width: 1, height: 1 },
    textBeforeCursor: "the raw text",
    textAfterCursor: "more raw text",
    ...overrides
  };
}

function completionRequestDoesNotIncludeRawTextByDefault() {
  const element = fakeElement();
  const payload = extension.buildCompletionRequest({
    element,
    context: fakeContext(),
    location: new URL("http://localhost/editor"),
    rawTextEnabled: false
  });

  assert.equal(payload.rawTextIncluded, false);
  assert.equal(Object.hasOwn(payload, "textBeforeCursor"), false);
  assert.equal(Object.hasOwn(payload, "textAfterCursor"), false);
  assert.equal(payload.context.beforeLength, 12);
  assert.equal(payload.location, "http://localhost");
}

function completionRequestRequiresRawTextOptIn() {
  const payload = extension.buildCompletionRequest({
    element: fakeElement(),
    context: fakeContext(),
    location: new URL("http://localhost/editor"),
    rawTextEnabled: true
  });

  assert.equal(payload.rawTextIncluded, true);
  assert.equal(payload.textBeforeCursor, "the raw text");
  assert.equal(payload.textAfterCursor, "more raw text");
}

function sensitiveFieldsAreBlocked() {
  const cases = [
    { type: "password" },
    { type: "search" },
    { autocomplete: "one-time-code" },
    { name: "api_key" },
    { ariaLabel: "Payment card number" },
    { placeholder: "Private search" }
  ];

  for (const metadata of cases) {
    assert.equal(extension.sensitiveFieldDecision(metadata).allowed, false, JSON.stringify(metadata));
  }
}

function sensitiveLocationsAreBlocked() {
  const blocked = [
    "http://example.com/editor",
    "ftp://localhost/editor",
    "http://localhost/login",
    "http://localhost/editor?search=private",
    "http://localhost/checkout/payment"
  ];

  for (const href of blocked) {
    assert.equal(extension.safeLocationDecision(new URL(href)).allowed, false, href);
  }

  assert.equal(extension.safeLocationDecision(new URL("http://localhost/editor")).allowed, true);
  assert.equal(extension.safeLocationDecision(new URL("http://127.0.0.1:5173/proof")).allowed, true);
}

function suggestionBindingsMustMatchElementAndFingerprint() {
  const element = fakeElement();
  const first = extension.createSuggestionBinding(element, fakeContext(), new URL("http://localhost/editor"));
  const same = extension.createSuggestionBinding(element, fakeContext(), new URL("http://localhost/editor"));
  const movedCaret = extension.createSuggestionBinding(
    element,
    fakeContext({ selectionStart: 13, selectionEnd: 13, beforeLength: 13, totalLength: 13 }),
    new URL("http://localhost/editor")
  );
  const otherElement = extension.createSuggestionBinding(fakeElement(), fakeContext(), new URL("http://localhost/editor"));

  assert.equal(extension.sameSuggestionBinding(first, same), true);
  assert.equal(extension.sameSuggestionBinding(first, movedCaret), false);
  assert.equal(extension.sameSuggestionBinding(first, otherElement), false);
}

function nextWordStillAcceptsOneWordOnly() {
  assert.equal(extension.nextWord(" finish this sentence"), " finish ");
  assert.equal(extension.nextWord("finish this sentence"), "finish ");
  assert.equal(extension.nextWord(""), "");
}

completionRequestDoesNotIncludeRawTextByDefault();
completionRequestRequiresRawTextOptIn();
sensitiveFieldsAreBlocked();
sensitiveLocationsAreBlocked();
suggestionBindingsMustMatchElementAndFingerprint();
nextWordStillAcceptsOneWordOnly();

console.log("browser extension content self-test passed");
