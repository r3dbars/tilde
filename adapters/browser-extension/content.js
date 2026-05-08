const state = {
  activeElement: null,
  suggestion: "",
  requestID: 0,
  ghost: null
};

const MIN_CHARS = 3;

document.addEventListener("focusin", event => {
  if (!isEditable(event.target)) return;
  state.activeElement = event.target;
  scheduleCompletion();
});

document.addEventListener("input", () => scheduleCompletion());
document.addEventListener("selectionchange", () => scheduleCompletion());

document.addEventListener("keydown", event => {
  if (!state.suggestion) return;

  if (event.key === "Escape") {
    hideGhost();
    event.preventDefault();
    return;
  }

  if (event.key === "Tab") {
    const accepted = nextWord(state.suggestion);
    if (!accepted) return;

    insertText(accepted);
    state.suggestion = state.suggestion.slice(accepted.length);
    if (state.suggestion.trim()) {
      showGhost(state.suggestion);
    } else {
      hideGhost();
    }
    event.preventDefault();
  }
}, true);

function scheduleCompletion() {
  const element = activeEditable();
  if (!element) {
    hideGhost();
    return;
  }

  const context = readContext(element);
  if (!context || context.textBeforeCursor.trim().length < MIN_CHARS) {
    hideGhost();
    return;
  }

  const requestID = ++state.requestID;
  window.setTimeout(() => {
    if (requestID !== state.requestID) return;
    chrome.runtime.sendMessage({
      type: "completion-request",
      textBeforeCursor: context.textBeforeCursor,
      textAfterCursor: context.textAfterCursor,
      location: window.location.href
    }, response => {
      if (requestID !== state.requestID) return;
      const suggestion = trimPrefix(response?.text || "", context.textBeforeCursor);
      if (!suggestion.trim()) {
        hideGhost();
        return;
      }

      state.suggestion = suggestion;
      showGhost(suggestion);
    });
  }, 120);
}

function activeEditable() {
  const element = document.activeElement;
  if (!isEditable(element)) return null;
  return element;
}

function isEditable(element) {
  if (!element || element.disabled || element.readOnly) return false;
  if (element instanceof HTMLInputElement) {
    return ["text", "search", "email", "url", "tel"].includes(element.type || "text");
  }
  if (element instanceof HTMLTextAreaElement) return true;
  return element.isContentEditable;
}

function readContext(element) {
  if (element instanceof HTMLInputElement || element instanceof HTMLTextAreaElement) {
    const start = element.selectionStart ?? element.value.length;
    const end = element.selectionEnd ?? start;
    return {
      textBeforeCursor: element.value.slice(0, start),
      textAfterCursor: element.value.slice(end),
      rect: caretRectForTextControl(element)
    };
  }

  const selection = window.getSelection();
  if (!selection || selection.rangeCount === 0) return null;
  const range = selection.getRangeAt(0);
  if (!element.contains(range.startContainer)) return null;

  const before = range.cloneRange();
  before.selectNodeContents(element);
  before.setEnd(range.startContainer, range.startOffset);

  const after = range.cloneRange();
  after.selectNodeContents(element);
  after.setStart(range.endContainer, range.endOffset);

  return {
    textBeforeCursor: before.toString(),
    textAfterCursor: after.toString(),
    rect: caretRectForRange(range)
  };
}

function caretRectForRange(range) {
  const clone = range.cloneRange();
  clone.collapse(true);
  const rect = clone.getClientRects()[0] || clone.getBoundingClientRect();
  if (rect && rect.width + rect.height > 0) return rect;

  const marker = document.createElement("span");
  marker.textContent = "\u200b";
  clone.insertNode(marker);
  const markerRect = marker.getBoundingClientRect();
  marker.remove();
  return markerRect;
}

function caretRectForTextControl(element) {
  const mirror = document.createElement("div");
  const style = window.getComputedStyle(element);
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

  mirror.style.position = "fixed";
  mirror.style.left = `${element.getBoundingClientRect().left}px`;
  mirror.style.top = `${element.getBoundingClientRect().top}px`;
  mirror.style.visibility = "hidden";
  mirror.style.whiteSpace = element instanceof HTMLTextAreaElement ? "pre-wrap" : "pre";
  mirror.textContent = element.value.slice(0, element.selectionStart ?? element.value.length);

  const marker = document.createElement("span");
  marker.textContent = "\u200b";
  mirror.appendChild(marker);
  document.body.appendChild(mirror);
  const rect = marker.getBoundingClientRect();
  mirror.remove();
  return rect;
}

function showGhost(text) {
  const element = activeEditable();
  if (!element) return;

  const context = readContext(element);
  if (!context || !context.rect) return;

  if (!state.ghost) {
    state.ghost = document.createElement("div");
    state.ghost.style.position = "fixed";
    state.ghost.style.zIndex = "2147483647";
    state.ghost.style.pointerEvents = "none";
    state.ghost.style.opacity = "0.42";
    state.ghost.style.color = "currentColor";
    state.ghost.style.font = "inherit";
    state.ghost.style.whiteSpace = "pre";
    document.documentElement.appendChild(state.ghost);
  }

  const style = window.getComputedStyle(element);
  state.ghost.style.font = style.font;
  state.ghost.style.color = style.color;
  state.ghost.textContent = text;
  state.ghost.style.left = `${context.rect.right}px`;
  state.ghost.style.top = `${context.rect.top}px`;
}

function hideGhost() {
  state.suggestion = "";
  if (state.ghost) {
    state.ghost.remove();
    state.ghost = null;
  }
}

function insertText(text) {
  const element = activeEditable();
  if (!element) return;

  if (element instanceof HTMLInputElement || element instanceof HTMLTextAreaElement) {
    const start = element.selectionStart ?? element.value.length;
    const end = element.selectionEnd ?? start;
    element.setRangeText(text, start, end, "end");
    element.dispatchEvent(new InputEvent("input", { bubbles: true, inputType: "insertText", data: text }));
    return;
  }

  const selection = window.getSelection();
  if (!selection || selection.rangeCount === 0) return;
  const range = selection.getRangeAt(0);
  range.deleteContents();
  range.insertNode(document.createTextNode(text));
  range.collapse(false);
  selection.removeAllRanges();
  selection.addRange(range);
  element.dispatchEvent(new InputEvent("input", { bubbles: true, inputType: "insertText", data: text }));
}

function nextWord(text) {
  const match = text.match(/^\s*\S+\s*/);
  return match ? match[0] : "";
}

function trimPrefix(suggestion, textBeforeCursor) {
  const trimmed = String(suggestion || "");
  const context = textBeforeCursor.trim();
  if (context && trimmed.toLowerCase().startsWith(context.toLowerCase())) {
    return trimmed.slice(context.length);
  }
  return trimmed;
}
