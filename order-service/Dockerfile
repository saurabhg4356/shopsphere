FROM python:3.11-slim AS builder

WORKDIR /app
RUN pip install --upgrade pip setuptools wheel
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --prefix=/install --no-cache-dir -r requirements.txt


FROM python:3.11-slim AS runtime

WORKDIR /app

COPY --from=builder /install /usr/local
COPY . .

RUN adduser --disabled-password --no-create-home --gecos "" appuser
RUN mkdir -p /app/data
RUN chown -R appuser:appuser /app
USER root

EXPOSE 8003

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8003/health')"

CMD ["sh", "-c", "chown -R appuser:appuser /app/data && su appuser -s /bin/sh -c 'uvicorn main:app --host 0.0.0.0 --port 8003 --workers 1'"]
