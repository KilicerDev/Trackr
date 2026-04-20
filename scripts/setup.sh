#!/usr/bin/env bash
set -euo pipefail

# Trackr Setup Script
# Generates .env and Caddyfile for Trackr deployment.
# Usage: bash scripts/setup.sh [--non-interactive]
#
# Requirements: openssl, bash 4+

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Colors ────────────────────────────────────────────────────────────────────

if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  DIM='\033[2m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' NC=''
fi

# ── Globals ───────────────────────────────────────────────────────────────────

NON_INTERACTIVE=false
SETUP_COMPLETE=false
DEPLOY_MODE=""
DOMAIN=""
API_DOMAIN=""
SITE_URL_VAL=""
SUPABASE_PUBLIC_URL_VAL=""
API_EXTERNAL_URL_VAL=""
ADDITIONAL_REDIRECT_URLS_VAL=""
PUBLIC_SUPABASE_URL_VAL=""

SMTP_HOST_VAL="supabase-inbucket"
SMTP_PORT_VAL="2500"
SMTP_USER_VAL="fake_mail_user"
SMTP_PASS_VAL="fake_mail_password"
SMTP_ADMIN_EMAIL_VAL="admin@example.com"
SMTP_SENDER_NAME_VAL="Trackr"

DASHBOARD_USERNAME_VAL="supabase"

# Secrets (populated by generate_secrets/generate_jwts)
POSTGRES_PASSWORD_VAL=""
JWT_SECRET_VAL=""
ANON_KEY_VAL=""
SERVICE_ROLE_KEY_VAL=""
DASHBOARD_PASSWORD_VAL=""
SECRET_KEY_BASE_VAL=""
VAULT_ENC_KEY_VAL=""
PG_META_CRYPTO_KEY_VAL=""
LOGFLARE_PUBLIC_VAL=""
LOGFLARE_PRIVATE_VAL=""
S3_KEY_ID_VAL=""
S3_KEY_SECRET_VAL=""
POOLER_TENANT_ID_VAL=""

# ── Trap ──────────────────────────────────────────────────────────────────────

cleanup() {
  if [ "$SETUP_COMPLETE" = false ]; then
    rm -f "$PROJECT_DIR/.env.tmp" "$PROJECT_DIR/Caddyfile.tmp"
    echo ""
    echo -e "${YELLOW}Setup interrupted. No files were modified.${NC}"
  fi
}
trap cleanup EXIT

# ── Helpers ───────────────────────────────────────────────────────────────────

info()  { echo -e "${CYAN}$1${NC}"; }
ok()    { echo -e "${GREEN}$1${NC}"; }
warn()  { echo -e "${YELLOW}$1${NC}"; }
err()   { echo -e "${RED}$1${NC}" >&2; }

prompt_yn() {
  local message="$1" default="${2:-n}"
  if [ "$NON_INTERACTIVE" = true ]; then
    [ "$default" = "y" ] && return 0 || return 1
  fi
  local suffix
  if [ "$default" = "y" ]; then suffix="[Y/n]"; else suffix="[y/N]"; fi
  while true; do
    read -rp "$(echo -e "${BOLD}${message}${NC} ${suffix} ")" answer
    answer="${answer:-$default}"
    case "$answer" in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
    esac
  done
}

prompt_value() {
  local message="$1" default="${2:-}" var_name="${3:-}"
  if [ "$NON_INTERACTIVE" = true ] && [ -n "$var_name" ]; then
    local env_val="${!var_name:-}"
    if [ -n "$env_val" ]; then
      printf '%s' "$env_val"
      return
    fi
  fi
  if [ "$NON_INTERACTIVE" = true ]; then
    printf '%s' "$default"
    return
  fi
  local display=""
  if [ -n "$default" ]; then display=" [${default}]"; fi
  read -rp "$(echo -e "${BOLD}${message}${NC}${display}: ")" value
  printf '%s' "${value:-$default}"
}

prompt_secret() {
  local message="$1" var_name="${2:-}"
  if [ "$NON_INTERACTIVE" = true ] && [ -n "$var_name" ]; then
    local env_val="${!var_name:-}"
    printf '%s' "$env_val"
    return
  fi
  if [ "$NON_INTERACTIVE" = true ]; then
    printf ''
    return
  fi
  read -srp "$(echo -e "${BOLD}${message}${NC}: ")" value
  echo ""
  printf '%s' "$value"
}

base64url_encode() {
  openssl enc -base64 -A | tr '+/' '-_' | tr -d '='
}

generate_jwt() {
  local role="$1" secret="$2"
  local iat
  iat=$(date +%s)
  local exp=$((iat + 315360000)) # 10 years

  local header='{"alg":"HS256","typ":"JWT"}'
  local payload="{\"role\":\"${role}\",\"iss\":\"supabase\",\"iat\":${iat},\"exp\":${exp}}"

  local h p sig
  h=$(printf '%s' "$header" | base64url_encode)
  p=$(printf '%s' "$payload" | base64url_encode)
  sig=$(printf '%s' "${h}.${p}" | openssl dgst -sha256 -hmac "$secret" -binary | base64url_encode)

  printf '%s' "${h}.${p}.${sig}"
}

generate_uuid() {
  local a b c d e
  a=$(openssl rand -hex 4)
  b=$(openssl rand -hex 2)
  c=$(openssl rand -hex 2)
  d=$(openssl rand -hex 2)
  e=$(openssl rand -hex 6)
  printf '%s' "${a}-${b}-${c}-${d}-${e}"
}

# ── Steps ─────────────────────────────────────────────────────────────────────

preflight_checks() {
  local missing=false

  if ! command -v openssl >/dev/null 2>&1; then
    err "openssl is required but not found. Please install it first."
    missing=true
  fi

  if ! command -v docker >/dev/null 2>&1; then
    warn "docker not found. You will need it to run Trackr."
  fi

  if ! docker compose version >/dev/null 2>&1; then
    warn "docker compose (v2) not found. You will need it to run Trackr."
  fi

  if [ ! -f "$PROJECT_DIR/docker-compose.yml" ]; then
    err "docker-compose.yml not found in ${PROJECT_DIR}."
    err "Please run this script from the Trackr repository root."
    missing=true
  fi

  if [ "$missing" = true ]; then
    exit 1
  fi
}

print_banner() {
  echo ""
  echo -e "${BOLD}${CYAN}"
  echo "  ╔════════════════════════════════════════╗"
  echo "  ║            Trackr Setup                ║"
  echo "  ║   Self-hosted project management       ║"
  echo "  ╚════════════════════════════════════════╝"
  echo -e "${NC}"
}

prompt_deployment_mode() {
  if [ "$NON_INTERACTIVE" = true ]; then
    DEPLOY_MODE="${TRACKR_DEPLOY_MODE:-local}"
    if [ "$DEPLOY_MODE" != "local" ] && [ "$DEPLOY_MODE" != "production" ]; then
      err "TRACKR_DEPLOY_MODE must be 'local' or 'production'"
      exit 1
    fi
    return
  fi

  echo -e "${BOLD}Deployment mode:${NC}"
  echo "  [1] Local development (localhost, no TLS)"
  echo "  [2] Production (custom domain, automatic TLS via Caddy)"
  echo ""

  while true; do
    read -rp "$(echo -e "${BOLD}Choose [1/2]${NC} [1]: ")" choice
    choice="${choice:-1}"
    case "$choice" in
      1) DEPLOY_MODE="local"; break ;;
      2) DEPLOY_MODE="production"; break ;;
      *) warn "Please enter 1 or 2." ;;
    esac
  done
  echo ""
}

prompt_domain() {
  if [ "$DEPLOY_MODE" = "local" ]; then
    DOMAIN="localhost"
    API_DOMAIN="localhost"
    SITE_URL_VAL="http://localhost"
    SUPABASE_PUBLIC_URL_VAL="http://localhost"
    API_EXTERNAL_URL_VAL="http://localhost"
    PUBLIC_SUPABASE_URL_VAL="http://localhost"
    ADDITIONAL_REDIRECT_URLS_VAL="http://localhost/auth/callback"
    return
  fi

  # Production mode
  if [ "$NON_INTERACTIVE" = true ]; then
    DOMAIN="${TRACKR_DOMAIN:-}"
    if [ -z "$DOMAIN" ]; then
      err "TRACKR_DOMAIN is required in production mode."
      exit 1
    fi
  else
    local domain_regex='^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)+$'
    while true; do
      DOMAIN=$(prompt_value "Enter your domain (e.g. trackr.example.com)")
      if [[ "$DOMAIN" =~ $domain_regex ]]; then
        break
      fi
      warn "Invalid domain format. Please enter a valid domain name."
    done
    echo ""
  fi

  API_DOMAIN="api.${DOMAIN}"
  SITE_URL_VAL="https://${DOMAIN}"
  SUPABASE_PUBLIC_URL_VAL="https://${API_DOMAIN}"
  API_EXTERNAL_URL_VAL="https://${API_DOMAIN}"
  PUBLIC_SUPABASE_URL_VAL="https://${API_DOMAIN}"
  ADDITIONAL_REDIRECT_URLS_VAL="https://${DOMAIN}/auth/callback"

  info "App URL:  https://${DOMAIN}"
  info "API URL:  https://${API_DOMAIN}"
  echo ""
}

prompt_smtp() {
  if [ "$NON_INTERACTIVE" = true ]; then
    SMTP_HOST_VAL="${TRACKR_SMTP_HOST:-supabase-inbucket}"
    SMTP_PORT_VAL="${TRACKR_SMTP_PORT:-2500}"
    SMTP_USER_VAL="${TRACKR_SMTP_USER:-fake_mail_user}"
    SMTP_PASS_VAL="${TRACKR_SMTP_PASS:-fake_mail_password}"
    SMTP_ADMIN_EMAIL_VAL="${TRACKR_SMTP_ADMIN_EMAIL:-admin@example.com}"
    SMTP_SENDER_NAME_VAL="${TRACKR_SMTP_SENDER_NAME:-Trackr}"
    return
  fi

  if prompt_yn "Configure SMTP for email delivery?" "n"; then
    SMTP_HOST_VAL=$(prompt_value "SMTP host (e.g. smtp.gmail.com)" "")
    SMTP_PORT_VAL=$(prompt_value "SMTP port" "587")
    SMTP_USER_VAL=$(prompt_value "SMTP username" "")
    SMTP_PASS_VAL=$(prompt_secret "SMTP password")
    SMTP_ADMIN_EMAIL_VAL=$(prompt_value "Admin email address" "")
    SMTP_SENDER_NAME_VAL=$(prompt_value "Sender display name" "Trackr")
    echo ""
  else
    if [ "$DEPLOY_MODE" = "production" ]; then
      echo ""
      warn "No SMTP configured. Email features (password resets, invites) will not work."
      warn "You can configure SMTP later in the .env file."
      echo ""
    fi
  fi
}

prompt_dashboard_username() {
  if [ "$NON_INTERACTIVE" = true ]; then
    DASHBOARD_USERNAME_VAL="${TRACKR_DASHBOARD_USERNAME:-supabase}"
    return
  fi
  DASHBOARD_USERNAME_VAL=$(prompt_value "Supabase dashboard username" "supabase")
  echo ""
}

check_existing_env() {
  if [ ! -f "$PROJECT_DIR/.env" ]; then
    return
  fi

  if [ "$NON_INTERACTIVE" = true ]; then
    return
  fi

  warn "An existing .env file was found."
  if prompt_yn "Create a backup before overwriting?" "y"; then
    local backup="$PROJECT_DIR/.env.backup.$(date +%Y%m%d%H%M%S)"
    cp "$PROJECT_DIR/.env" "$backup"
    ok "Backup saved to ${backup}"
  fi

  if ! prompt_yn "Overwrite the existing .env file?" "y"; then
    info "Setup cancelled."
    exit 0
  fi
  echo ""
}

check_existing_volumes() {
  if [ "$NON_INTERACTIVE" = true ]; then
    return
  fi

  if ! command -v docker >/dev/null 2>&1; then
    return
  fi

  local volume_name
  volume_name=$(docker volume ls --filter name=trackr_db-data --format '{{.Name}}' 2>/dev/null || true)

  if [ -z "$volume_name" ]; then
    return
  fi

  echo ""
  warn "Existing database volume detected (${volume_name})."
  warn "The PostgreSQL password is baked into this volume on first startup."
  warn "A new password will NOT match the one stored in the database."
  echo ""
  echo "  [1] Remove the volume (WARNING: destroys all data)"
  echo "  [2] Keep the volume (enter the existing password manually)"
  echo "  [3] Abort setup"
  echo ""

  while true; do
    read -rp "$(echo -e "${BOLD}Choose [1/2/3]${NC}: ")" choice
    case "$choice" in
      1)
        if prompt_yn "Are you sure? This will delete all database data" "n"; then
          warn "Stopping containers and removing volumes..."
          docker compose -f "$PROJECT_DIR/docker-compose.yml" down -v 2>/dev/null || true
          ok "Containers stopped and all volumes removed."
        else
          warn "Volume not removed. You may need to set the password manually."
        fi
        break
        ;;
      2)
        echo ""
        POSTGRES_PASSWORD_VAL=$(prompt_secret "Enter the existing POSTGRES_PASSWORD")
        ok "Using existing database password."
        break
        ;;
      3)
        info "Setup aborted."
        exit 0
        ;;
      *) warn "Please enter 1, 2, or 3." ;;
    esac
  done
  echo ""
}

check_running_containers() {
  if [ "$NON_INTERACTIVE" = true ]; then
    return
  fi

  if ! command -v docker >/dev/null 2>&1; then
    return
  fi

  local running
  running=$(docker compose -f "$PROJECT_DIR/docker-compose.yml" ps -q 2>/dev/null || true)
  if [ -n "$running" ]; then
    echo ""
    warn "Trackr containers are currently running."
    warn "You should stop them before applying new configuration."
    echo ""
    if prompt_yn "Stop containers now?" "y"; then
      docker compose -f "$PROJECT_DIR/docker-compose.yml" down 2>/dev/null || true
      ok "Containers stopped."
    else
      warn "Containers are still running. New configuration will take effect on next restart."
    fi
    echo ""
  fi
}

generate_secrets() {
  info "Generating secrets..."

  # Only generate if not already set (e.g., by check_existing_volumes)
  if [ -z "$POSTGRES_PASSWORD_VAL" ]; then
    POSTGRES_PASSWORD_VAL=$(openssl rand -hex 24)
  fi

  JWT_SECRET_VAL=$(openssl rand -hex 32)
  DASHBOARD_PASSWORD_VAL=$(openssl rand -hex 16)
  SECRET_KEY_BASE_VAL=$(openssl rand -base64 48)
  VAULT_ENC_KEY_VAL=$(openssl rand -hex 16)
  PG_META_CRYPTO_KEY_VAL=$(openssl rand -hex 16)
  LOGFLARE_PUBLIC_VAL=$(openssl rand -hex 24)
  LOGFLARE_PRIVATE_VAL=$(openssl rand -hex 24)
  S3_KEY_ID_VAL=$(openssl rand -hex 16)
  S3_KEY_SECRET_VAL=$(openssl rand -hex 32)
  POOLER_TENANT_ID_VAL=$(generate_uuid)

  ok "Secrets generated."
}

generate_jwts() {
  info "Generating JWT keys..."

  ANON_KEY_VAL=$(generate_jwt "anon" "$JWT_SECRET_VAL")
  SERVICE_ROLE_KEY_VAL=$(generate_jwt "service_role" "$JWT_SECRET_VAL")

  ok "JWT keys generated."
  echo ""
}

write_env_file() {
  info "Writing .env file..."

  cat > "$PROJECT_DIR/.env.tmp" << ENVEOF
############
# Secrets
# Auto-generated by setup.sh on $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# DO NOT commit this file to version control!
############

POSTGRES_PASSWORD=${POSTGRES_PASSWORD_VAL}
JWT_SECRET=${JWT_SECRET_VAL}
ANON_KEY=${ANON_KEY_VAL}
SERVICE_ROLE_KEY=${SERVICE_ROLE_KEY_VAL}
DASHBOARD_USERNAME=${DASHBOARD_USERNAME_VAL}
DASHBOARD_PASSWORD=${DASHBOARD_PASSWORD_VAL}
SECRET_KEY_BASE=${SECRET_KEY_BASE_VAL}
VAULT_ENC_KEY=${VAULT_ENC_KEY_VAL}
PG_META_CRYPTO_KEY=${PG_META_CRYPTO_KEY_VAL}
LOGFLARE_PUBLIC_ACCESS_TOKEN=${LOGFLARE_PUBLIC_VAL}
LOGFLARE_PRIVATE_ACCESS_TOKEN=${LOGFLARE_PRIVATE_VAL}
S3_PROTOCOL_ACCESS_KEY_ID=${S3_KEY_ID_VAL}
S3_PROTOCOL_ACCESS_KEY_SECRET=${S3_KEY_SECRET_VAL}


############
# URLs
############

SUPABASE_PUBLIC_URL=${SUPABASE_PUBLIC_URL_VAL}
API_EXTERNAL_URL=${API_EXTERNAL_URL_VAL}
SITE_URL=${SITE_URL_VAL}
ADDITIONAL_REDIRECT_URLS=${ADDITIONAL_REDIRECT_URLS_VAL}


############
# App (SvelteKit) -- baked into Docker image at build time
############

PUBLIC_SUPABASE_URL=${PUBLIC_SUPABASE_URL_VAL}
PUBLIC_SUPABASE_ANON_KEY=\${ANON_KEY}
APP_PORT=3000


############
# Database
############

POSTGRES_HOST=db
POSTGRES_DB=postgres
POSTGRES_PORT=5432


############
# Supavisor (connection pooler)
############

POOLER_PROXY_PORT_TRANSACTION=6543
POOLER_DEFAULT_POOL_SIZE=20
POOLER_MAX_CLIENT_CONN=100
POOLER_TENANT_ID=${POOLER_TENANT_ID_VAL}
POOLER_DB_POOL_SIZE=5


############
# Studio (Supabase dashboard)
############

STUDIO_DEFAULT_ORGANIZATION=Default Organization
STUDIO_DEFAULT_PROJECT=Default Project
OPENAI_API_KEY=


############
# Auth
############

JWT_EXPIRY=3600
DISABLE_SIGNUP=false
ENABLE_EMAIL_SIGNUP=true
ENABLE_EMAIL_AUTOCONFIRM=true
ENABLE_ANONYMOUS_USERS=false
ENABLE_PHONE_SIGNUP=false
ENABLE_PHONE_AUTOCONFIRM=false

MAILER_URLPATHS_CONFIRMATION=/auth/v1/verify
MAILER_URLPATHS_INVITE=/auth/v1/verify
MAILER_URLPATHS_RECOVERY=/auth/v1/verify
MAILER_URLPATHS_EMAIL_CHANGE=/auth/v1/verify

SMTP_ADMIN_EMAIL=${SMTP_ADMIN_EMAIL_VAL}
SMTP_HOST=${SMTP_HOST_VAL}
SMTP_PORT=${SMTP_PORT_VAL}
SMTP_USER=${SMTP_USER_VAL}
SMTP_PASS=${SMTP_PASS_VAL}
SMTP_SENDER_NAME=${SMTP_SENDER_NAME_VAL}


############
# Storage
############

GLOBAL_S3_BUCKET=stub
REGION=stub
STORAGE_TENANT_ID=stub


############
# Edge Functions
############

FUNCTIONS_VERIFY_JWT=false


############
# PostgREST
############

PGRST_DB_SCHEMAS=public,storage,graphql_public


############
# Kong (API gateway)
############

KONG_HTTP_PORT=8000
KONG_HTTPS_PORT=8443


############
# imgproxy
############

IMGPROXY_ENABLE_WEBP_DETECTION=true


############
# Logging
############

DOCKER_SOCKET_LOCATION=/var/run/docker.sock
ENVEOF

  mv "$PROJECT_DIR/.env.tmp" "$PROJECT_DIR/.env"
  ok ".env written."
}

write_caddyfile() {
  info "Writing Caddyfile..."

  if [ "$DEPLOY_MODE" = "production" ]; then
    cat > "$PROJECT_DIR/Caddyfile.tmp" << CADDYEOF
${DOMAIN} {
	reverse_proxy app:3000
}

${API_DOMAIN} {
	@preflight method OPTIONS
	handle @preflight {
		header Access-Control-Allow-Origin "https://${DOMAIN}"
		header Access-Control-Allow-Methods "GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS"
		header Access-Control-Allow-Headers "Accept, Authorization, Content-Type, apikey, x-client-info, x-supabase-api-version, Prefer, Range, Accept-Profile, Content-Profile, x-upsert"
		header Access-Control-Allow-Credentials "true"
		header Access-Control-Max-Age "3600"
		respond "" 204
	}

	handle {
		reverse_proxy kong:8000 {
			flush_interval -1
			header_down -Access-Control-Allow-Origin
			header_down -Access-Control-Allow-Credentials
			header_down -Access-Control-Allow-Methods
			header_down -Access-Control-Allow-Headers
			header_down -Access-Control-Expose-Headers
			header_down -Access-Control-Max-Age
		}
		header Access-Control-Allow-Origin "https://${DOMAIN}"
		header Access-Control-Allow-Credentials "true"
		header Access-Control-Expose-Headers "Content-Range, X-Supabase-Api-Version"
	}
}
CADDYEOF
  else
    # Local mode: single-origin, path-based routing through port 80
    cat > "$PROJECT_DIR/Caddyfile.tmp" << 'CADDYEOF'
:80 {
	handle /rest/* {
		reverse_proxy kong:8000
	}
	handle /auth/* {
		reverse_proxy kong:8000
	}
	handle /storage/* {
		reverse_proxy kong:8000
	}
	handle /realtime/* {
		reverse_proxy kong:8000 {
			flush_interval -1
		}
	}
	handle /graphql/* {
		reverse_proxy kong:8000
	}
	handle {
		reverse_proxy app:3000
	}
}
CADDYEOF
  fi

  mv "$PROJECT_DIR/Caddyfile.tmp" "$PROJECT_DIR/Caddyfile"
  ok "Caddyfile written."
  echo ""
}

print_summary() {
  echo ""
  echo -e "${BOLD}${GREEN}══════════════════════════════════════════${NC}"
  echo -e "${BOLD}${GREEN}  Setup Complete${NC}"
  echo -e "${BOLD}${GREEN}══════════════════════════════════════════${NC}"
  echo ""

  if [ "$DEPLOY_MODE" = "production" ]; then
    echo -e "  ${BOLD}Mode:${NC}      Production"
    echo -e "  ${BOLD}App URL:${NC}   https://${DOMAIN}"
    echo -e "  ${BOLD}API URL:${NC}   https://${API_DOMAIN}"
  else
    echo -e "  ${BOLD}Mode:${NC}      Local development"
    echo -e "  ${BOLD}App URL:${NC}   http://localhost"
    echo -e "  ${BOLD}API URL:${NC}   http://localhost (same origin)"
  fi

  echo ""
  echo -e "  ${BOLD}Dashboard credentials:${NC}"
  echo -e "    Username: ${DASHBOARD_USERNAME_VAL}"
  echo -e "    Password: ${DIM}${DASHBOARD_PASSWORD_VAL}${NC}"
  echo ""
  echo -e "${BOLD}Next steps:${NC}"
  echo ""
  echo "  1. Review the generated .env file"
  echo ""
  echo "  2. Start the services:"
  echo -e "     ${CYAN}docker compose up -d --build${NC}"
  echo ""
  echo "  3. Wait for all services to be healthy:"
  echo -e "     ${CYAN}docker compose ps${NC}"
  echo ""

  if [ "$DEPLOY_MODE" = "production" ]; then
    echo "  4. Make sure DNS records are configured:"
    echo -e "     ${DIM}A  @    → your-server-ip${NC}"
    echo -e "     ${DIM}A  api  → your-server-ip${NC}"
    echo ""
    echo "  5. Open https://${DOMAIN} and create your admin account"
  else
    echo "  4. Open http://localhost and create your admin account"
  fi

  echo ""
  echo -e "${YELLOW}Important:${NC}"
  echo "  - Save your dashboard password. It is stored only in .env"
  echo "  - If you change POSTGRES_PASSWORD later, sync it into the DB:"
  echo -e "    ${CYAN}bash scripts/setup.sh --update-db-password${NC}"
  echo "  - ANON_KEY and SERVICE_ROLE_KEY are signed with JWT_SECRET."
  echo "    Never change JWT_SECRET without re-running this script."
  if [ "$DEPLOY_MODE" = "production" ]; then
    echo "  - If you change ANON_KEY or PUBLIC_SUPABASE_URL, rebuild the app:"
    echo "    docker compose build app"
  fi
  echo ""
}

# ── Subcommand: update-db-password ────────────────────────────────────────────

update_db_password() {
  if [ ! -f "$PROJECT_DIR/.env" ]; then
    err "No .env file found. Run setup first."
    exit 1
  fi

  local new_pw
  new_pw=$(grep '^POSTGRES_PASSWORD=' "$PROJECT_DIR/.env" | cut -d= -f2)
  if [ -z "$new_pw" ]; then
    err "POSTGRES_PASSWORD not found in .env"
    exit 1
  fi

  info "Syncing POSTGRES_PASSWORD from .env into the running database..."

  local container="supabase-db"
  if ! docker inspect "$container" >/dev/null 2>&1; then
    err "Container '$container' is not running. Start the database first:"
    err "  docker compose up -d db"
    exit 1
  fi

  # supabase_admin is the actual superuser in Supabase's Postgres image.
  # Connect via 127.0.0.1 which uses trust auth (no password needed),
  # so this works regardless of what the current DB password is.
  local roles="authenticator pgbouncer supabase_auth_admin supabase_functions_admin supabase_storage_admin supabase_admin"
  for role in $roles; do
    if docker exec "$container" psql -h 127.0.0.1 -U supabase_admin -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname = '$role'" 2>/dev/null | grep -q 1; then
      docker exec "$container" psql -h 127.0.0.1 -U supabase_admin -d postgres -c "ALTER ROLE $role WITH PASSWORD '$new_pw';" >/dev/null
      ok "  Updated: $role"
    fi
  done

  echo ""
  ok "All database role passwords updated."
  info "Now restart the other services to pick up the new password:"
  echo -e "  ${CYAN}docker compose restart auth rest storage realtime supavisor${NC}"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
  # Parse args
  local cmd=""
  for arg in "$@"; do
    case "$arg" in
      --non-interactive) NON_INTERACTIVE=true ;;
      --update-db-password) cmd="update-db-password" ;;
      --help)
        echo "Usage: bash scripts/setup.sh [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --non-interactive      Run without prompts (configure via env vars)"
        echo "  --update-db-password   Sync POSTGRES_PASSWORD from .env into the running DB"
        echo "  --help                 Show this help"
        SETUP_COMPLETE=true
        exit 0
        ;;
      *) err "Unknown argument: $arg. Use --help for usage."; exit 1 ;;
    esac
  done

  preflight_checks

  if [ "$cmd" = "update-db-password" ]; then
    update_db_password
    SETUP_COMPLETE=true
    exit 0
  fi

  print_banner
  prompt_deployment_mode
  prompt_domain
  prompt_smtp
  prompt_dashboard_username
  check_existing_env
  check_running_containers
  check_existing_volumes
  generate_secrets
  generate_jwts
  write_env_file
  write_caddyfile

  SETUP_COMPLETE=true
  print_summary
}

main "$@"
