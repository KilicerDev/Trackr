import { api } from "$lib/api";
import type { CreateProjectInput } from "$lib/api/projects";

export type ProjectMember = {
  user_id: string;
  role: { id: string; name: string; slug: string } | null;
  user: {
    id: string;
    full_name: string;
    username: string;
    avatar_url: string | null;
  };
};

export type Project = {
  id: string;
  name: string;
  identifier: string;
  description: string | null;
  status: string;
  color: string | null;
  icon: string | null;
  start_at: string | null;
  end_at: string | null;
  created_at: string;
  updated_at: string;
  organization_id: string;
  owner: {
    id: string;
    full_name: string;
    avatar_url: string | null;
  } | null;
  members: ProjectMember[];
  [key: string]: unknown;
};

class ProjectStore {
  items = $state<Project[]>([]);
  loading = $state(false);
  error = $state<string | null>(null);
  activeProject = $state<Project | null>(null);
  lastLoadedOrgId = $state<string | null>(null);

  async load(orgId: string) {
    this.lastLoadedOrgId = orgId;
    this.loading = true;
    this.error = null;

    try {
      const data = await api.projects.getAll(orgId);
      this.items = data as Project[];
    } catch (e) {
      this.error =
        e instanceof Error ? e.message : "Failed to load projects";
    } finally {
      this.loading = false;
    }
  }

  async loadAll() {
    this.lastLoadedOrgId = "__all__";
    this.loading = true;
    this.error = null;

    try {
      const data = await api.projects.getAllAcrossOrgs();
      this.items = data as Project[];
    } catch (e) {
      this.error =
        e instanceof Error ? e.message : "Failed to load projects";
    } finally {
      this.loading = false;
    }
  }

  async loadIfNeeded(orgId: string) {
    if (this.lastLoadedOrgId === orgId && this.items.length > 0) return;
    await this.load(orgId);
  }

  async loadById(id: string) {
    this.loading = true;
    this.error = null;

    try {
      this.activeProject = (await api.projects.getById(id)) as Project;
    } catch (e) {
      this.error =
        e instanceof Error ? e.message : "Project not found";
    } finally {
      this.loading = false;
    }
  }

  async create(input: CreateProjectInput) {
    try {
      const project = (await api.projects.create(input)) as Project;
      this.items = [project, ...this.items];
      return project;
    } catch (e) {
      this.error =
        e instanceof Error ? e.message : "Failed to create project";
      throw e;
    }
  }

  async update(id: string, values: Record<string, unknown>) {
    const prev = this.activeProject ? { ...this.activeProject } : null;
    if (this.activeProject && this.activeProject.id === id) {
      this.activeProject = { ...this.activeProject, ...values } as Project;
    }

    try {
      const updated = (await api.projects.update(id, values)) as Project;
      this.activeProject = updated;
      this.items = this.items.map((p) => (p.id === id ? updated : p));
      return updated;
    } catch (e) {
      if (prev) this.activeProject = prev;
      this.error =
        e instanceof Error ? e.message : "Failed to update project";
      throw e;
    }
  }

  async remove(projectId: string) {
    const prev = [...this.items];
    this.items = this.items.filter((p) => p.id !== projectId);

    try {
      await api.projects.delete(projectId);
    } catch {
      this.items = prev;
    }
  }

  clear() {
    this.items = [];
    this.activeProject = null;
    this.error = null;
    this.lastLoadedOrgId = null;
  }
}

export const projectStore = new ProjectStore();
