#!/usr/bin/env bash
# Cargado por los demas scripts de sispro-bug-agent. No se ejecuta solo.
set -euo pipefail

sispro_load_config() {
  local config_file="config/sispro.env"

  if [ ! -f "$config_file" ]; then
    echo "Error: no existe $config_file en el repo actual." >&2
    echo "Copia config/sispro.env.example (del plugin) a $config_file y llenalo." >&2
    exit 1
  fi

  set -a
  # shellcheck disable=SC1090
  source "$config_file"
  set +a

  local missing=()
  [ -z "${SISPRO_BASE_URL:-}" ] && missing+=("SISPRO_BASE_URL")
  [ -z "${SISPRO_API_KEY:-}" ] && missing+=("SISPRO_API_KEY")
  [ -z "${SISPRO_PROJECT_ID:-}" ] && missing+=("SISPRO_PROJECT_ID")

  if [ "${#missing[@]}" -gt 0 ]; then
    echo "Error: faltan variables en $config_file: ${missing[*]}" >&2
    exit 1
  fi
}
