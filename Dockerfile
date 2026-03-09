# ═══════════════════════════════════════════════════════════════
#  FHIR Questionnaire Generation Pipeline — Single Container
#  Only the Policy Preprocessor (port 6080) is exposed.
# ═══════════════════════════════════════════════════════════════

# ── Stage 1: Build all four Ballerina services ─────────────────
FROM ballerina/ballerina:2201.12.10 AS bal-build
USER root

# Policy Preprocessor
WORKDIR /build/policy-preprocessor
COPY data_ingestion_pipeline/policy_preprocessor/ .
RUN rm -f Dependencies.toml && bal build

# Questionnaire Generator Agent
WORKDIR /build/generator-agent
COPY fhir_questionnaire_generation/fhir_questionnaire_agents/fhir_questionnaire_generator_agent/ .
RUN rm -f Dependencies.toml && bal build

# Questionnaire Reviewer Agent
WORKDIR /build/reviewer-agent
COPY fhir_questionnaire_generation/fhir_questionnaire_agents/fhir_questionnaire_reviewer_agent/ .
RUN rm -f Dependencies.toml && bal build

# Questionnaire Orchestration
WORKDIR /build/orchestration
COPY fhir_questionnaire_generation/fhir_questionnaire_orchestration/ .
RUN rm -f Dependencies.toml && bal build


# ── Stage 2: Runtime ──────────────────────────────────────────
FROM python:3.12-slim

# Install Java 21 (Eclipse Temurin) + curl for health checks
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        wget gnupg ca-certificates curl \
        libgl1 libglib2.0-0 && \
    # Add Eclipse Temurin APT repository
    mkdir -p /etc/apt/keyrings && \
    wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public \
        | gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] \
        https://packages.adoptium.net/artifactory/deb \
        $(. /etc/os-release && echo $VERSION_CODENAME) main" \
        > /etc/apt/sources.list.d/adoptium.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends temurin-21-jre && \
    # Clean up
    apt-get purge -y wget gnupg && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ── Python dependencies (cached layer) ────────────────────────
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
COPY data_ingestion_pipeline/pdf_to_md_service/requirements.txt /tmp/requirements.txt
RUN uv pip install --system --no-cache -r /tmp/requirements.txt && rm /tmp/requirements.txt

# ── Copy Python service ───────────────────────────────────────
COPY data_ingestion_pipeline/pdf_to_md_service/ /app/services/pdf-to-md/

# ── Copy Ballerina JARs + Config.toml ─────────────────────────
COPY --from=bal-build /build/policy-preprocessor/target/bin/policy_document_chunker.jar \
     /app/services/policy-preprocessor/app.jar
COPY data_ingestion_pipeline/policy_preprocessor/Config.toml \
     /app/services/policy-preprocessor/Config.toml

COPY --from=bal-build /build/generator-agent/target/bin/fhir_questionnaire_generator.jar \
     /app/services/generator-agent/app.jar
# COPY fhir_questionnaire_generation/fhir_questionnaire_agents/fhir_questionnaire_generator_agent/Config.toml \
#      /app/services/generator-agent/Config.toml

COPY --from=bal-build /build/reviewer-agent/target/bin/fhir_questionnaire_reviewer.jar \
     /app/services/reviewer-agent/app.jar
# COPY fhir_questionnaire_generation/fhir_questionnaire_agents/fhir_questionnaire_reviewer_agent/Config.toml \
#      /app/services/reviewer-agent/Config.toml

COPY --from=bal-build /build/orchestration/target/bin/fhir_questionnaire_generation.jar \
     /app/services/orchestration/app.jar
COPY fhir_questionnaire_generation/fhir_questionnaire_orchestration/Config.toml \
     /app/services/orchestration/Config.toml

# ── Shared data directory ─────────────────────────────────────
RUN mkdir -p /app/data/pdf /app/data/md /app/data/chunks

# ── Create non-root user ──────────────────────────────────────
RUN addgroup --gid 10014 appgroup && \
    adduser --uid 10014 --gid 10014 --disabled-password --gecos "" appuser && \
    chown -R 10014:10014 /app

# ── Entrypoint ────────────────────────────────────────────────
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# ── Default environment (all services talk via localhost) ──────
ENV STORAGE_TYPE=local \
    LOCAL_STORAGE_PATH=/app/data \
    LOCAL_DIR=/app/data/ \
    USE_FTP=false \
    NOTIFICATION_CALLBACK_URL=http://localhost:6080/notification \
    PDF_TO_MD_SERVICE_URL=http://localhost:8000 \
    FHIR_QUESTIONNAIRE_SERVICE_URL=http://localhost:6060/generate \
    FHIR_SERVER_URL=http://localhost:9090/fhir/r4 \
    POLICY_FLOW_ORCHESTRATOR=http://localhost:6080 \
    FHIR_QUESTIONNAIRE_GENERATOR_URL=http://localhost:7082/QuestionnaireGenerator \
    FHIR_REVIEWER_URL=http://localhost:7081/Reviewer

# Only expose the Policy Preprocessor to the outside world
EXPOSE 6080

USER 10014

ENTRYPOINT ["/app/entrypoint.sh"]
