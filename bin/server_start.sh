#!/bin/bash
# Load ASDF Elixir and Erlang paths
. /root/.asdf/asdf.sh
cd /root/sovereign_soul_engine
# Set DEEPSEEK_API_KEY in your environment or .env before running.
# Example: export DEEPSEEK_API_KEY="sk-..."
PORT=4002 MIX_ENV=dev mix phx.server
