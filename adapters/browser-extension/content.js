const AutocompleteLabBrowserExtension = (() => {
  "use strict";

  const root = typeof globalThis !== "undefined" ? globalThis : window;
  const MIN_CHARS = 3;
  const REQUEST_DELAY_MS = 120;
  const RAW_TEXT_OPT_IN_FLAG = "__AUTOCOMPLETE_LAB_BROWSER_EXTENSION_ALLOW_RAW_TEXT__";
  const LOCAL_HOSTS = new Set(["localhost", "127.0.0.1", "[::1]", "::1"]);
  const ALLOWED_INPUT_TYPES = new Set(["", "text"]);
  const BLOCKED_INPUT_TYPES = new Set([
    "button",
    "checkbox",
    "color",
    "date",
    "datetime-local",
    "email",
    "file",
    "hidden",
    "month",
    "number",
    "password",
    "radio",
    "range",
    "reset",
    "search",
    "submit",
    "tel",
    "time",
    "url",
    "week"
  ]);
  const SENSITIVE_FIELD_PATTERNS = [
    /\bpass(word|code)?\b/,
    /\bpin\b/,
    /\botp\b/,
    /\bone\s*time\b/,
    /\b2fa\b/,
    /\bmfa\b/,
    /\bverification\b/,
    /\bverify\b/,
    /\btoken\b/,
    /\bsecret\b/,
    /\bapi\s*key\b/,
    /\baccess\s*key\b/,
    /\bprivate\s*key\b/,
    /\bssn\b/,
    /\bsocial\s*security\b/,
    /\bcredit\b/,
    /\bcard\b/,
    /\bcc\b/,
    /\bcvc\b/,
    /\bcvv\b/,
    /\biban\b/,
    /\brouting\b/,
    /\bpayment\b/,
    /\bcheckout\b/,
    /\bbilling\b/,
    /\bpaypal\b/,
    /\bstripe\b/,
    /\bwallet\b/,
    /\blog\s*in\b/,
    /\blogin\b/,
    /\bsign\s*in\b/,
    /\bsignin\b/,
    /\bauth\b/,
    /\bsession\b/,
    /\bsearch\b/,
    /\bquery\b/,
    /\burl\b/,
    /\baddress\b/,
    /\blocation\b/,
    /\bprivate\b/
  ];
  const SENSITIVE_LOCATION_PATTERNS = [
    /\bpass(word|code)?\b/,
    /\botp\b/,
    /\bone\s*time\b/,
    /\b2fa\b/,
    /\bmfa\b/,
    /\bauth\b/,
    /\blog\s*in\b/,
    /\blogin\b/,
    /\bsign\s*in\b/,
    /\bsignin\b/,
    /\bsession\b/,
    /\btoken\b/,
    /\bsecret\b/,
    /\bapi\s*key\b/,
    /\bcheckout\b/,
    /\bpayment\b/,
    /\bbilling\b/,
    /\bpaypal\b/,
    /\bstripe\b/,
    /\bwallet\b/,
    /\bsearch\b/,
    /\bquery\b/,
    /\burl\b/,
    /\baddress\b/,
    /\bprivate\b/
  ];
  const SENSITIVE_AUTOCOMPLETE_TOKENS = [
    "current-password",
    "new-password",
    "one-time-code",
    "cc-name",
    "cc-number",
    "cc-exp",
    "cc-exp-month",
    "cc-exp-year",
    "cc-csc",
    "cc-type",
    "transaction-currency",
    "transaction-amount",
    "email",
    "username",
    "tel",
    "street-address",
    "address-line1",
    "address-line2",
    "address-line3",
    "address-level1",
    "address-level2",
    "postal-code",
    "country",
    "country-name"
  ];

  const elementIDs = new WeakMap();
  let nextElementID = 1;

  const state = {
    activeElement: null,
    suggestion: "",
    suggestionBinding: null,
    requestID: 0,
    ghost: null,
    installed: false,
    acceptingSuggestion: false
  };

  function install() {
    const document = root.document;
    if (!document || state.installed) return Boolean(document);

    document.addEventListener("focusin", event => {
      if (!isEditable(event.target)) {
        state.activeElement = null;
        invalidateSuggestion();
        return;
      }

      state.activeElement = event.target;
      invalidateSuggestion();
      scheduleCompletion();
    }, true);

    document.addEventListener("focusout", event => {
      if (event.target === state.activeElement) {
        state.activeElement = null;
        invalidateSuggestion();
      }
    }, true);

    document.addEventListener("input", event => {
      if (state.acceptingSuggestion) return;
      if (event.target !== activeEditable()) return;
      invalidateSuggestion();
      scheduleCompletion();
    }, true);

    document.addEventListener("selectionchange", () => {
      if (state.suggestionBinding && !isCurrentBinding(state.suggestionBinding)) {
        clearSuggestion();
      }
      scheduleCompletion();
    });

    document.addEventListener("keydown", event => {
      if (!state.suggestion) return;

      if (event.key === "Escape") {
        invalidateSuggestion();
        event.preventDefault();
        return;
      }

      if (event.key !== "Tab") return;

      const binding = state.suggestionBinding;
      if (!binding || !isCurrentBinding(binding)) {
        invalidateSuggestion();
        return;
      }

      const accepted = nextWord(state.suggestion);
      if (!accepted) {
        invalidateSuggestion();
        return;
      }

      if (!insertText(accepted, binding)) {
        invalidateSuggestion();
        return;
      }

      const remaining = state.suggestion.slice(accepted.length);
      const nextBinding = currentBinding();
      if (remaining.trim() && nextBinding) {
        state.suggestion = remaining;
        state.suggestionBinding = nextBinding;
        if (!showGhost(remaining, nextBinding)) clearSuggestion();
      } else {
        clearSuggestion();
      }

      event.preventDefault();
    }, true);

    state.installed = true;
    return true;
  }

  function scheduleCompletion() {
    const locationSafety = safeLocationDecision(root.location);
    if (!locationSafety.allowed) {
      invalidateSuggestion();
      return;
    }

    const element = activeEditable();
    if (!element) {
      invalidateSuggestion();
      return;
    }

    const rawTextEnabled = rawTextRequestsEnabled();
    const context = readContext(element, { includeRawText: rawTextEnabled });
    if (!context || context.trimmedBeforeLength < MIN_CHARS) {
      invalidateSuggestion();
      return;
    }

    const binding = createSuggestionBinding(element, context, root.location);
    const payload = buildCompletionRequest({
      element,
      context,
      location: root.location,
      rawTextEnabled
    });
    const requestID = ++state.requestID;

    root.setTimeout(() => {
      if (requestID !== state.requestID) return;
      if (!isCurrentBinding(binding)) {
        clearSuggestion();
        return;
      }

      sendCompletionRequest(payload, response => {
        if (requestID !== state.requestID) return;
        if (!isCurrentBinding(binding)) {
          clearSuggestion();
          return;
        }

        const suggestion = normalizeSuggestion(response?.text || "", context);
        if (!suggestion.trim()) {
          clearSuggestion();
          return;
        }

        const freshBinding = currentBinding();
        if (!freshBinding || !sameSuggestionBinding(binding, freshBinding)) {
          clearSuggestion();
          return;
        }

        state.suggestion = suggestion;
        state.suggestionBinding = freshBinding;
        if (!showGhost(suggestion, freshBinding)) clearSuggestion();
      });
    }, REQUEST_DELAY_MS);
  }

  function sendCompletionRequest(payload, callback) {
    const runtime = root.chrome?.runtime;
    if (!runtime?.sendMessage) {
      callback(null);
      return;
    }
    runtime.sendMessage(payload, callback);
  }

  function activeEditable() {
    const element = root.document?.activeElement;
    if (!isEditable(element)) return null;
    return element;
  }

  function isEditable(element) {
    if (!element || element.disabled || element.readOnly) return false;
    if (isHiddenElement(element)) return false;
    if (!fieldSafety(element).allowed) return false;

    if (isHTMLInput(element)) {
      const type = normalizedInputType(element);
      return ALLOWED_INPUT_TYPES.has(type);
    }
    if (isHTMLTextArea(element)) return true;
    return Boolean(element.isContentEditable);
  }

  function isHiddenElement(element) {
    if (element.hidden || element.getAttribute?.("aria-hidden") === "true") return true;
    const style = root.getComputedStyle?.(element);
    return style?.display === "none" || style?.visibility === "hidden";
  }

  function fieldSafety(element) {
    return sensitiveFieldDecision(sensitiveFieldMetadata(element));
  }

  function sensitiveFieldDecision(metadata) {
    const type = normalizeText(metadata.type || "");
    if (BLOCKED_INPUT_TYPES.has(type) && !ALLOWED_INPUT_TYPES.has(type)) {
      return { allowed: false, reason: `blocked-input-type:${type || "unknown"}` };
    }

    const autocompleteTokens = normalizeText(metadata.autocomplete || "")
      .split(/\s+/)
      .filter(Boolean);
    const sensitiveToken = autocompleteTokens.find(token => SENSITIVE_AUTOCOMPLETE_TOKENS.includes(token));
    if (sensitiveToken) {
      return { allowed: false, reason: `sensitive-autocomplete:${sensitiveToken}` };
    }

    const haystack = normalizeText([
      metadata.type,
      metadata.inputMode,
      metadata.role,
      metadata.name,
      metadata.id,
      metadata.className,
      metadata.autocomplete,
      metadata.placeholder,
      metadata.ariaLabel,
      metadata.title,
      metadata.testID,
      metadata.ancestorHints
    ].filter(Boolean).join(" "));
    const pattern = SENSITIVE_FIELD_PATTERNS.find(candidate => candidate.test(haystack));
    if (pattern) return { allowed: false, reason: "sensitive-field-metadata" };

    return { allowed: true, reason: "allowed" };
  }

  function sensitiveFieldMetadata(element) {
    const metadata = {
      type: normalizedInputType(element),
      inputMode: safeAttribute(element, "inputmode"),
      role: safeAttribute(element, "role"),
      name: safeAttribute(element, "name"),
      id: safeAttribute(element, "id"),
      className: typeof element.className === "string" ? element.className : "",
      autocomplete: safeAttribute(element, "autocomplete"),
      placeholder: safeAttribute(element, "placeholder"),
      ariaLabel: safeAttribute(element, "aria-label"),
      title: safeAttribute(element, "title"),
      testID: safeAttribute(element, "data-testid"),
      ancestorHints: ""
    };

    const hints = [];
    let cursor = element.parentElement;
    for (let depth = 0; cursor && depth < 4; depth += 1) {
      hints.push(
        safeAttribute(cursor, "id"),
        safeAttribute(cursor, "class"),
        safeAttribute(cursor, "role"),
        safeAttribute(cursor, "aria-label"),
        safeAttribute(cursor, "autocomplete"),
        safeAttribute(cursor, "action"),
        safeAttribute(cursor, "data-testid")
      );
      cursor = cursor.parentElement;
    }
    metadata.ancestorHints = hints.filter(Boolean).join(" ");
    return metadata;
  }

  function safeLocationDecision(location) {
    if (!location) return { allowed: false, reason: "missing-location" };
    if (!["http:", "https:"].includes(location.protocol)) {
      return { allowed: false, reason: "blocked-protocol" };
    }
    if (location.username || location.password) {
      return { allowed: false, reason: "blocked-credential-url" };
    }
    if (!LOCAL_HOSTS.has(location.hostname)) {
      return { allowed: false, reason: "blocked-host" };
    }

    const route = normalizeText([
      location.pathname,
      location.search,
      location.hash
    ].filter(Boolean).join(" "));
    if (SENSITIVE_LOCATION_PATTERNS.some(pattern => pattern.test(route))) {
      return { allowed: false, reason: "sensitive-location" };
    }

    return { allowed: true, reason: "local-proof-location" };
  }

  function safeLocation(location) {
    if (!location) return "";
    return `${location.protocol}//${location.host}`;
  }

  function readContext(element, options = {}) {
    const includeRawText = options.includeRawText === true;

    if (isHTMLInput(element) || isHTMLTextArea(element)) {
      const start = element.selectionStart ?? element.value.length;
      const end = element.selectionEnd ?? start;
      const textBeforeCursor = String(element.value || "").slice(0, start);
      const textAfterCursor = String(element.value || "").slice(end);
      return summarizeContext({
        textBeforeCursor,
        textAfterCursor,
        selectionStart: start,
        selectionEnd: end,
        totalLength: String(element.value || "").length,
        rect: caretRectForTextControl(element, { allowRawMeasurement: includeRawText }),
        includeRawText
      });
    }

    const selection = root.getSelection?.();
    if (!selection || selection.rangeCount === 0) return null;
    const range = selection.getRangeAt(0);
    if (!element.contains(range.startContainer) || !element.contains(range.endContainer)) return null;

    const before = range.cloneRange();
    before.selectNodeContents(element);
    before.setEnd(range.startContainer, range.startOffset);

    const after = range.cloneRange();
    after.selectNodeContents(element);
    after.setStart(range.endContainer, range.endOffset);

    return summarizeContext({
      textBeforeCursor: before.toString(),
      textAfterCursor: after.toString(),
      selectionStart: range.startOffset,
      selectionEnd: range.endOffset,
      totalLength: element.textContent?.length || 0,
      rect: caretRectForRange(range),
      includeRawText
    });
  }

  function summarizeContext({
    textBeforeCursor,
    textAfterCursor,
    selectionStart,
    selectionEnd,
    totalLength,
    rect,
    includeRawText
  }) {
    const selectedLength = Math.max(0, selectionEnd - selectionStart);
    const context = {
      beforeLength: textBeforeCursor.length,
      afterLength: textAfterCursor.length,
      trimmedBeforeLength: textBeforeCursor.trim().length,
      totalLength,
      selectedLength,
      hasSelection: selectedLength > 0,
      selectionStart,
      selectionEnd,
      rect
    };

    if (includeRawText) {
      context.textBeforeCursor = textBeforeCursor;
      context.textAfterCursor = textAfterCursor;
    }

    return context;
  }

  function caretRectForRange(range) {
    const clone = range.cloneRange();
    clone.collapse(true);
    const rect = clone.getClientRects()[0] || clone.getBoundingClientRect();
    if (rect && rect.width + rect.height > 0) return rect;

    const marker = root.document.createElement("span");
    marker.textContent = "\u200b";
    clone.insertNode(marker);
    const markerRect = marker.getBoundingClientRect();
    marker.remove();
    return markerRect;
  }

  function caretRectForTextControl(element, options = {}) {
    if (options.allowRawMeasurement !== true) {
      return approximateCaretRectForTextControl(element);
    }

    const mirror = root.document.createElement("div");
    const style = root.getComputedStyle(element);
    const properties = [
      "boxSizing", "width", "height", "overflowX", "overflowY", "borderTopWidth",
      "borderRightWidth", "borderBottomWidth", "borderLeftWidth", "paddingTop",
      "paddingRight", "paddingBottom", "paddingLeft", "fontFamily", "fontSize",
      "fontWeight", "fontStyle", "letterSpacing", "textTransform", "whiteSpace",
      "wordWrap", "lineHeight"
    ];

    for (const property of properties) {
      mirror.style[property] = style[property];
    }

    const bounds = element.getBoundingClientRect();
    mirror.style.position = "fixed";
    mirror.style.left = `${bounds.left}px`;
    mirror.style.top = `${bounds.top}px`;
    mirror.style.visibility = "hidden";
    mirror.style.whiteSpace = isHTMLTextArea(element) ? "pre-wrap" : "pre";
    mirror.textContent = String(element.value || "").slice(0, element.selectionStart ?? element.value.length);

    const marker = root.document.createElement("span");
    marker.textContent = "\u200b";
    mirror.appendChild(marker);
    root.document.body.appendChild(mirror);
    const rect = marker.getBoundingClientRect();
    mirror.remove();
    return rect;
  }

  function approximateCaretRectForTextControl(element) {
    const bounds = element.getBoundingClientRect();
    const style = root.getComputedStyle?.(element);
    const paddingLeft = parseFloat(style?.paddingLeft || "0") || 0;
    const paddingTop = parseFloat(style?.paddingTop || "0") || 0;
    const lineHeight = parseFloat(style?.lineHeight || style?.fontSize || "16") || 16;
    return {
      left: bounds.left + paddingLeft,
      right: bounds.left + paddingLeft,
      top: bounds.top + paddingTop,
      bottom: bounds.top + paddingTop + lineHeight,
      width: 0,
      height: lineHeight
    };
  }

  function showGhost(text, binding) {
    if (!binding || !isCurrentBinding(binding)) return false;

    const context = readContext(binding.element, { includeRawText: false });
    if (!context || !context.rect) return false;
    const freshBinding = createSuggestionBinding(binding.element, context, root.location);
    if (!sameSuggestionBinding(binding, freshBinding)) return false;

    if (!state.ghost) {
      state.ghost = root.document.createElement("div");
      state.ghost.style.position = "fixed";
      state.ghost.style.zIndex = "2147483647";
      state.ghost.style.pointerEvents = "none";
      state.ghost.style.opacity = "0.42";
      state.ghost.style.color = "currentColor";
      state.ghost.style.font = "inherit";
      state.ghost.style.whiteSpace = "pre";
      root.document.documentElement.appendChild(state.ghost);
    }

    const style = root.getComputedStyle(binding.element);
    state.ghost.style.font = style.font;
    state.ghost.style.color = style.color;
    state.ghost.textContent = text;
    state.ghost.style.left = `${context.rect.right}px`;
    state.ghost.style.top = `${context.rect.top}px`;
    return true;
  }

  function clearSuggestion() {
    state.suggestion = "";
    state.suggestionBinding = null;
    if (state.ghost) {
      state.ghost.remove();
      state.ghost = null;
    }
  }

  function invalidateSuggestion() {
    state.requestID += 1;
    clearSuggestion();
  }

  function insertText(text, expectedBinding) {
    if (!expectedBinding || !isCurrentBinding(expectedBinding)) return false;

    const element = activeEditable();
    if (!element) return false;

    state.acceptingSuggestion = true;
    try {
      if (isHTMLInput(element) || isHTMLTextArea(element)) {
        const start = element.selectionStart ?? element.value.length;
        const end = element.selectionEnd ?? start;
        element.setRangeText(text, start, end, "end");
        element.dispatchEvent(new InputEvent("input", { bubbles: true, inputType: "insertText", data: text }));
        return true;
      }

      const selection = root.getSelection?.();
      if (!selection || selection.rangeCount === 0) return false;
      const range = selection.getRangeAt(0);
      if (!element.contains(range.startContainer) || !element.contains(range.endContainer)) return false;
      range.deleteContents();
      range.insertNode(root.document.createTextNode(text));
      range.collapse(false);
      selection.removeAllRanges();
      selection.addRange(range);
      element.dispatchEvent(new InputEvent("input", { bubbles: true, inputType: "insertText", data: text }));
      return true;
    } finally {
      state.acceptingSuggestion = false;
    }
  }

  function currentBinding() {
    const element = activeEditable();
    if (!element) return null;
    if (!safeLocationDecision(root.location).allowed) return null;
    const context = readContext(element, { includeRawText: false });
    if (!context) return null;
    return createSuggestionBinding(element, context, root.location);
  }

  function isCurrentBinding(binding) {
    const current = currentBinding();
    return sameSuggestionBinding(binding, current);
  }

  function createSuggestionBinding(element, context, location) {
    return {
      element,
      fingerprint: requestFingerprint(element, context, location)
    };
  }

  function sameSuggestionBinding(left, right) {
    return Boolean(left && right && left.element === right.element && left.fingerprint === right.fingerprint);
  }

  function requestFingerprint(element, context, location) {
    const metadata = safeFieldMetadata(element);
    return [
      safeLocation(location),
      metadata.elementKey,
      metadata.tag,
      metadata.type,
      metadata.role,
      metadata.contentEditable ? "contenteditable" : "text-control",
      context.beforeLength,
      context.afterLength,
      context.totalLength,
      context.selectedLength,
      context.selectionStart,
      context.selectionEnd
    ].join("|");
  }

  function buildCompletionRequest({ element, context, location, rawTextEnabled }) {
    const payload = {
      type: "completion-request",
      rawTextIncluded: rawTextEnabled === true,
      location: safeLocation(location),
      locationSafety: safeLocationDecision(location).reason,
      field: safeFieldMetadata(element),
      context: {
        beforeLength: context.beforeLength,
        afterLength: context.afterLength,
        trimmedBeforeLength: context.trimmedBeforeLength,
        totalLength: context.totalLength,
        selectedLength: context.selectedLength,
        hasSelection: context.hasSelection,
        fingerprint: requestFingerprint(element, context, location)
      },
      geometry: rectSummary(context.rect)
    };

    if (rawTextEnabled === true) {
      payload.textBeforeCursor = context.textBeforeCursor || "";
      payload.textAfterCursor = context.textAfterCursor || "";
    }

    return payload;
  }

  function safeFieldMetadata(element) {
    return {
      elementKey: elementKey(element),
      tag: normalizeText(element?.tagName || ""),
      type: normalizedInputType(element),
      role: normalizeText(safeAttribute(element, "role")),
      inputMode: normalizeText(safeAttribute(element, "inputmode")),
      contentEditable: Boolean(element?.isContentEditable)
    };
  }

  function rectSummary(rect) {
    if (!rect) return null;
    return {
      left: Math.round(rect.left),
      right: Math.round(rect.right),
      top: Math.round(rect.top),
      bottom: Math.round(rect.bottom),
      width: Math.round(rect.width || 0),
      height: Math.round(rect.height || 0)
    };
  }

  function rawTextRequestsEnabled() {
    return root[RAW_TEXT_OPT_IN_FLAG] === true;
  }

  function normalizeSuggestion(suggestion, context) {
    const text = String(suggestion || "");
    if (!context.textBeforeCursor) return text;
    return trimPrefix(text, context.textBeforeCursor);
  }

  function nextWord(text) {
    const match = String(text || "").match(/^\s*\S+\s*/);
    return match ? match[0] : "";
  }

  function trimPrefix(suggestion, textBeforeCursor) {
    const trimmed = String(suggestion || "");
    const context = String(textBeforeCursor || "").trim();
    if (context && trimmed.toLowerCase().startsWith(context.toLowerCase())) {
      return trimmed.slice(context.length);
    }
    return trimmed;
  }

  function elementKey(element) {
    if (!element || (typeof element !== "object" && typeof element !== "function")) return "unknown";
    if (!elementIDs.has(element)) {
      elementIDs.set(element, `element-${nextElementID}`);
      nextElementID += 1;
    }
    return elementIDs.get(element);
  }

  function isHTMLInput(element) {
    return typeof root.HTMLInputElement !== "undefined" && element instanceof root.HTMLInputElement;
  }

  function isHTMLTextArea(element) {
    return typeof root.HTMLTextAreaElement !== "undefined" && element instanceof root.HTMLTextAreaElement;
  }

  function normalizedInputType(element) {
    if (!element || !("type" in element)) return "";
    return normalizeText(element.type || "text");
  }

  function safeAttribute(element, name) {
    return String(element?.getAttribute?.(name) || "");
  }

  function normalizeText(text) {
    return String(text || "")
      .toLowerCase()
      .replace(/[_-]+/g, " ")
      .replace(/[^\p{L}\p{N}]+/gu, " ")
      .replace(/\s+/g, " ")
      .trim();
  }

  const api = {
    install,
    _test: {
      RAW_TEXT_OPT_IN_FLAG,
      buildCompletionRequest,
      createSuggestionBinding,
      nextWord,
      normalizeText,
      requestFingerprint,
      safeLocation,
      safeLocationDecision,
      sameSuggestionBinding,
      sensitiveFieldDecision,
      trimPrefix
    }
  };

  if (root.document) install();
  return api;
})();

if (typeof globalThis !== "undefined") {
  globalThis.AutocompleteLabBrowserExtension = AutocompleteLabBrowserExtension;
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = AutocompleteLabBrowserExtension;
}
