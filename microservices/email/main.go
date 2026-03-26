package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"github.com/emersion/go-sasl"
	"github.com/emersion/go-smtp"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Config struct {
	Port           string
	DatabaseURL    string
	SMTPHost       string
	SMTPPort       string
	SMTPUser       string
	SMTPPass       string
	SMTPSenderName string
	SMTPFromEmail  string
	SiteURL        string
}

type NotificationPayload struct {
	NotificationID string  `json:"notification_id"`
	RecipientEmail string  `json:"recipient_email"`
	RecipientName  *string `json:"recipient_name"`
	ActorName      *string `json:"actor_name"`
	Type           string  `json:"type"`
	Title          string  `json:"title"`
	Body           *string `json:"body"`
	ResourceType   *string `json:"resource_type"`
	ResourceID     *string `json:"resource_id"`
	ContentPreview *string `json:"content_preview"`
}

var cfg Config

func main() {
	cfg = Config{
		Port:           envOr("PORT", "8080"),
		DatabaseURL:    envOr("DATABASE_URL", "postgresql://postgres:postgres@localhost:54322/postgres"),
		SMTPHost:       envOr("SMTP_HOST", "localhost"),
		SMTPPort:       envOr("SMTP_PORT", "1025"),
		SMTPUser:       os.Getenv("SMTP_USER"),
		SMTPPass:       os.Getenv("SMTP_PASS"),
		SMTPSenderName: envOr("SMTP_SENDER_NAME", "Trackr"),
		SMTPFromEmail:  envOr("SMTP_FROM_EMAIL", "notifications@trackr.local"),
		SiteURL:        envOr("SITE_URL", "http://localhost:5173"),
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Start LISTEN/NOTIFY listener
	go listenForNotifications(ctx)

	// Health check endpoint
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"ok"}`))
	})

	go func() {
		log.Printf("Health endpoint on :%s", cfg.Port)
		log.Fatal(http.ListenAndServe(":"+cfg.Port, nil))
	}()

	log.Printf("Email service started — listening for DB notifications on %s", cfg.DatabaseURL)

	// Wait for shutdown signal
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
	<-sig
	log.Println("Shutting down...")
	cancel()
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func listenForNotifications(ctx context.Context) {
	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer pool.Close()

	conn, err := pool.Acquire(ctx)
	if err != nil {
		log.Fatalf("Failed to acquire connection: %v", err)
	}
	defer conn.Release()

	_, err = conn.Exec(ctx, "LISTEN email_notification")
	if err != nil {
		log.Fatalf("Failed to LISTEN: %v", err)
	}

	log.Println("Listening for email_notification events...")

	for {
		notification, err := conn.Conn().WaitForNotification(ctx)
		if err != nil {
			if ctx.Err() != nil {
				return // shutdown
			}
			log.Printf("Error waiting for notification: %v", err)
			continue
		}

		var payload NotificationPayload
		if err := json.Unmarshal([]byte(notification.Payload), &payload); err != nil {
			log.Printf("Failed to parse notification payload: %v", err)
			continue
		}

		if payload.RecipientEmail == "" || payload.Type == "" || payload.Title == "" {
			log.Printf("Skipping notification with missing fields")
			continue
		}

		subject := getSubjectLine(payload.Type, payload.Title, ptrStr(payload.Body))
		htmlBody := buildEmailHTML(payload, cfg.SiteURL)
		plainBody := buildEmailPlainText(payload, cfg.SiteURL)

		if err := sendEmail(payload.RecipientEmail, subject, htmlBody, plainBody); err != nil {
			log.Printf("Failed to send email to %s: %v", payload.RecipientEmail, err)
			continue
		}

		log.Printf("Email sent to %s (type: %s)", payload.RecipientEmail, payload.Type)
	}
}

func sendEmail(to, subject, htmlBody, plainBody string) error {
	from := fmt.Sprintf("%s <%s>", cfg.SMTPSenderName, cfg.SMTPFromEmail)
	addr := net.JoinHostPort(cfg.SMTPHost, cfg.SMTPPort)

	msgBytes := buildMIMEMessage(from, to, subject, htmlBody, plainBody, cfg.SiteURL)

	var auth sasl.Client
	if cfg.SMTPUser != "" {
		auth = sasl.NewPlainClient("", cfg.SMTPUser, cfg.SMTPPass)
	}

	if cfg.SMTPPort == "465" {
		return smtp.SendMailTLS(addr, auth, cfg.SMTPFromEmail, []string{to}, bytes.NewReader(msgBytes))
	}
	return smtp.SendMail(addr, auth, cfg.SMTPFromEmail, []string{to}, bytes.NewReader(msgBytes))
}

func ptrStr(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
