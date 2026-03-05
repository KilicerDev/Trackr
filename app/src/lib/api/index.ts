import { tasks } from "./tasks";
import { projects } from "./projects";
import { tickets } from "./tickets";
import { members } from "./members";
import { organizations } from "./organizations";
import { config } from "./config";
import { roles } from "./roles";
import { users } from "./users";
import { notificationsApi } from "./notifications";

export const api = {
  tasks,
  projects,
  tickets,
  members,
  organizations,
  config,
  roles,
  users,
  notifications: notificationsApi,
};