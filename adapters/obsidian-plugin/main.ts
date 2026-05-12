import { Plugin } from "obsidian";
import { Decoration, DecorationSet, EditorView, keymap, ViewPlugin, ViewUpdate, WidgetType } from "@codemirror/view";
import { StateEffect, StateField } from "@codemirror/state";

const setSuggestion = StateEffect.define<string>();

const suggestionField = StateField.define<string>({
  create: () => "",
  update(value, transaction) {
    for (const effect of transaction.effects) {
      if (effect.is(setSuggestion)) return effect.value;
    }
    if (transaction.docChanged || transaction.selection) return "";
    return value;
  }
});

class GhostWidget extends WidgetType {
  constructor(private readonly text: string) {
    super();
  }

  toDOM() {
    const span = document.createElement("span");
    span.className = "autocomplete-lab-ghost";
    span.textContent = this.text;
    span.style.opacity = "0.42";
    span.style.pointerEvents = "none";
    return span;
  }
}

const ghostDecorations = ViewPlugin.fromClass(class {
  decorations: DecorationSet = Decoration.none;

  constructor(view: EditorView) {
    this.updateDecorations(view);
  }

  update(update: ViewUpdate) {
    if (update.docChanged || update.selectionSet || update.transactions.some(transaction => transaction.effects.length)) {
      this.updateDecorations(update.view);
    }
  }

  updateDecorations(view: EditorView) {
    const suggestion = view.state.field(suggestionField, false) || "";
    if (!suggestion) {
      this.decorations = Decoration.none;
      return;
    }

    const position = view.state.selection.main.head;
    this.decorations = Decoration.set([
      Decoration.widget({
        widget: new GhostWidget(suggestion),
        side: 1
      }).range(position)
    ]);
  }
}, {
  decorations: plugin => plugin.decorations
});

function requestSuggestion(view: EditorView) {
  const cursor = view.state.selection.main.head;
  const textBeforeCursor = view.state.doc.sliceString(Math.max(0, cursor - 900), cursor);
  const trimmed = textBeforeCursor.trim().toLowerCase();
  if (trimmed.length < 3) {
    view.dispatch({ effects: setSuggestion.of("") });
    return;
  }

  let suggestion = " and keep moving";
  if (trimmed.endsWith("i think")) suggestion = " we should ship this";
  if (trimmed.endsWith("can we")) suggestion = " make this feel instant";
  if (trimmed.endsWith("the plan")) suggestion = " is to keep it small";
  view.dispatch({ effects: setSuggestion.of(suggestion) });
}

function acceptNextWord(view: EditorView): boolean {
  const suggestion = view.state.field(suggestionField, false) || "";
  const match = suggestion.match(/^\s*\S+\s*/);
  if (!match) return false;

  const accepted = match[0];
  const remaining = suggestion.slice(accepted.length);
  view.dispatch({
    changes: { from: view.state.selection.main.head, insert: accepted },
    effects: setSuggestion.of(remaining)
  });
  return true;
}

const autocompleteLabExtension = [
  suggestionField,
  ghostDecorations,
  EditorView.updateListener.of(update => {
    if (update.docChanged || update.selectionSet) {
      window.clearTimeout((update.view as any).autocompleteLabTimer);
      (update.view as any).autocompleteLabTimer = window.setTimeout(() => requestSuggestion(update.view), 120);
    }
  }),
  keymap.of([
    {
      key: "Tab",
      run: acceptNextWord
    },
    {
      key: "Escape",
      run(view) {
        view.dispatch({ effects: setSuggestion.of("") });
        return false;
      }
    }
  ])
];

export default class AutocompleteLabPlugin extends Plugin {
  async onload() {
    this.registerEditorExtension(autocompleteLabExtension);
  }
}
