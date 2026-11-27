FROM python:3.11-slim

COPY --from=ghcr.io/astral-sh/uv:0.13.10 /uv /uvx /bin/

# Install Python environment globally instead of a virtual environment
ENV UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT="/usr/local" \
    UV_CACHE_DIR="/tmp/uv-cache" \
    HOME="/tmp" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN groupadd --system app \
    && useradd --system --uid 10001 --gid app --create-home --shell /usr/sbin/nologin app

WORKDIR /app

COPY pyproject.toml uv.lock ./

RUN uv sync --frozen --no-dev

# Deliberately not --chown'd to the app user: it stays root-owned so even a
# fully compromised app process can't rewrite its own source on disk if the
# read_only filesystem guard in compose.yml is ever disabled or bypassed.
COPY . .

EXPOSE 8000

USER 10001:10001

CMD ["fastapi", "run", "main.py", "--host", "0.0.0.0", "--port", "8000"]