#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_DIR="$ROOT_DIR/apps/web"

"$ROOT_DIR/scripts/dev-deploy.sh"

cd "$WEB_DIR"
npm run dev