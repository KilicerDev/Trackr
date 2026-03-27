import type { Editor } from "@milkdown/kit/core";
import { commonmark } from "@milkdown/kit/preset/commonmark";
import { history } from "@milkdown/kit/plugin/history";
import { clipboard } from "@milkdown/kit/plugin/clipboard";
import { listener, listenerCtx } from "@milkdown/kit/plugin/listener";
import { trailing } from "@milkdown/kit/plugin/trailing";
import { indent } from "@milkdown/kit/plugin/indent";
import { cursor } from "@milkdown/kit/plugin/cursor";

export type PluginConfig = {
  onChange?: (markdown: string) => void;
};

export function configurePlugins(editor: Editor, config: PluginConfig): Editor {
  return editor
    .use(commonmark)
    .use(history)
    .use(clipboard)
    .use(trailing)
    .use(indent)
    .use(cursor)
    .use(listener)
    .config((ctx) => {
      const l = ctx.get(listenerCtx);
      if (config.onChange) {
        l.markdownUpdated((_ctx, markdown, prevMarkdown) => {
          if (markdown !== prevMarkdown) {
            config.onChange!(markdown);
          }
        });
      }
    });
}
