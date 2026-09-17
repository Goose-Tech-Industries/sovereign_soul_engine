# Sovereign Soul Engine — production release image.
#
# Adjust ARG BUILDER_IMAGE to your exact Elixir/OTP patch. Get it from:
#   elixir --version   (e.g. "Elixir 1.20.2 (compiled with Erlang/OTP 29)")
#   https://hub.docker.com/r/hexpm/elixir/tags

ARG BUILDER_IMAGE="hexpm/elixir:1.20.2-erlang-29.0.2-debian-bookworm-20250226"
ARG RUNNER_IMAGE="debian:bookworm-slim"

FROM ${BUILDER_IMAGE} AS build

# Install build tooling + Node (for esbuild/tailwind).
RUN apt-get update -y && apt-get install -y build-essential git curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

# Cache dependencies first (this layer only invalidates when mix.exs/mix.lock change).
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

RUN mix assets.deploy

RUN mix compile

# runtime.exs is read at boot, so it does not invalidate the compiled release.
COPY config/runtime.exs config/
RUN mix release

# ── Runtime stage ─────────────────────────────────────────────────────────────

FROM ${RUNNER_IMAGE}

RUN apt-get update -y \
    && apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

ENV MIX_ENV="prod"
ENV PHX_SERVER="true"

COPY --from=build --chown=nobody:root /app/_build/${MIX_ENV}/rel/sovereign_soul_engine ./

USER nobody

CMD ["bin/sovereign_soul_engine", "start"]
