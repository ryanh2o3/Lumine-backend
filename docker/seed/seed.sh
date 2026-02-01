#!/bin/bash
set -euo pipefail

docker compose exec -T db psql -U picshare -d picshare < docker/seed/seed.sql
