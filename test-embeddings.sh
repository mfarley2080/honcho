#!/usr/bin/env bash
# Benchmark nomic-embed-text vs mxbai-embed-large on this CPU.
# Run on TrueNAS with Ollama installed.
# Usage: bash test-embeddings.sh [ollama-host]
set -euo pipefail

HOST=${1:-http://localhost:11434}
RUNS=20

# Realistic honcho message samples — mix of short and paragraph-length
MESSAGES=(
  "Hey, can you help me debug this Python script? It's throwing a KeyError on line 47."
  "I've been thinking about the architecture for the new service. I think we should use event sourcing because it gives us a complete audit trail and makes it easier to rebuild state. The main downside is the added complexity around projections."
  "Done with the meeting. They approved the budget for Q3."
  "I keep forgetting to take my medication in the morning. It's been a problem for about three months now. I've tried setting alarms but I snooze them."
  "The deploy failed again. Same error as last week — the health check times out before the app finishes loading the ML model. We need to either increase the grace period or lazy-load the model."
  "Thanks!"
  "Can you summarize what we discussed about the pricing model? I want to send a recap to the team before EOD."
  "I'm working on a side project — a personal finance app that remembers your spending habits and financial goals. Three friends are already using it and asking when they can pay me."
)

benchmark_model() {
    local model=$1
    echo ""
    echo "=== ${model} ==="

    echo -n "Pulling model... "
    curl -s "${HOST}/api/pull" -d "{\"name\":\"${model}\"}" \
        | python3 -c "import sys,json; [print('done') if 'success' in l else None for l in (json.loads(x) for x in sys.stdin if x.strip())]" 2>/dev/null \
        || echo "done (already present or pull complete)"

    echo "Running ${RUNS} embeddings across ${#MESSAGES[@]} message samples..."

    local total_ms=0
    local count=0
    local times=()

    for i in $(seq 1 $RUNS); do
        local msg="${MESSAGES[$((($i - 1) % ${#MESSAGES[@]}))]}"
        local escaped
        escaped=$(echo "$msg" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))")

        local start
        start=$(python3 -c "import time; print(int(time.time()*1000))")

        curl -s "${HOST}/api/embeddings" \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"${model}\",\"prompt\":${escaped}}" \
            > /dev/null

        local end
        end=$(python3 -c "import time; print(int(time.time()*1000))")

        local elapsed=$(( end - start ))
        times+=($elapsed)
        total_ms=$(( total_ms + elapsed ))
        count=$(( count + 1 ))

        printf "  run %2d: %dms\n" "$i" "$elapsed"
    done

    local avg=$(( total_ms / count ))
    local min
    min=$(printf '%s\n' "${times[@]}" | sort -n | head -1)
    local max
    max=$(printf '%s\n' "${times[@]}" | sort -n | tail -1)

    echo ""
    echo "  avg: ${avg}ms | min: ${min}ms | max: ${max}ms"
    echo "  throughput: ~$(( 1000 / avg )) embeddings/sec"
    echo "  deriver capacity: ~$(( 1000 / avg * 60 )) messages/min"
}

echo "Embedding benchmark — ${HOST}"
echo "Each run embeds one message; ${RUNS} runs per model."

benchmark_model "nomic-embed-text"
benchmark_model "mxbai-embed-large"

echo ""
echo "=== Summary ==="
echo "For honcho's deriver (async background processing), either model"
echo "is adequate for personal/small-team use. The question is whether"
echo "mxbai throughput meets your expected message ingestion rate."
