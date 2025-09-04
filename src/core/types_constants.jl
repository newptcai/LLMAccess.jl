"""
    AbstractLLM

An abstract type representing any Large Language Model (LLM).
"""
abstract type AbstractLLM end

"""
    OpenAICompatibleLLM

An abstract type for LLMs that are compatible with OpenAI's API.
"""
abstract type OpenAICompatibleLLM <: AbstractLLM end

"""
    OpenAILLM

Concrete type for OpenAI's LLM.
"""
struct OpenAILLM <: OpenAICompatibleLLM end

"""
    OpenRouterLLM

Concrete type for OpenRouter's LLM.
"""
struct OpenRouterLLM <: OpenAICompatibleLLM end

"""
    GroqLLM

Concrete type for Groq's LLM.
"""
struct GroqLLM <: OpenAICompatibleLLM end

"""
    AnthropicLLM

Concrete type for Anthropic's LLM (e.g., Claude).
"""
struct AnthropicLLM <: AbstractLLM end

"""
    GoogleLLM

Concrete type for Google's LLM (e.g., PaLM/Gemini).
"""
struct GoogleLLM <: AbstractLLM end

"""
    OllamaLLM

Concrete type for Ollama's LLM.
"""
struct OllamaLLM <: AbstractLLM end

"""
    MistralLLM

Concrete type for Mistral's LLM.
"""
struct MistralLLM <: AbstractLLM end

"""
    DeepSeekLLM

Concrete type for DeepSeek's LLM (OpenAI-compatible API).
"""
struct DeepSeekLLM <: OpenAICompatibleLLM end

# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────

const DEFAULT_MODELS = Dict(
    "openai"      => "gpt-4o-mini",
    "openrouter"  => "amazon/nova-micro-v1",
    "anthropic"   => "claude-3-5-haiku-latest",
    "google"      => "gemini-2.0-flash",
    "ollama"      => "gemma3:4b",
    "mistral"     => "mistral-small-latest",
    "groq"        => "llama-3.3-70b-versatile",
    "deepseek"    => "deepseek-chat",
)

const DEFAULT_TEMPERATURE = 1.0
const DEFAULT_LLM = "google"

const MODEL_ALIASES = Dict(
    # Mistral
    "small" => "mistral-small-latest",
    "medium" => "mistral-medium-latest",
    "large" => "mistral-large-latest",
    "ocr" => "mistral-ocr-latest",
    "magistral" => "magistral-medium-latest",

    # Google Gemini
    "gemini" => "gemini-2.5-pro",
    "flash"  => "gemini-2.5-flash",

    # Anthropic Claude
    "sonnet" => "claude-sonnet-4-20250514",
    "opus"   => "claude-opus-4-1-20250805",
    "haiku"  => "claude-3-5-haiku-latest",

    # DeepSeek
    "r1" => "deepseek-reasoner",
    "v3" => "deepseek-chat",

    # OpenAI GPT
    "4o"      => "gpt-4o",
    "4o-mini" => "gpt-4o-mini",
    "3.5"     => "gpt-3.5-turbo",
    "5"       => "gpt-5",
    "5-mini"  => "gpt-5-mini",
)
