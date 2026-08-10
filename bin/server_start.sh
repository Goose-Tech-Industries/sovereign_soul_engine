#!/bin/bash
# Load ASDF Elixir and Erlang paths
. /root/.asdf/asdf.sh
cd /root/sovereign_soul_engine
export DEEPSEEK_API_KEY="***REDACTED-DEEPSEEK-KEY***"
PORT=4002 MIX_ENV=dev mix phx.server
