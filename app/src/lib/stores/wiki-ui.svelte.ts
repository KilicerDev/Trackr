import { api } from "$lib/api";

const SIDEBAR_COLLAPSED_KEY = "wiki-sidebar-collapsed";
const SAVE_DEBOUNCE_MS = 500;

type WikiPrefs = { expandedFolders?: string[] };

class WikiUiState {
  sidebarCollapsed = $state(false);
  expandedFolders = $state<Set<string>>(new Set());

  #localInitialized = false;
  #loadedUserId: string | null = null;
  #saveTimer: ReturnType<typeof setTimeout> | null = null;

  initLocal() {
    if (typeof document === "undefined" || this.#localInitialized) return;
    this.#localInitialized = true;
    const stored = localStorage.getItem(SIDEBAR_COLLAPSED_KEY);
    this.sidebarCollapsed = stored === "true";
  }

  setSidebarCollapsed(value: boolean) {
    this.sidebarCollapsed = value;
    if (typeof document !== "undefined") {
      localStorage.setItem(SIDEBAR_COLLAPSED_KEY, String(value));
    }
  }

  async loadFolderState(userId: string) {
    if (this.#loadedUserId === userId) return;
    this.#loadedUserId = userId;
    try {
      const prefs = await api.userPreferences.getPrefs();
      const wiki = (prefs.wiki as WikiPrefs | undefined) ?? {};
      this.expandedFolders = new Set(wiki.expandedFolders ?? []);
    } catch (e) {
      console.error("[wikiUi] Failed to load folder state:", e);
    }
  }

  isExpanded(folderId: string): boolean {
    return this.expandedFolders.has(folderId);
  }

  toggleFolder(folderId: string) {
    const next = new Set(this.expandedFolders);
    if (next.has(folderId)) next.delete(folderId);
    else next.add(folderId);
    this.expandedFolders = next;
    this.#scheduleSave();
  }

  #scheduleSave() {
    if (this.#saveTimer) clearTimeout(this.#saveTimer);
    this.#saveTimer = setTimeout(() => {
      this.#saveTimer = null;
      void this.#flush();
    }, SAVE_DEBOUNCE_MS);
  }

  async #flush() {
    try {
      const current = await api.userPreferences.getPrefs();
      const wiki = (current.wiki as WikiPrefs | undefined) ?? {};
      await api.userPreferences.setPrefs({
        ...current,
        wiki: { ...wiki, expandedFolders: [...this.expandedFolders] },
      });
    } catch (e) {
      console.error("[wikiUi] Failed to save folder state:", e);
    }
  }
}

export const wikiUi = new WikiUiState();
