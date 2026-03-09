# Minimal Dockerfile to test entrypoint.sh issue
FROM python:3.12-slim

WORKDIR /app

RUN mkdir -p /app/data/pdf /app/data/md /app/data/chunks

# Create non-root user
RUN addgroup --gid 10014 appgroup && \
    adduser --uid 10014 --gid 10014 --disabled-password --gecos "" appuser && \
    chown -R 10014:10014 /app

# Entrypoint (copy AFTER chown — file will be owned by root)
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Debug: verify ownership
RUN echo "=== entrypoint.sh ===" && \
    ls -la /app/entrypoint.sh && \
    echo "=== whoami ===" && \
    whoami && \
    echo "==============="

EXPOSE 6080

USER 10014

ENTRYPOINT ["/app/entrypoint.sh"]
