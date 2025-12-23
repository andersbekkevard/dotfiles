# Helper function to run llama-server with optimized M4 Pro flags
_llama_serve_model() {
    local model_path="$1"
    local port="$2"
    shift 2

    if ! command -v llama-server &> /dev/null; then
        echo "✗ llama-server not found"
        echo "Install it with: brew install llama.cpp"
        return 1
    fi

    if [[ ! -f "$model_path" ]]; then
        echo "✗ Model blob not found at: $model_path"
        return 1
    fi

    echo "🚀 Starting optimized llama-server on port $port..."
    echo "📦 Model: $(basename $model_path)"
    
    # M4 Pro Optimized Flags:
    # -c 32768: Sets context to 32k
    # -np 1: Single slot for max speed
    # -fa on: Force Flash Attention
    # --mlock: Lock in RAM
    llama-server \
        -m "$model_path" \
        --port "$port" \
        -c 32768 \
        -np 1 \
        -fa on \
        --mlock \
        "$@"
}

# Host the Aprilia model
llama-host-aprilia() {
    local model="/Users/andersbekkevard/.ollama/models/blobs/sha256-00bea8063ebdbfab1537572106912c9849dee347eb245a72eaac6f9ea3af5f69"
    _llama_serve_model "$model" 8080 "$@"
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
