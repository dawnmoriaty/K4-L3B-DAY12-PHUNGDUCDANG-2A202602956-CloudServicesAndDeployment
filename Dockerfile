# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (Production-ready)
# ═══════════════════════════════════════════════════════════════════

# Stage 1: Builder
FROM python:3.11-slim AS builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --default-timeout=100 --prefix=/install -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim

WORKDIR /app

# Copy các thư viện đã cài từ stage builder sang runtime
COPY --from=builder /install /usr/local

# Tạo non-root user để tăng tính bảo mật
RUN useradd --create-home --uid 10001 appuser
USER appuser

# Copy mã nguồn sau khi đã cài dependencies để tận dụng Docker layer cache
COPY . .

EXPOSE 8000

# Healthcheck probe gọi endpoint /health
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import os, urllib.request; port = os.environ.get('PORT', '8000'); urllib.request.urlopen(f'http://127.0.0.1:{port}/health').read()" || exit 1

# Bind Uvicorn vào 0.0.0.0 và đọc cổng từ biến môi trường PORT (mặc định 8000)
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
