import { tasks } from "./tasks";
import { projects } from "./projects";
import { tickets } from "./tickets";
import { members } from "./members";
import { organizations } from "./organizations";
import { config } from "./config";
import { roles } from "./roles";
import { users } from "./users";
import { notificationsApi } from "./notifications";
import { attachments } from "./attachments";
import { views } from "./views";
import { tags } from "./tags";
import { wiki } from "./wiki";
import { ical } from "./ical";
import { keys } from "./keys";
import { activities } from "./activities";
import { userPreferences } from "./userPreferences";

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
  attachments,
  views,
  tags,
  wiki,
  ical,
  keys,
  activities,
  userPreferences,
};