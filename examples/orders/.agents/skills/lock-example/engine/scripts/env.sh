# Shared settings, sourced by the other scripts. Override any value in <project>/decision-lock.env or the environment.
# DL_ROOT is the project being tested (tests/, db/, handoff/ live under it). Default: the parent of scripts/.
DL_ROOT=${DL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
export DL_ROOT
[ -f "$DL_ROOT/decision-lock.env" ] && . "$DL_ROOT/decision-lock.env"
IMAGE=${IMAGE:-decision-lock-pg:16}                     # Postgres image that has pgTAP and pg_prove
CONTAINER=${CONTAINER:-decision-lock-$(basename "$DL_ROOT")}
DBNAME=${DBNAME:-app}
SCHEMA_DIR=${SCHEMA_DIR:-db}                            # *.sql files here are applied in name order to build the fresh DB
DOCKER=${DOCKER:-docker}
# Git Bash on Windows rewrites /work style paths in docker arguments unless this is set (lesson 7).
export MSYS_NO_PATHCONV=1
