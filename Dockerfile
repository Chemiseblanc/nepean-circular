# Find eligible builder and runner images at
# https://hub.docker.com/r/hexpm/elixir/tags
#
# This file is based on the Phoenix 1.8 release Dockerfile.
# Adjusted for SQLite + pythonx (Python 3.13 with pypdf/Pillow).

ARG ELIXIR_VERSION=1.18.3
ARG OTP_VERSION=27.2.1
ARG DEBIAN_VERSION=bookworm-20260202-slim
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

# ===========================================================================
# Stage 1 — Build
# ===========================================================================
FROM ${BUILDER_IMAGE} AS builder

# Install build-time deps (git for heroicons, python3 + venv for pythonx)
RUN apt-get update -y && \
    apt-get install -y build-essential git python3 python3-venv curl && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

# Set build ENV
ENV MIX_ENV="prod"

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy compile-time config and runtime config
# runtime.exs must be present before `mix release` so it is included in the release
COPY config/config.exs config/${MIX_ENV}.exs config/runtime.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

# Compile the release
RUN mix compile

# Build assets (tailwind + esbuild + digest)
RUN mix assets.deploy

# Generate the release
# If you haven't run `mix phx.gen.release` yet, do so first to get
# the rel/ directory with env.sh.eex and a bin/server script.
COPY rel rel
RUN mix release

# ===========================================================================
# Stage 2 — Runner (minimal production image)
# ===========================================================================
FROM ${RUNNER_IMAGE}

# Install runtime deps:
# - libstdc++6: for Erlang NIFs
# - openssl: for crypto
# - libncurses5: for Erlang remote_console
# - locales: for UTF-8 locale
# - python3 + python3-venv + python3-pip: pythonx runtime (pypdf, Pillow)
# - libimage libraries: Pillow dependencies
RUN apt-get update -y && \
    apt-get install -y \
      libstdc++6 openssl libncurses5 locales ca-certificates \
      python3 python3-venv python3-pip \
      libjpeg62-turbo libpng16-16 zlib1g libfreetype6 \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"

WORKDIR /app

# Create a non-root user to run the app
RUN groupadd --system --gid 999 app && useradd --system --uid 999 --gid app --home /app app

# Create the SQLite data directory (mount a volume here)
RUN mkdir -p /data && chown app:app /data

# Copy the release from the build stage
COPY --from=builder --chown=app:app /app/_build/prod/rel/nepean_circular ./

USER app

# Default env vars — override at runtime as needed
ENV PHX_SERVER="true"
ENV DATABASE_PATH="/data/nepean_circular.db"
ENV PORT="4000"

EXPOSE 4000

CMD ["/app/bin/server"]
