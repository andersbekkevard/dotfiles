# Helper function to run llama-server with optimized M4 Pro flags
_llama_serve_model() {
    local model_path="$1"
    local port="$2"
    local context="${3:-32768}" # Default to 32k if not provided
    shift 3

    if ! command -v llama-server &> /dev/null; then
        echo "✗ llama-server not found"
        echo "Install it with: brew install llama.cpp"
        return 1
    fi

    if [[ ! -f "$model_path" ]]; then
        echo "✗ Model blob not found at: $model_path"
        return 1
    fi

    echo "🚀 Starting optimized llama-server on port $port (Context: $context)..."
    echo "📦 Model: $(basename $model_path)"
    
    # M4 Pro Optimized Flags:
    # -np 1: Single slot for max speed
    # -fa on: Force Flash Attention
    # --mlock: Lock in RAM
    llama-server \
        -m "$model_path" \
        --port "$port" \
        -c "$context" \
        -np 1 \
        -fa on \
        --mlock \
        "$@"
}

# Host the Aprilia model
llama-host-aprilia() {
    local model="${LLAMA_APRILIA_MODEL_PATH:-}"
    if [[ -z "$model" ]]; then
        echo "Set LLAMA_APRILIA_MODEL_PATH in ~/.zshrc.local"
        return 1
    fi
    _llama_serve_model "$model" 8080 32768 "$@"
}

# Host the GLM 4.7 Flash model
llama-host-glm() {
    local model="${LLAMA_GLM_MODEL_PATH:-}"
    if [[ -z "$model" ]]; then
        echo "Set LLAMA_GLM_MODEL_PATH in ~/.zshrc.local"
        return 1
    fi
    local log_file="/tmp/llama-glm-$(date +%Y%m%d_%H%M%S).log"

    echo "Logging to: $log_file"

    _llama_serve_model "$model" 8080 32768 \
        --alias glm-4.7-flash \
        --jinja \
        --verbose \
        --temp 1.0 \
        --top-p 0.95 \
        --min-p 0.01 \
        --sleep-idle-seconds 300 \
        --host 127.0.0.1 \
        "$@" > "$log_file" 2>&1 &

    echo "Server PID: $!"
    echo "Tail logs: tail -f $log_file"
}

# Host the GPT OS (Oss) model using a dedicated Ollama server instance
# (Required because 'gptoss' architecture is Ollama-specific)
llama-host-oss() {
    local port=8081
    echo "🚀 Starting dedicated Ollama server on port $port..."
    echo "📦 Model: gpt-oss:20b"
    echo "🔗 OpenAI API: http://localhost:$port/v1"
    echo "🔗 Ollama API: http://localhost:$port/api"
    echo "------------------------------------------------"
    
    # We set OLLAMA_HOST to a custom port to avoid conflicting 
    # with your main Ollama app/service (default 11434).
    OLLAMA_HOST="127.0.0.1:$port" ollama serve
}
