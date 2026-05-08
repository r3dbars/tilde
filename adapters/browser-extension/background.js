const NATIVE_HOST = "bar.r3d.autocomplete_lab";

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (!message || message.type !== "completion-request") {
    return false;
  }

  const payload = {
    textBeforeCursor: message.textBeforeCursor || "",
    textAfterCursor: message.textAfterCursor || "",
    location: message.location || location.origin
  };

  try {
    chrome.runtime.sendNativeMessage(NATIVE_HOST, payload, response => {
      if (chrome.runtime.lastError || !response || !response.text) {
        sendResponse({ text: mockSuggestion(payload.textBeforeCursor) });
        return;
      }

      sendResponse({ text: String(response.text) });
    });
  } catch (_error) {
    sendResponse({ text: mockSuggestion(payload.textBeforeCursor) });
  }

  return true;
});

function mockSuggestion(textBeforeCursor) {
  const trimmed = textBeforeCursor.trim().toLowerCase();
  if (trimmed.endsWith("i think")) return " we should ship this";
  if (trimmed.endsWith("can we")) return " make this feel instant";
  if (trimmed.endsWith("the plan")) return " is to keep it small";
  return " and keep moving";
}
