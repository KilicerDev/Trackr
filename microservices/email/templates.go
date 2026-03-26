package main

import (
	"bytes"
	"fmt"
	"html/template"
	"log"
	"strings"
)

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
	heading    string
	paragraphs []string
	quote      string
	alertLevel string
	ctaLabel   string
	ctaURL     string
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
			heading:    "Task assigned to you",
			paragraphs: []string{fmt.Sprintf("%s assigned you a task: %s", actor, body)},
			ctaLabel:   "Open Trackr",
			ctaURL:     taskURL,
		}
	case "task_status_change":
		desc := payload.Title
		if body != "" {
			desc += " \u2014 " + body
		}
		return emailContent{
			heading:    "Task status updated",
			paragraphs: []string{desc},
			ctaLabel:   "Open Trackr",
			ctaURL:     taskURL,
		}
	case "task_comment":
		taskName := body
		if taskName == "" {
			taskName = "a task"
		}
		return emailContent{
			heading:    "New comment on task",
			paragraphs: []string{fmt.Sprintf("%s commented on %s", actor, taskName)},
			quote:      preview,
			ctaLabel:   "Open Trackr",
			ctaURL:     taskURL,
		}
	case "ticket_created":
		return emailContent{
			heading:    "New support ticket",
			paragraphs: []string{fmt.Sprintf("A new ticket has been created: %s", payload.Title)},
			ctaLabel:   "View Ticket",
			ctaURL:     ticketURL,
		}
	case "ticket_assigned":
		return emailContent{
			heading:    "Ticket assigned to you",
			paragraphs: []string{fmt.Sprintf("A ticket has been assigned to you: %s", body)},
			ctaLabel:   "View Ticket",
			ctaURL:     ticketURL,
		}
	case "ticket_resolved":
		return emailContent{
			heading:    "Your ticket has been resolved",
			paragraphs: []string{fmt.Sprintf("Your support ticket %s has been marked as resolved.", body)},
			ctaLabel:   "View Ticket",
			ctaURL:     ticketURL,
		}
	case "ticket_message":
		ticketName := body
		if ticketName == "" {
			ticketName = "your ticket"
		}
		return emailContent{
			heading:    "New message on ticket",
			paragraphs: []string{fmt.Sprintf("%s sent a message on %s", actor, ticketName)},
			quote:      preview,
			ctaLabel:   "View Ticket",
			ctaURL:     ticketURL,
		}
	case "sla_breach":
		desc := payload.Title
		if body != "" {
			desc += " \u2014 " + body
		}
		return emailContent{
			heading:    "SLA Breach Detected",
			paragraphs:  []string{desc},
			alertLevel: "danger",
			ctaLabel:   "View Ticket",
			ctaURL:     ticketURL,
		}
	default:
		return emailContent{
			heading:    payload.Title,
			paragraphs: []string{body},
			ctaLabel:   "Open Trackr",
			ctaURL:     siteURL,
		}
	}
}

// Template data passed to the HTML template.
type emailTemplateData struct {
	Heading       string
	RecipientName string
	Paragraphs    []string
	Quote         string
	CTAURL        string
	CTALabel      string
	AccentColor   string
	AlertLevel    string
}

var emailHTMLTemplate = template.Must(template.New("email").Parse(emailHTMLTemplateStr))

const emailHTMLTemplateStr = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>{{.Heading}}</title>
</head>
<body style="margin:0;padding:0;background-color:#111113;font-family:'JetBrains Mono',SFMono-Regular,Menlo,Consolas,monospace;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#111113;padding:40px 0;">
    <tr>
      <td align="center">
        <table role="presentation" width="480" cellpadding="0" cellspacing="0" style="background-color:#18181b;border-radius:12px;border:1px solid #2e2e2e;overflow:hidden;">
          <!-- Header -->
          <tr>
            <td style="padding:32px 40px 24px;text-align:center;border-bottom:1px solid #2e2e2e;">
              <div style="display:inline-block;margin-bottom:16px;">
                <!--[if mso]>
                <table role="presentation" cellpadding="0" cellspacing="0"><tr>
                  <td style="width:8px;height:32px;background-color:#FF4867;border-radius:2px;">&nbsp;</td>
                  <td style="width:4px;">&nbsp;</td>
                  <td style="width:8px;height:32px;background-color:#FF4867;border-radius:2px;">&nbsp;</td>
                  <td style="width:4px;">&nbsp;</td>
                  <td style="width:8px;height:32px;background-color:#FF4867;border-radius:2px;">&nbsp;</td>
                </tr></table>
                <![endif]-->
                <!--[if !mso]><!-->
                <span style="display:inline-block;width:8px;height:32px;background-color:#FF4867;border-radius:2px;margin:0 2px;"></span>
                <span style="display:inline-block;width:8px;height:32px;background-color:#FF4867;border-radius:2px;margin:0 2px;"></span>
                <span style="display:inline-block;width:8px;height:32px;background-color:#FF4867;border-radius:2px;margin:0 2px;"></span>
                <!--<![endif]-->
              </div>
              <div style="font-size:18px;font-weight:700;color:#ededed;letter-spacing:4px;">TRACKR</div>
            </td>
          </tr>
          <!-- Body -->
          <tr>
            <td style="padding:32px 40px;">
              <h1 style="margin:0 0 8px;font-size:20px;font-weight:600;color:{{if eq .AlertLevel "danger"}}#ef4444{{else}}#ededed{{end}};">{{.Heading}}</h1>
              <p style="margin:0 0 4px;font-size:13px;color:#8b8b8b;line-height:1.5;">Hi {{.RecipientName}},</p>
              {{range .Paragraphs}}
              <p style="margin:0 0 24px;font-size:14px;color:#8b8b8b;line-height:1.6;">{{.}}</p>
              {{end}}
              {{if .Quote}}
              <div style="margin:0 0 24px;background-color:#252525;border-radius:8px;padding:16px 20px;border:1px solid #2e2e2e;">
                <p style="margin:0;font-size:13px;color:#b0b0b0;line-height:1.6;white-space:pre-wrap;">{{.Quote}}</p>
              </div>
              {{end}}
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="padding:8px 0 24px;">
                    <a href="{{.CTAURL}}" style="display:inline-block;background-color:{{.AccentColor}};color:#ffffff;font-family:'JetBrains Mono',SFMono-Regular,Menlo,Consolas,monospace;font-size:13px;font-weight:600;text-decoration:none;padding:12px 32px;border-radius:8px;letter-spacing:0.5px;">
                      {{.CTALabel}}
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
              <p style="margin:0;font-size:11px;color:#71717a;">&#169; Trackr</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`

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

	data := emailTemplateData{
		Heading:       content.heading,
		RecipientName: recipientName,
		Paragraphs:    content.paragraphs,
		Quote:         content.quote,
		CTAURL:        content.ctaURL,
		CTALabel:      content.ctaLabel,
		AccentColor:   accentColor,
		AlertLevel:    content.alertLevel,
	}

	var buf bytes.Buffer
	if err := emailHTMLTemplate.Execute(&buf, data); err != nil {
		log.Printf("Template execution error: %v", err)
		return "<html><body>Notification from Trackr</body></html>"
	}
	return buf.String()
}

func buildEmailPlainText(payload NotificationPayload, siteURL string) string {
	content := getEmailContent(payload, siteURL)
	recipientName := "there"
	if payload.RecipientName != nil {
		recipientName = *payload.RecipientName
	}

	var sb strings.Builder
	sb.WriteString("TRACKR\n")
	sb.WriteString(strings.Repeat("-", 40))
	sb.WriteString("\n\n")
	sb.WriteString(content.heading)
	sb.WriteString("\n\n")
	fmt.Fprintf(&sb, "Hi %s,\n\n", recipientName)
	for _, p := range content.paragraphs {
		sb.WriteString(p)
		sb.WriteString("\n\n")
	}
	if content.quote != "" {
		sb.WriteString("> ")
		sb.WriteString(strings.ReplaceAll(content.quote, "\n", "\n> "))
		sb.WriteString("\n\n")
	}
	fmt.Fprintf(&sb, "%s: %s\n\n", content.ctaLabel, content.ctaURL)
	sb.WriteString(strings.Repeat("-", 40))
	sb.WriteString("\nYou can manage your email notification preferences in Trackr.\n")
	fmt.Fprintf(&sb, "%s/settings/notifications\n", strings.TrimRight(siteURL, "/"))

	return sb.String()
}
