import { api } from "$lib/api";
import type { WikiAccessGrant } from "$lib/api/wiki";

function extractErrorMessage(e: unknown, fallback: string): string {
  if (e instanceof Error) return e.message;
  if (e && typeof e === "object" && "message" in e && typeof (e as { message: unknown }).message === "string")
    return (e as { message: string }).message;
  return fallback;
}

export type WikiFolder = {
  id: string;
  name: string;
  parent_id: string | null;
  organization_id: string;
  position: number;
  created_by: string;
  created_at: string;
  updated_at: string;
};

export type WikiPageMeta = {
  id: string;
  title: string;
  folder_id: string | null;
  position: number;
  icon: string | null;
  created_by: string;
  updated_at: string;
};

export type WikiPageFull = WikiPageMeta & {
  content: string;
  organization_id: string;
  updated_by: string | null;
  created_at: string;
  created_by_user: { id: string; full_name: string; avatar_url: string | null } | null;
  updated_by_user: { id: string; full_name: string; avatar_url: string | null } | null;
};

type MyAccessGrant = { id: string; folder_id: string | null; page_id: string | null; access_level: string };

class WikiStore {
  folders = $state<WikiFolder[]>([]);
  pages = $state<WikiPageMeta[]>([]);
  activePage = $state<WikiPageFull | null>(null);
  loading = $state(false);
  saving = $state(false);
  saveStatus = $state<"saved" | "saving" | "unsaved" | "error">("saved");
  error = $state<string | null>(null);

  /** Registered by WikiPageView so the layout can trigger a save before navigation. */
  flushSave: (() => Promise<void>) | null = null;

  // --- ACL state ---
  isWikiAdmin = $state(false);
  myAccessGrants = $state<MyAccessGrant[]>([]);
  activePageGrants = $state<WikiAccessGrant[]>([]);
  allGrants = $state<WikiAccessGrant[]>([]);

  setWikiAdmin(isAdmin: boolean) {
    this.isWikiAdmin = isAdmin;
  }

  /** Fetch the current user's own access grants for client-side permission checks. */
  async loadMyAccess() {
    try {
      this.myAccessGrants = await api.wiki.access.getMyAccess();
    } catch (e) {
      console.error("[WikiStore.loadMyAccess]", e);
    }
  }

  getGrantsForItem(itemId: string, type: "folder" | "page"): WikiAccessGrant[] {
    if (type === "folder") {
      return this.allGrants.filter(g => g.folder_id === itemId);
    }
    return this.allGrants.filter(g => g.page_id === itemId);
  }

  /** Client-side mirror of the DB access logic — for UI decisions only. RLS enforces server-side. */
  getEffectiveAccess(
    item: { id: string; folder_id?: string | null; parent_id?: string | null },
    type: "page" | "folder"
  ): "read" | "read_write" | null {
    if (this.isWikiAdmin) return "read_write";

    if (type === "page") {
      // Direct page grant
      const pageGrant = this.myAccessGrants.find((g) => g.page_id === item.id);
      let level: "read" | "read_write" | null = (pageGrant?.access_level as "read" | "read_write") ?? null;
      if (level === "read_write") return level;

      // Inherited from folder
      if (item.folder_id) {
        const folderLevel = this.getFolderInheritedAccess(item.folder_id);
        level = this.mostPermissive(level, folderLevel);
      }
      return level;
    }

    // Folder: direct grant + parent chain
    const directGrant = this.myAccessGrants.find((g) => g.folder_id === item.id);
    let level: "read" | "read_write" | null = (directGrant?.access_level as "read" | "read_write") ?? null;
    if (level === "read_write") return level;

    if (item.parent_id) {
      const parentLevel = this.getFolderInheritedAccess(item.parent_id);
      level = this.mostPermissive(level, parentLevel);
    }
    return level;
  }

  private getFolderInheritedAccess(folderId: string): "read" | "read_write" | null {
    let currentId: string | null = folderId;
    let level: "read" | "read_write" | null = null;
    const visited = new Set<string>();

    while (currentId && !visited.has(currentId)) {
      visited.add(currentId);
      const grant = this.myAccessGrants.find((g) => g.folder_id === currentId);
      if (grant) {
        const grantLevel = grant.access_level as "read" | "read_write";
        if (grantLevel === "read_write") return "read_write";
        if (!level) level = grantLevel;
      }
      const folder = this.folders.find((f) => f.id === currentId);
      currentId = folder?.parent_id ?? null;
    }

    return level;
  }

  private mostPermissive(
    a: "read" | "read_write" | null,
    b: "read" | "read_write" | null
  ): "read" | "read_write" | null {
    if (a === "read_write" || b === "read_write") return "read_write";
    if (a === "read" || b === "read") return "read";
    return null;
  }

  // --- Access grant management (for share modal) ---

  async loadAccessGrants(targetId: string, targetType: "folder" | "page") {
    this.activePageGrants = [];
    try {
      this.activePageGrants = targetType === "folder"
        ? await api.wiki.access.getForFolder(targetId)
        : await api.wiki.access.getForPage(targetId);
    } catch (e) {
      console.error("[WikiStore.loadAccessGrants]", e);
    }
  }

  async grantAccess(input: {
    organization_id: string;
    user_id: string;
    folder_id?: string | null;
    page_id?: string | null;
    access_level: "read" | "read_write";
    granted_by: string;
  }) {
    try {
      const grant = await api.wiki.access.grant(input);
      this.activePageGrants = [
        ...this.activePageGrants.filter((g) => g.user_id !== grant.user_id),
        grant,
      ];
      this.allGrants = [
        ...this.allGrants.filter((g) => g.id !== grant.id),
        grant,
      ];
      return grant;
    } catch (e) {
      this.error = extractErrorMessage(e, "Failed to grant access");
      throw e;
    }
  }

  async revokeAccess(grantId: string) {
    const prev = [...this.activePageGrants];
    const prevAll = [...this.allGrants];
    this.activePageGrants = this.activePageGrants.filter((g) => g.id !== grantId);
    this.allGrants = this.allGrants.filter((g) => g.id !== grantId);
    try {
      await api.wiki.access.revoke(grantId);
    } catch {
      this.activePageGrants = prev;
      this.allGrants = prevAll;
    }
  }

  // --- Data loading ---

  async loadTree(orgId?: string) {
    this.loading = true;
    this.error = null;
    try {
      const [folders, pages, allGrants] = await Promise.all([
        api.wiki.folders.getAll(),
        api.wiki.pages.getAll(),
        api.wiki.access.getAll(),
      ]);
      this.folders = folders as WikiFolder[];
      this.pages = pages as WikiPageMeta[];
      this.allGrants = allGrants;

      if (!this.isWikiAdmin) {
        await this.loadMyAccess();
      }
    } catch (e) {
      console.error("[WikiStore.loadTree]", e);
      this.error = extractErrorMessage(e, "Failed to load wiki");
    } finally {
      this.loading = false;
    }
  }

  async loadPage(pageId: string) {
    this.loading = true;
    this.error = null;
    try {
      this.activePage = (await api.wiki.pages.getById(pageId)) as WikiPageFull;
    } catch (e) {
      console.error("[WikiStore.loadPage]", e);
      this.error = extractErrorMessage(e, "Failed to load page");
    } finally {
      this.loading = false;
    }
  }

  async createFolder(input: { name: string; organization_id: string; parent_id?: string | null; created_by: string }) {
    try {
      const folder = (await api.wiki.folders.create(input)) as WikiFolder;
      this.folders = [...this.folders, folder];
      return folder;
    } catch (e) {
      this.error = extractErrorMessage(e, "Failed to create folder");
      throw e;
    }
  }

  async updateFolder(id: string, input: { name?: string; parent_id?: string | null; position?: number }) {
    try {
      const updated = (await api.wiki.folders.update(id, input)) as WikiFolder;
      this.folders = this.folders.map((f) => (f.id === id ? updated : f));
      return updated;
    } catch (e) {
      this.error = extractErrorMessage(e, "Failed to update folder");
      throw e;
    }
  }

  async deleteFolder(id: string) {
    const prev = [...this.folders];
    this.folders = this.folders.filter((f) => f.id !== id);
    try {
      await api.wiki.folders.delete(id);
    } catch (e) {
      console.error("[WikiStore.deleteFolder]", e);
      this.folders = prev;
      this.error = extractErrorMessage(e, "Failed to delete folder");
      throw e;
    }
  }

  async createPage(input: { title?: string; folder_id?: string | null; organization_id: string; created_by: string }) {
    try {
      const page = (await api.wiki.pages.create(input)) as WikiPageMeta;
      this.pages = [...this.pages, page];
      return page;
    } catch (e) {
      this.error = extractErrorMessage(e, "Failed to create page");
      throw e;
    }
  }

  async updatePage(id: string, input: { title?: string; content?: string; folder_id?: string | null; position?: number; updated_by?: string }) {
    this.saving = true;
    this.saveStatus = "saving";
    try {
      const updated = (await api.wiki.pages.update(id, input)) as WikiPageMeta;
      this.pages = this.pages.map((p) => (p.id === id ? updated : p));
      if (this.activePage?.id === id) {
        this.activePage = { ...this.activePage, ...input, ...updated };
      }
      this.saveStatus = "saved";
      return updated;
    } catch (e) {
      this.saveStatus = "error";
      this.error = extractErrorMessage(e, "Failed to save page");
      throw e;
    } finally {
      this.saving = false;
    }
  }

  async deletePage(id: string) {
    const prev = [...this.pages];
    this.pages = this.pages.filter((p) => p.id !== id);
    if (this.activePage?.id === id) this.activePage = null;
    try {
      await api.wiki.pages.delete(id);
    } catch (e) {
      console.error("[WikiStore.deletePage]", e);
      this.pages = prev;
      this.error = extractErrorMessage(e, "Failed to delete page");
      throw e;
    }
  }

  clear() {
    this.folders = [];
    this.pages = [];
    this.activePage = null;
    this.error = null;
    this.saveStatus = "saved";
    this.isWikiAdmin = false;
    this.myAccessGrants = [];
    this.activePageGrants = [];
    this.allGrants = [];
  }
}

export const wikiStore = new WikiStore();
