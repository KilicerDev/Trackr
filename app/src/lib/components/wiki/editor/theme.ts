import type { Editor } from "@milkdown/kit/core";
import { editorViewOptionsCtx } from "@milkdown/kit/core";

export function configureTheme(editor: Editor): Editor {
  return editor.config((ctx) => {
    ctx.update(editorViewOptionsCtx, (prev) => ({
      ...prev,
      attributes: {
        class: "milkdown-editor",
        spellcheck: "true",
      },
    }));
  });
}
