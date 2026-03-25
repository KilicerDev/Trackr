package main

import "fmt"

func getSubjectLine(typ, title, body string) string {
	switch typ {
	case "task_assigned":
		return "Task assigned to you: " + body
	case "task_status_change":
		return title
	case "task_comment":
		if body != "" {
			return "New comment on: " + body
		}
		return "New comment on task"
	case "ticket_created":
		return "New ticket: " + title
	case "ticket_assigned":
		return "Ticket assigned to you"
	case "ticket_resolved":
		return "Your ticket has been resolved"
	case "ticket_message":
		if body != "" {
			return "New message on: " + body
		}
		return "New message on ticket"
	case "sla_breach":
		return title
	default:
		return title
	}
}

type emailContent struct {
	heading     string
	description string
	ctaLabel    string
	ctaURL      string
}

func getEmailContent(payload NotificationPayload, siteURL string) emailContent {
	actor := "Someone"
	if payload.ActorName != nil {
		actor = *payload.ActorName
	}
	body := ptrStr(payload.Body)
	preview := ptrStr(payload.ContentPreview)
	resourceID := ptrStr(payload.ResourceID)

	ticketURL := siteURL
	if resourceID != "" {
		ticketURL = fmt.Sprintf("%s/tickets?id=%s", siteURL, resourceID)
	}
	taskURL := siteURL

	switch payload.Type {
	case "task_assigned":
		return emailContent{
			heading:     "Task assigned to you",
			description: fmt.Sprintf(`<strong style="color:#ededed;">%s</strong> assigned you a task: <strong style="color:#ededed;">%s</strong>`, actor, body),
			ctaLabel:    "Open Trackr",
			ctaURL:      taskURL,
		}
	case "task_status_change":
		desc := payload.Title
		if body != "" {
			desc += fmt.Sprintf(` &mdash; <strong style="color:#ededed;">%s</strong>`, body)
		}
		return emailContent{
			heading:     "Task status updated",
			description: desc,
			ctaLabel:    "Open Trackr",
			ctaURL:      taskURL,
		}
	case "task_comment":
		taskName := body
		if taskName == "" {
			taskName = "a task"
		}
		desc := fmt.Sprintf(`<strong style="color:#ededed;">%s</strong> commented on <strong style="color:#ededed;">%s</strong>`, actor, taskName)
		if preview != "" {
			desc += fmt.Sprintf(`<div style="margin-top:16px;background-color:#252525;border-radius:8px;padding:16px 20px;border:1px solid #2e2e2e;"><p style="margin:0;font-size:13px;color:#b0b0b0;line-height:1.6;white-space:pre-wrap;">%s</p></div>`, preview)
		}
		return emailContent{
			heading:     "New comment on task",
			description: desc,
			ctaLabel:    "Open Trackr",
			ctaURL:      taskURL,
		}
	case "ticket_created":
		return emailContent{
			heading:     "New support ticket",
			description: fmt.Sprintf(`A new ticket has been created: <strong style="color:#ededed;">%s</strong>`, payload.Title),
			ctaLabel:    "View Ticket",
			ctaURL:      ticketURL,
		}
	case "ticket_assigned":
		return emailContent{
			heading:     "Ticket assigned to you",
			description: fmt.Sprintf(`A ticket has been assigned to you: <strong style="color:#ededed;">%s</strong>`, body),
			ctaLabel:    "View Ticket",
			ctaURL:      ticketURL,
		}
	case "ticket_resolved":
		return emailContent{
			heading:     "Your ticket has been resolved",
			description: fmt.Sprintf(`Your support ticket <strong style="color:#ededed;">%s</strong> has been marked as resolved.`, body),
			ctaLabel:    "View Ticket",
			ctaURL:      ticketURL,
		}
	case "ticket_message":
		ticketName := body
		if ticketName == "" {
			ticketName = "your ticket"
		}
		desc := fmt.Sprintf(`<strong style="color:#ededed;">%s</strong> sent a message on <strong style="color:#ededed;">%s</strong>`, actor, ticketName)
		if preview != "" {
			desc += fmt.Sprintf(`<div style="margin-top:16px;background-color:#252525;border-radius:8px;padding:16px 20px;border:1px solid #2e2e2e;"><p style="margin:0;font-size:13px;color:#b0b0b0;line-height:1.6;white-space:pre-wrap;">%s</p></div>`, preview)
		}
		return emailContent{
			heading:     "New message on ticket",
			description: desc,
			ctaLabel:    "View Ticket",
			ctaURL:      ticketURL,
		}
	case "sla_breach":
		desc := fmt.Sprintf(`<strong style="color:#ff4867;">%s</strong>`, payload.Title)
		if body != "" {
			desc += " &mdash; " + body
		}
		return emailContent{
			heading:     "SLA Breach Detected",
			description: desc,
			ctaLabel:    "View Ticket",
			ctaURL:      ticketURL,
		}
	default:
		return emailContent{
			heading:     payload.Title,
			description: body,
			ctaLabel:    "Open Trackr",
			ctaURL:      siteURL,
		}
	}
}

func buildEmailHTML(payload NotificationPayload, siteURL string) string {
	content := getEmailContent(payload, siteURL)
	recipientName := "there"
	if payload.RecipientName != nil {
		recipientName = *payload.RecipientName
	}
	accentColor := "#ff4867"
	if payload.Type == "sla_breach" {
		accentColor = "#ef4444"
	}

	return fmt.Sprintf(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>%s</title>
</head>
<body style="margin:0;padding:0;background-color:#111113;font-family:'JetBrains Mono',SFMono-Regular,Menlo,Consolas,monospace;">
  <table role="presentation" width="100%%" cellpadding="0" cellspacing="0" style="background-color:#111113;padding:40px 0;">
    <tr>
      <td align="center">
        <table role="presentation" width="480" cellpadding="0" cellspacing="0" style="background-color:#18181b;border-radius:12px;border:1px solid #2e2e2e;overflow:hidden;">
          <!-- Header -->
          <tr>
            <td style="padding:32px 40px 24px;text-align:center;border-bottom:1px solid #2e2e2e;">
              <div style="display:inline-block;margin-bottom:16px;">
                <svg width="32" height="32" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <rect x="1.27" y="1.26" width="3.66" height="13.46" rx="1" fill="#FF4867"/>
                  <rect x="11.02" y="1.26" width="3.66" height="13.46" rx="1" fill="#FF4867"/>
                  <rect x="6.15" y="1.26" width="3.66" height="13.46" rx="1" fill="#FF4867"/>
                </svg>
              </div>
              <div style="font-size:18px;font-weight:700;color:#ededed;letter-spacing:4px;">TRACKR</div>
            </td>
          </tr>
          <!-- Body -->
          <tr>
            <td style="padding:32px 40px;">
              <h1 style="margin:0 0 8px;font-size:20px;font-weight:600;color:#ededed;">%s</h1>
              <p style="margin:0 0 4px;font-size:13px;color:#8b8b8b;line-height:1.5;">Hi %s,</p>
              <p style="margin:0 0 24px;font-size:14px;color:#8b8b8b;line-height:1.6;">
                %s
              </p>
              <table role="presentation" width="100%%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="padding:8px 0 24px;">
                    <a href="%s" style="display:inline-block;background-color:%s;color:#ffffff;font-family:'JetBrains Mono',SFMono-Regular,Menlo,Consolas,monospace;font-size:13px;font-weight:600;text-decoration:none;padding:12px 32px;border-radius:8px;letter-spacing:0.5px;">
                      %s
                    </a>
                  </td>
                </tr>
              </table>
              <p style="margin:0;font-size:12px;color:#71717a;line-height:1.5;">
                You can manage your email notification preferences in Trackr.
              </p>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="padding:20px 40px;border-top:1px solid #2e2e2e;text-align:center;">
              <p style="margin:0;font-size:11px;color:#71717a;">&copy; Trackr</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`, content.heading, content.heading, recipientName, content.description, content.ctaURL, accentColor, content.ctaLabel)
}
