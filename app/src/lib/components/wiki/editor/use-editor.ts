import { Editor, rootCtx, defaultValueCtx, editorViewOptionsCtx, editorViewCtx } from "@milkdown/kit/core";
import { callCommand, getMarkdown, replaceAll } from "@milkdown/kit/utils";
import { TooltipProvider } from "@milkdown/plugin-tooltip";
import { SlashProvider } from "@milkdown/plugin-slash";
import { BlockProvider } from "@milkdown/plugin-block";
import type { EditorView } from "@milkdown/prose/view";
import { configurePlugins, selectionTooltip, slashMenu, block, type PluginConfig } from "./plugins";
import { configureTheme } from "./theme";

export type ActiveMarks = {
  bold: boolean;
  italic: boolean;
  strike: boolean;
  code: boolean;
  link: boolean;
};

export type WikiEditorOptions = {
  target: HTMLElement;
  content: string;
  onChange?: (markdown: string) => void;
  readonly?: boolean;
  toolbarEl?: HTMLElement | null;
  slashEl?: HTMLElement | null;
  blockEl?: HTMLElement | null;
  onSlashChange?: (visible: boolean, query: string) => void;
  onActiveMarksChange?: (marks: ActiveMarks) => void;
};

function readActiveMarks(view: EditorView): ActiveMarks {
  const { state } = view;
  const { from, to, empty, $from } = state.selection;
  const marks = state.schema.marks;
  const names = {
    bold: "strong",
    italic: "emphasis",
    strike: "strike_through",
    code: "inline_code",
    link: "link",
  } as const;
  const out: ActiveMarks = { bold: false, italic: false, strike: false, code: false, link: false };
  for (const [key, schemaName] of Object.entries(names) as [keyof ActiveMarks, string][]) {
    const markType = marks[schemaName];
    if (!markType) continue;
    if (empty) {
      const stored = state.storedMarks ?? $from.marks();
      out[key] = !!markType.isInSet(stored);
    } else {
      out[key] = state.doc.rangeHasMark(from, to, markType);
    }
  }
  return out;
}

export type WikiEditorInstance = {
  destroy: () => Promise<void>;
  setContent: (markdown: string) => void;
  getContent: () => string;
  runCommand: (commandKey: unknown, payload?: unknown) => void;
  runSlashItem: (commandKey: unknown, payload?: unknown) => void;
  hideSlash: () => void;
};

export async function createWikiEditor(options: WikiEditorOptions): Promise<WikiEditorInstance> {
  const pluginConfig: PluginConfig = {
    initialContent: options.content,
    onChange: options.onChange,
  };

  const wireProviders = !options.readonly;

  let tooltipProvider: TooltipProvider | null = null;
  let slashProvider: SlashProvider | null = null;
  let blockProvider: BlockProvider | null = null;

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

  if (wireProviders && options.toolbarEl) {
    const toolbarEl = options.toolbarEl;
    const notifyMarks = options.onActiveMarksChange;
    editor = editor.config((ctx) => {
      ctx.set(selectionTooltip.key, {
        view: () => {
          tooltipProvider = new TooltipProvider({ content: toolbarEl });
          return {
            update: (view, prevState) => {
              tooltipProvider?.update(view, prevState);
              if (notifyMarks) notifyMarks(readActiveMarks(view));
            },
            destroy: () => tooltipProvider?.destroy(),
          };
        },
      });
    });
  }

  if (wireProviders && options.slashEl) {
    const slashEl = options.slashEl;
    const notify = options.onSlashChange;
    editor = editor.config((ctx) => {
      ctx.set(slashMenu.key, {
        view: () => {
          slashProvider = new SlashProvider({
            content: slashEl,
            debounce: 20,
            shouldShow(view) {
              if (!slashProvider) return false;
              const content = slashProvider.getContent(view);
              if (typeof content !== "string") return false;
              const match = content.match(/\/(\w*)$/);
              if (!match) {
                notify?.(false, "");
                return false;
              }
              notify?.(true, match[1]);
              return true;
            },
          });
          slashProvider.onHide = () => notify?.(false, "");
          return {
            update: (view, prevState) => slashProvider?.update(view, prevState),
            destroy: () => slashProvider?.destroy(),
          };
        },
      });
    });
  }

  if (wireProviders && options.blockEl) {
    const blockEl = options.blockEl;
    editor = editor.config((ctx) => {
      ctx.set(block.key, {
        view: () => {
          blockProvider = new BlockProvider({ ctx, content: blockEl });
          return {
            update: () => blockProvider?.update(),
            destroy: () => blockProvider?.destroy(),
          };
        },
      });
    });
  }

  await editor.create();

  // Open links with Cmd/Ctrl+Click (or middle-click) in a new tab. We intercept
  // at mousedown to preventDefault BEFORE ProseMirror can start its own
  // text/node selection behavior (which would highlight the block).
  function handleEditorMouseDown(e: MouseEvent) {
    const modified = e.metaKey || e.ctrlKey;
    const middleClick = e.button === 1;
    if (!modified && !middleClick) return;
    const target = e.target as HTMLElement | null;
    const anchor = target?.closest?.("a[href]") as HTMLAnchorElement | null;
    if (!anchor) return;
    const href = anchor.getAttribute("href");
    if (!href) return;
    e.preventDefault();
    e.stopPropagation();
    window.open(href, "_blank", "noopener,noreferrer");
  }
  options.target.addEventListener("mousedown", handleEditorMouseDown, true);

  return {
    async destroy() {
      options.target.removeEventListener("mousedown", handleEditorMouseDown, true);
      await editor.destroy();
    },
    setContent(markdown: string) {
      editor.action(replaceAll(markdown));
    },
    getContent(): string {
      return editor.action(getMarkdown());
    },
    runCommand(commandKey, payload) {
      editor.action((ctx) => {
        const view = ctx.get(editorViewCtx);
        view.focus();
        callCommand(commandKey as never, payload as never)(ctx);
      });
    },
    runSlashItem(commandKey, payload) {
      editor.action((ctx) => {
        const view = ctx.get(editorViewCtx);
        const { state } = view;
        const { $from } = state.selection;
        const paraStart = $from.start($from.depth);
        const textBefore = state.doc.textBetween(paraStart, $from.pos, undefined, "\uFFFC");
        const slashIdx = textBefore.lastIndexOf("/");
        if (slashIdx >= 0) {
          const deleteFrom = paraStart + slashIdx;
          view.dispatch(state.tr.delete(deleteFrom, $from.pos));
        }
        callCommand(commandKey as never, payload as never)(ctx);
      });
    },
    hideSlash() {
      slashProvider?.hide();
      options.onSlashChange?.(false, "");
    },
  };
}
