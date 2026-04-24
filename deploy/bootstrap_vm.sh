#!/usr/bin/env bash
set -euo pipefail

APP_BASE_DIR="${APP_BASE_DIR:-/opt/ai-vector-demo}"
APP_DIR="${APP_DIR:-${APP_BASE_DIR}/app}"
VENV_DIR="${VENV_DIR:-${APP_DIR}/.venv}"
WALLET_DIR="${WALLET_DIR:-${APP_BASE_DIR}/wallet}"
WALLET_ZIP="${WALLET_ZIP:-${APP_BASE_DIR}/wallet.zip}"
BOOTSTRAP_ENV_FILE="${BOOTSTRAP_ENV_FILE:-${APP_BASE_DIR}/bootstrap.env}"
SYSTEMD_SERVICE_PATH="${SYSTEMD_SERVICE_PATH:-/etc/systemd/system/vector-demo.service}"
SERVICE_TEMPLATE_PATH="${SERVICE_TEMPLATE_PATH:-${APP_DIR}/deploy/vector-demo.service}"

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Environment variable ${name} is required." >&2
    exit 1
  fi
}

load_bootstrap_env() {
  if [[ -f "${BOOTSTRAP_ENV_FILE}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${BOOTSTRAP_ENV_FILE}"
    set +a
  fi
}

clone_or_update_repo() {
  require_env "API_REPO_URL"

  mkdir -p "${APP_BASE_DIR}"

  if [[ ! -d "${APP_DIR}/.git" ]]; then
    rm -rf "${APP_DIR}"
    git clone "${API_REPO_URL}" "${APP_DIR}"
  fi

  git -C "${APP_DIR}" fetch --all --tags
  if [[ -n "${API_REPO_REF:-}" ]]; then
    git -C "${APP_DIR}" checkout "${API_REPO_REF}"
  fi
}

setup_wallet() {
  if [[ -z "${ORACLE_WALLET_ZIP_BASE64:-}" ]]; then
    echo "Skipping wallet setup because ORACLE_WALLET_ZIP_BASE64 is empty."
    return
  fi

  mkdir -p "${WALLET_DIR}"
  printf '%s' "${ORACLE_WALLET_ZIP_BASE64}" | base64 -d > "${WALLET_ZIP}"
  unzip -o "${WALLET_ZIP}" -d "${WALLET_DIR}" >/dev/null
  chmod 600 "${WALLET_DIR}"/* || true
}

write_env_file() {
  require_env "ORACLE_PASSWORD"
  require_env "ORACLE_DSN"

  local wallet_location=""
  local wallet_password=""
  if [[ -n "${ORACLE_WALLET_ZIP_BASE64:-}" ]]; then
    wallet_location="${WALLET_DIR}"
    wallet_password="${ORACLE_WALLET_PASSWORD}"
  fi

  cat > "${APP_DIR}/.env" <<EOF
VECTOR_DB=oracle
PDF_PATH=${APP_DIR}/${PDF_FILENAME}
OLLAMA_BASE_URL=http://127.0.0.1:11434
EMBED_MODEL=${EMBED_MODEL}
CHAT_MODEL=${CHAT_MODEL}
ORACLE_USER=${ORACLE_USER}
ORACLE_PASSWORD=${ORACLE_PASSWORD}
ORACLE_DSN=${ORACLE_DSN}
ORACLE_WALLET_LOCATION=${wallet_location}
ORACLE_WALLET_PASSWORD=${wallet_password}
DATABASE_URL=
CHUNK_SIZE=${CHUNK_SIZE}
CHUNK_OVERLAP=${CHUNK_OVERLAP}
EOF

  chmod 600 "${APP_DIR}/.env"
}

install_python_deps() {
  python3 -m venv "${VENV_DIR}"
  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
  python -m pip install --upgrade pip
  python -m pip install -r "${APP_DIR}/requirements.txt"
}

init_schema() {
  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
  python "${APP_DIR}/scripts/init_oracle.py"
}

install_systemd_service() {
  sed \
    -e "s|__APP_DIR__|${APP_DIR}|g" \
    -e "s|__APP_USER__|${APP_USER}|g" \
    "${SERVICE_TEMPLATE_PATH}" > "${SYSTEMD_SERVICE_PATH}"

  systemctl daemon-reload
  systemctl enable vector-demo.service
  systemctl restart vector-demo.service
}

wait_for_api() {
  local url="http://127.0.0.1:${APP_PORT}/health"
  for _ in $(seq 1 30); do
    if curl -fsS "${url}" >/dev/null; then
      return 0
    fi
    sleep 2
  done

  echo "API did not become ready in time." >&2
  return 1
}

ingest_pdf() {
  if [[ "${AUTO_INGEST_ON_BOOT}" != "true" ]]; then
    return
  fi

  curl -fsS -X POST "http://127.0.0.1:${APP_PORT}/ingest" >/dev/null
}

main() {
  load_bootstrap_env

  : "${APP_USER:=ubuntu}"
  : "${APP_PORT:=8000}"
  : "${ORACLE_USER:=admin}"
  : "${ORACLE_WALLET_PASSWORD:=}"
  : "${EMBED_MODEL:=nomic-embed-text}"
  : "${CHAT_MODEL:=llama3.2}"
  : "${CHUNK_SIZE:=1200}"
  : "${CHUNK_OVERLAP:=200}"
  : "${PDF_FILENAME:=move-oracle-cloud-using-zero-downtime-migration.pdf}"
  : "${AUTO_INGEST_ON_BOOT:=true}"

  clone_or_update_repo
  setup_wallet
  write_env_file
  install_python_deps
  init_schema
  install_systemd_service
  wait_for_api
  ingest_pdf
}

main "$@"
