#!/bin/bash
# Load ASDF Elixir and Erlang paths
. /root/.asdf/asdf.sh
cd /root/sovereign_soul_engine
# DEEPSEEK_API_KEY must already be set in the environment (e.g. via a local,
# gitignored .env sourced by your shell profile) — never hardcode it here again.
: "${DEEPSEEK_API_KEY:?DEEPSEEK_API_KEY is not set. Export it in your shell/.env before running this script.}"

PORT=4002 MIX_ENV=dev mix phx.server
