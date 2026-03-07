package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5/pgxpool"
	pgvector "github.com/pgvector/pgvector-go"
)

// --- Config ---

type Config struct {
	ServiceToken string
	OllamaURL    string
	DatabaseURL  string
	Port         string
}

func loadConfig() Config {
	c := Config{
		ServiceToken: os.Getenv("SERVICE_TOKEN"),
		OllamaURL:    os.Getenv("OLLAMA_URL"),
		DatabaseURL:  os.Getenv("DATABASE_URL"),
		Port:         os.Getenv("PORT"),
	}
	if c.OllamaURL == "" {
		c.OllamaURL = "http://ollama:11434"
	}
	if c.Port == "" {
		c.Port = "8080"
	}
	if c.ServiceToken == "" {
		log.Fatal("SERVICE_TOKEN is required")
	}
	if c.DatabaseURL == "" {
		log.Fatal("DATABASE_URL is required")
	}
	return c
}

// --- Types ---

type IndexRequest struct {
	SourceType string          `json:"source_type"`
	SourceID   string          `json:"source_id"`
	ParentID   *string         `json:"parent_id"`
	OrgID      string          `json:"org_id"`
	Title      string          `json:"title"`
	Preview    *string         `json:"preview"`
	Content    string          `json:"content"`
	Metadata   json.RawMessage `json:"metadata"`
}

type SearchRequest struct {
	Query  string   `json:"query"`
	OrgID  string   `json:"org_id"`
	OrgIDs []string `json:"org_ids"`
	Types  []string `json:"types"`
	Limit  int      `json:"limit"`
}

type SearchResult struct {
	SourceType string          `json:"source_type"`
	SourceID   string          `json:"source_id"`
	ParentID   *string         `json:"parent_id"`
	Title      string          `json:"title"`
	Preview    *string         `json:"preview"`
	Metadata   json.RawMessage `json:"metadata"`
	Similarity float64         `json:"similarity"`
}

type OllamaEmbedRequest struct {
	Model string `json:"model"`
	Input string `json:"input"`
}

type OllamaEmbedResponse struct {
	Embeddings [][]float32 `json:"embeddings"`
}

// --- Server ---

type Server struct {
	cfg Config
	db  *pgxpool.Pool
}

func (s *Server) getEmbedding(ctx context.Context, text string) ([]float32, error) {
	body, _ := json.Marshal(OllamaEmbedRequest{
		Model: "nomic-embed-text",
		Input: text,
	})

	req, err := http.NewRequestWithContext(ctx, "POST", s.cfg.OllamaURL+"/api/embed", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("creating ollama request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("calling ollama: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("ollama returned %d: %s", resp.StatusCode, string(respBody))
	}

	var result OllamaEmbedResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("decoding ollama response: %w", err)
	}
	if len(result.Embeddings) == 0 {
		return nil, fmt.Errorf("ollama returned no embeddings")
	}
	return result.Embeddings[0], nil
}

// --- Handlers ---

func (s *Server) handleIndex(w http.ResponseWriter, r *http.Request) {
	var req IndexRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid json"}`, http.StatusBadRequest)
		return
	}
	if req.SourceType == "" || req.SourceID == "" || req.OrgID == "" || req.Content == "" {
		http.Error(w, `{"error":"source_type, source_id, org_id, content are required"}`, http.StatusBadRequest)
		return
	}

	embedding, err := s.getEmbedding(r.Context(), req.Content)
	if err != nil {
		log.Printf("ERROR embedding: %v", err)
		http.Error(w, `{"error":"embedding failed"}`, http.StatusBadGateway)
		return
	}

	meta := req.Metadata
	if meta == nil {
		meta = json.RawMessage(`{}`)
	}

	vec := pgvector.NewVector(embedding)

	_, err = s.db.Exec(r.Context(), `
		INSERT INTO public.search_documents (source_type, source_id, parent_id, title, preview, content, metadata, embedding, org_id, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, now())
		ON CONFLICT (source_type, source_id)
		DO UPDATE SET
			parent_id  = EXCLUDED.parent_id,
			title      = EXCLUDED.title,
			preview    = EXCLUDED.preview,
			content    = EXCLUDED.content,
			metadata   = EXCLUDED.metadata,
			embedding  = EXCLUDED.embedding,
			org_id     = EXCLUDED.org_id,
			updated_at = now()
	`, req.SourceType, req.SourceID, req.ParentID, req.Title, req.Preview, req.Content, meta, vec, req.OrgID)
	if err != nil {
		log.Printf("ERROR db upsert: %v", err)
		http.Error(w, `{"error":"database error"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"status":"indexed"}`))
}

func (s *Server) handleSearch(w http.ResponseWriter, r *http.Request) {
	var req SearchRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid json"}`, http.StatusBadRequest)
		return
	}
	// Support both single org_id and org_ids array
	if len(req.OrgIDs) == 0 && req.OrgID != "" {
		req.OrgIDs = []string{req.OrgID}
	}
	if req.Query == "" || len(req.OrgIDs) == 0 {
		http.Error(w, `{"error":"query and org_ids are required"}`, http.StatusBadRequest)
		return
	}
	if req.Limit <= 0 || req.Limit > 50 {
		req.Limit = 20
	}

	embedding, err := s.getEmbedding(r.Context(), req.Query)
	if err != nil {
		log.Printf("ERROR embedding query: %v", err)
		http.Error(w, `{"error":"embedding failed"}`, http.StatusBadGateway)
		return
	}

	vec := pgvector.NewVector(embedding)

	var types interface{}
	if len(req.Types) > 0 {
		types = req.Types
	}

	rows, err := s.db.Query(r.Context(), `
		SELECT source_type, source_id, parent_id, title, preview, metadata, similarity
		FROM universal_search($1, $2::uuid[], $3, 0.4, $4)
	`, vec, req.OrgIDs, types, req.Limit)
	if err != nil {
		log.Printf("ERROR search query: %v", err)
		http.Error(w, `{"error":"search failed"}`, http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	results := []SearchResult{}
	for rows.Next() {
		var sr SearchResult
		if err := rows.Scan(&sr.SourceType, &sr.SourceID, &sr.ParentID, &sr.Title, &sr.Preview, &sr.Metadata, &sr.Similarity); err != nil {
			log.Printf("ERROR scanning row: %v", err)
			continue
		}
		results = append(results, sr)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{"results": results})
}

func (s *Server) handleDelete(w http.ResponseWriter, r *http.Request) {
	sourceType := chi.URLParam(r, "sourceType")
	sourceID := chi.URLParam(r, "sourceId")

	if sourceType == "" || sourceID == "" {
		http.Error(w, `{"error":"source_type and source_id are required"}`, http.StatusBadRequest)
		return
	}

	_, err := s.db.Exec(r.Context(),
		`DELETE FROM public.search_documents WHERE source_type = $1 AND source_id = $2`,
		sourceType, sourceID,
	)
	if err != nil {
		log.Printf("ERROR delete: %v", err)
		http.Error(w, `{"error":"delete failed"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"status":"deleted"}`))
}

func (s *Server) handleReindex(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	var indexed int

	// Reindex tickets
	rows, err := s.db.Query(ctx, `
		SELECT t.id, t.subject, t.description, t.status, t.priority, t.channel, t.category, t.organization_id
		FROM public.support_tickets t
		WHERE t.deleted_at IS NULL
	`)
	if err != nil {
		log.Printf("ERROR querying tickets: %v", err)
		http.Error(w, `{"error":"failed to query tickets"}`, http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	for rows.Next() {
		var id, orgID string
		var subject string
		var description *string
		var status, priority, channel string
		var category *string
		if err := rows.Scan(&id, &subject, &description, &status, &priority, &channel, &category, &orgID); err != nil {
			log.Printf("ERROR scanning ticket: %v", err)
			continue
		}
		content := subject
		if description != nil {
			content += " " + *description
		}
		preview := truncate(description, 200)
		meta := map[string]interface{}{"status": status, "priority": priority, "channel": channel, "category": category}
		metaJSON, _ := json.Marshal(meta)

		s.indexDocument(ctx, "ticket", id, nil, orgID, subject, preview, content, metaJSON)
		indexed++
	}

	// Reindex tasks
	rows2, err := s.db.Query(ctx, `
		SELECT t.id, t.title, t.description, t.status, t.priority, t.type, t.short_id, t.project_id,
		       p.name AS project_name, p.color AS project_color
		FROM public.tasks t
		JOIN public.projects p ON p.id = t.project_id
		WHERE t.deleted_at IS NULL
	`)
	if err != nil {
		log.Printf("ERROR querying tasks: %v", err)
	} else {
		defer rows2.Close()
		for rows2.Next() {
			var id, title, status, priority, taskType, projectID string
			var description, shortID, projectName, projectColor *string
			if err := rows2.Scan(&id, &title, &description, &status, &priority, &taskType, &shortID, &projectID, &projectName, &projectColor); err != nil {
				log.Printf("ERROR scanning task: %v", err)
				continue
			}
			displayTitle := title
			if shortID != nil {
				displayTitle = *shortID + ": " + title
			}
			content := title
			if description != nil {
				content += " " + *description
			}
			preview := truncate(description, 200)
			meta := map[string]interface{}{"status": status, "priority": priority, "type": taskType, "short_id": shortID, "project_id": projectID, "project_name": projectName, "project_color": projectColor}
			metaJSON, _ := json.Marshal(meta)

			orgID := s.getProjectOrgID(ctx, projectID)
			if orgID == "" {
				continue
			}

			parentID := projectID
			s.indexDocument(ctx, "task", id, &parentID, orgID, displayTitle, preview, content, metaJSON)
			indexed++
		}
	}

	// Reindex ticket messages
	rows3, err := s.db.Query(ctx, `
		SELECT m.id, m.body, m.is_internal_note, m.ticket_id,
		       t.subject AS ticket_subject, t.organization_id,
		       u.full_name AS sender_name
		FROM public.support_ticket_messages m
		JOIN public.support_tickets t ON t.id = m.ticket_id
		JOIN public.users u ON u.id = m.sender_id
		WHERE m.deleted_at IS NULL AND t.deleted_at IS NULL
	`)
	if err != nil {
		log.Printf("ERROR querying messages: %v", err)
	} else {
		defer rows3.Close()
		for rows3.Next() {
			var id, body, ticketID, ticketSubject, orgID, senderName string
			var isInternal bool
			if err := rows3.Scan(&id, &body, &isInternal, &ticketID, &ticketSubject, &orgID, &senderName); err != nil {
				log.Printf("ERROR scanning message: %v", err)
				continue
			}
			displayTitle := "Message in: " + ticketSubject
			preview := truncateStr(body, 200)
			meta := map[string]interface{}{"ticket_id": ticketID, "ticket_subject": ticketSubject, "sender_name": senderName, "is_internal_note": isInternal}
			metaJSON, _ := json.Marshal(meta)

			s.indexDocument(ctx, "ticket_message", id, &ticketID, orgID, displayTitle, &preview, body, metaJSON)
			indexed++
		}
	}

	// Reindex task comments
	rows4, err := s.db.Query(ctx, `
		SELECT c.id, c.content, c.task_id,
		       t.title AS task_title, t.short_id, t.project_id,
		       p.organization_id,
		       u.full_name AS user_name
		FROM public.task_comments c
		JOIN public.tasks t ON t.id = c.task_id
		JOIN public.projects p ON p.id = t.project_id
		JOIN public.users u ON u.id = c.user_id
		WHERE c.deleted_at IS NULL AND t.deleted_at IS NULL
	`)
	if err != nil {
		log.Printf("ERROR querying comments: %v", err)
	} else {
		defer rows4.Close()
		for rows4.Next() {
			var id, content, taskID, taskTitle, projectID, orgID, userName string
			var shortID *string
			if err := rows4.Scan(&id, &content, &taskID, &taskTitle, &shortID, &projectID, &orgID, &userName); err != nil {
				log.Printf("ERROR scanning comment: %v", err)
				continue
			}
			label := "Comment on: " + taskTitle
			if shortID != nil {
				label = "Comment on: " + *shortID
			}
			preview := truncateStr(content, 200)
			meta := map[string]interface{}{"task_id": taskID, "task_short_id": shortID, "task_title": taskTitle, "project_id": projectID, "user_name": userName}
			metaJSON, _ := json.Marshal(meta)

			s.indexDocument(ctx, "task_comment", id, &taskID, orgID, label, &preview, content, metaJSON)
			indexed++
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{"status": "reindex_complete", "indexed": indexed})
}

func (s *Server) indexDocument(ctx context.Context, sourceType, sourceID string, parentID *string, orgID, title string, preview *string, content string, metadata json.RawMessage) {
	embedding, err := s.getEmbedding(ctx, content)
	if err != nil {
		log.Printf("ERROR embedding %s/%s: %v", sourceType, sourceID, err)
		return
	}

	vec := pgvector.NewVector(embedding)

	_, err = s.db.Exec(ctx, `
		INSERT INTO public.search_documents (source_type, source_id, parent_id, title, preview, content, metadata, embedding, org_id, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, now())
		ON CONFLICT (source_type, source_id)
		DO UPDATE SET
			parent_id  = EXCLUDED.parent_id,
			title      = EXCLUDED.title,
			preview    = EXCLUDED.preview,
			content    = EXCLUDED.content,
			metadata   = EXCLUDED.metadata,
			embedding  = EXCLUDED.embedding,
			org_id     = EXCLUDED.org_id,
			updated_at = now()
	`, sourceType, sourceID, parentID, title, preview, content, metadata, vec, orgID)
	if err != nil {
		log.Printf("ERROR upserting %s/%s: %v", sourceType, sourceID, err)
	}
}

func (s *Server) getProjectOrgID(ctx context.Context, projectID string) string {
	var orgID string
	err := s.db.QueryRow(ctx, `SELECT organization_id FROM public.projects WHERE id = $1`, projectID).Scan(&orgID)
	if err != nil {
		return ""
	}
	return orgID
}

// --- Helpers ---

func truncate(s *string, maxLen int) *string {
	if s == nil {
		return nil
	}
	t := truncateStr(*s, maxLen)
	return &t
}

func truncateStr(s string, maxLen int) string {
	runes := []rune(s)
	if len(runes) <= maxLen {
		return s
	}
	return string(runes[:maxLen]) + "..."
}

// --- Auth middleware ---

func bearerAuth(token string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.URL.Path == "/health" {
				next.ServeHTTP(w, r)
				return
			}
			auth := r.Header.Get("Authorization")
			if !strings.HasPrefix(auth, "Bearer ") || strings.TrimPrefix(auth, "Bearer ") != token {
				http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// --- Main ---

func main() {
	cfg := loadConfig()

	pool, err := pgxpool.New(context.Background(), cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Unable to connect to database: %v", err)
	}
	defer pool.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := pool.Ping(ctx); err != nil {
		log.Fatalf("Unable to ping database: %v", err)
	}

	// Enable pgvector for the connection pool
	_, err = pool.Exec(context.Background(), "CREATE EXTENSION IF NOT EXISTS vector")
	if err != nil {
		log.Printf("WARN: could not ensure vector extension: %v", err)
	}

	srv := &Server{cfg: cfg, db: pool}

	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(120 * time.Second))
	r.Use(bearerAuth(cfg.ServiceToken))

	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"ok"}`))
	})

	r.Post("/index", srv.handleIndex)
	r.Post("/search", srv.handleSearch)
	r.Delete("/index/{sourceType}/{sourceId}", srv.handleDelete)
	r.Post("/reindex", srv.handleReindex)

	log.Printf("embed-service listening on :%s", cfg.Port)
	log.Fatal(http.ListenAndServe(":"+cfg.Port, r))
}
