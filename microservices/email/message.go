package main

import (
	"bytes"
	"crypto/rand"
	"fmt"
	"mime/quotedprintable"
	"strings"
	"time"
)

func buildMIMEMessage(from, to, subject, htmlBody, plainBody, siteURL string) []byte {
	boundary := generateBoundary()
	msgID := generateMessageID()

	var buf bytes.Buffer

	headers := []struct{ k, v string }{
		{"From", from},
		{"To", to},
		{"Subject", subject},
		{"Date", time.Now().UTC().Format(time.RFC1123Z)},
		{"Message-ID", msgID},
		{"MIME-Version", "1.0"},
		{"List-Unsubscribe", fmt.Sprintf("<%s/settings/notifications>", strings.TrimRight(siteURL, "/"))},
		{"Reply-To", from},
		{"X-Mailer", "Trackr-Email/1.0"},
		{"Content-Type", fmt.Sprintf("multipart/alternative; boundary=\"%s\"", boundary)},
	}
	for _, h := range headers {
		fmt.Fprintf(&buf, "%s: %s\r\n", h.k, h.v)
	}
	buf.WriteString("\r\n")

	// Plain text part (first — least preferred in multipart/alternative)
	fmt.Fprintf(&buf, "--%s\r\n", boundary)
	buf.WriteString("Content-Type: text/plain; charset=UTF-8\r\n")
	buf.WriteString("Content-Transfer-Encoding: quoted-printable\r\n\r\n")
	qpEncode(&buf, plainBody)
	buf.WriteString("\r\n")

	// HTML part (second — preferred by clients that support HTML)
	fmt.Fprintf(&buf, "--%s\r\n", boundary)
	buf.WriteString("Content-Type: text/html; charset=UTF-8\r\n")
	buf.WriteString("Content-Transfer-Encoding: quoted-printable\r\n\r\n")
	qpEncode(&buf, htmlBody)
	buf.WriteString("\r\n")

	// Closing boundary
	fmt.Fprintf(&buf, "--%s--\r\n", boundary)

	return buf.Bytes()
}

func qpEncode(buf *bytes.Buffer, content string) {
	w := quotedprintable.NewWriter(buf)
	w.Write([]byte(content))
	w.Close()
}

func generateMessageID() string {
	b := make([]byte, 16)
	rand.Read(b)
	domain := cfg.SMTPFromEmail
	if idx := strings.LastIndex(domain, "@"); idx >= 0 {
		domain = domain[idx+1:]
	}
	return fmt.Sprintf("<%x.%x@%s>", b[:8], b[8:], domain)
}

func generateBoundary() string {
	b := make([]byte, 16)
	rand.Read(b)
	return fmt.Sprintf("==Trackr_%x==", b)
}
