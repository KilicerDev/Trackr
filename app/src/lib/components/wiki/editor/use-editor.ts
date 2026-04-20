import { Editor, rootCtx, defaultValueCtx, editorViewOptionsCtx } from "@milkdown/kit/core";
import { getMarkdown, replaceAll } from "@milkdown/kit/utils";
import { configurePlugins, type PluginConfig } from "./plugins";
import { configureTheme } from "./theme";

export type WikiEditorOptions = {
  target: HTMLElement;
  content: string;
  onChange?: (markdown: string) => void;
  readonly?: boolean;
};

export type WikiEditorInstance = {
  destroy: () => Promise<void>;
  setContent: (markdown: string) => void;
  getContent: () => string;
};

export async function createWikiEditor(options: WikiEditorOptions): Promise<WikiEditorInstance> {
  const pluginConfig: PluginConfig = {
    initialContent: options.content,
    onChange: options.onChange,
  };

  let editor = Editor.make();
  editor = editor.config((ctx) => {
    ctx.set(rootCtx, options.target);
    ctx.set(defaultValueCtx, options.content);
    if (options.readonly) {
      ctx.update(editorViewOptionsCtx, (prev) => ({
        ...prev,
        editable: () => false,
      }));
    }
  });
  editor = configureTheme(editor);
  editor = configurePlugins(editor, pluginConfig);

  await editor.create();

  return {
    async destroy() {
      await editor.destroy();
    },
    setContent(markdown: string) {
      editor.action(replaceAll(markdown));
    },
    getContent(): string {
      return editor.action(getMarkdown());
    },
  };
}
