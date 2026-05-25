# Stage 1 — build with uv
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim@sha256:e5b65587bce7de595f299855d7385fe7fca39b8a74baa261ba1b7147afa78e58 AS builder

WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev
COPY . .

# Stage 2 — runtime
FROM cgr.dev/chainguard/python@sha256:f960fea6d1fb1c0ad626558d9db323ff84468927ac37cd7fa889b512ba0dc1c9

WORKDIR /app

COPY --from=builder /app/.venv /app/.venv
COPY --from=builder /app/main.py .

ENV PATH="/app/.venv/bin:$PATH"

ENTRYPOINT ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
