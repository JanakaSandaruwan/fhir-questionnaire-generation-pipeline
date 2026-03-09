#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Entrypoint: starts all 5 services inside a single container
# Only port 6080 (policy-preprocessor) is exposed externally.
# ─────────────────────────────────────────────────────────────

set -e

echo "=== DEBUG: entrypoint running as $(id) ==="
echo "=== DEBUG: entrypoint.sh owner: $(ls -la /app/entrypoint.sh) ==="

PIDS=()

cleanup() {
    echo ""
    echo "[entrypoint] Stopping all services..."
    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
        fi
    done
    wait 2>/dev/null
    echo "[entrypoint] All services stopped."
    exit 0
}

trap cleanup SIGINT SIGTERM

echo "========================================"
echo " Starting FHIR Questionnaire Pipeline"
echo "========================================"

# ── 1. PDF to Markdown Service (Python / FastAPI) ──
echo "[1/5] Starting PDF to MD Service on port 8000..."
cd /app/services/pdf-to-md
python main.py &
PIDS+=($!)

# ── 2. Policy Preprocessor (Ballerina JAR) ──
echo "[2/5] Starting Policy Preprocessor on port 6080..."
cd /app/services/policy-preprocessor
SERVICE_PORT=6080 java -jar app.jar &
PIDS+=($!)

# ── 3. Questionnaire Generator Agent (Ballerina JAR) ──
echo "[3/5] Starting Questionnaire Generator Agent on port 7082..."
cd /app/services/generator-agent
SERVICE_PORT=7082 java -jar app.jar &
PIDS+=($!)

# ── 4. Questionnaire Reviewer Agent (Ballerina JAR) ──
echo "[4/5] Starting Questionnaire Reviewer Agent on port 7081..."
cd /app/services/reviewer-agent
SERVICE_PORT=7081 java -jar app.jar &
PIDS+=($!)

# ── 5. Questionnaire Orchestration (Ballerina JAR) ──
echo "[5/5] Starting Questionnaire Orchestration on port 6060..."
cd /app/services/orchestration
SERVICE_PORT=6060 java -jar app.jar &
PIDS+=($!)

echo ""
echo "========================================"
echo " All 5 services started."
echo " Exposed port: 6080 (Policy Preprocessor)"
echo "========================================"

# Wait for any child to exit; if one dies the container stops
wait -n
EXIT_CODE=$?
echo "[entrypoint] A service exited with code $EXIT_CODE — shutting down."
cleanup
