FROM debian:bookworm-slim

LABEL maintainer="Phillip Bailey"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get dist-upgrade -y && apt-get install -y --no-install-recommends \
    python3-dev build-essential gcc \
    nginx supervisor curl ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Create non-root user and add to www-data group
RUN groupadd -r appuser && useradd -r -g appuser appuser \
    && usermod -a -G www-data appuser

COPY nginx/flask.conf /etc/nginx/sites-available/
COPY supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY app /var/www/app

RUN mkdir -p /var/log/nginx/app /var/log/supervisor \
    && rm /etc/nginx/sites-enabled/default \
    && ln -s /etc/nginx/sites-available/flask.conf /etc/nginx/sites-enabled/flask.conf \
    && echo "daemon off;" >> /etc/nginx/nginx.conf \
    && sed -i 's|pid /run/nginx.pid;|pid /var/run/nginx.pid;|' /etc/nginx/nginx.conf \
    && uv pip install --system --no-cache --break-system-packages -r /var/www/app/requirements.txt \
    && chown -R appuser:appuser /var/www/app \
    && chown -R appuser:appuser /var/log \
    && chown -R appuser:appuser /var/run

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

# Run as non-root user for security (nginx can now bind to non-privileged port 8080)
USER appuser
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
