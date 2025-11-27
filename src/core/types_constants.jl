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
struct OpenRouterLLM <: AbstractLLM end

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
    AbstractOllamaLLM

Common supertype for Ollama providers (local daemon and hosted cloud).
"""
abstract type AbstractOllamaLLM <: AbstractLLM end

"""
    OllamaLLM

Concrete type for Ollama's local LLM.
"""
struct OllamaLLM <: AbstractOllamaLLM end

"""
    OllamaCloudLLM

Concrete type for Ollama Cloud's hosted LLM.
"""
struct OllamaCloudLLM <: AbstractOllamaLLM end

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
    # Prefer economical, widely-available defaults per provider
    "openai"      => "gpt-5-mini",
    "openrouter"  => "amazon/nova-micro-v1",
    "anthropic"   => "claude-haiku-4-5-20251001",
    "google"      => "gemini-2.5-flash",
    "ollama"      => "gemma3:4b",
    "ollama_cloud" => "gpt-oss:120b",
    "mistral"     => "mistral-small-latest",
    "deepseek"    => "deepseek-chat",
)

const DEFAULT_TEMPERATURE = 1.0
const DEFAULT_LLM = "google"

"""
    PROVIDER_ALIASES

Short aliases mapping to canonical provider names accepted by `--llm`.

Examples:
  - "g"  => "google"
  - "oa" => "openai"
  - "an" => "anthropic"
"""
const PROVIDER_ALIASES = Dict(
    # OpenAI
    "o"  => "openai",

    # Anthropic
    "a"  => "anthropic",

    # Google
    "g"  => "google",

    # Mistral
    "m"  => "mistral",

    # Ollama
    "ol" => "ollama",

    # Ollama Cloud
    "oc" => "ollama_cloud",
    "ollama-cloud" => "ollama_cloud",
    "ollamacloud" => "ollama_cloud",

    # OpenRouter
    "or" => "openrouter",

    # DeepSeek
    "d"  => "deepseek",
)

const MODEL_ALIASES = Dict(
    # Mistral
    # 1–2 letter shorthands
    "m" => "mistral-medium-latest",   # Mistral Medium
    "ms" => "mistral-small-latest",
    "ml" => "mistral-large-latest",
    "mo" => "mistral-ocr-latest",

    "small" => "mistral-small-latest",
    "medium" => "mistral-medium-latest",
    "large" => "mistral-large-latest",
    "ocr" => "mistral-ocr-latest",
    "magistral" => "magistral-medium-latest",
    # Additional Mistral families
    "codestral" => "codestral-latest",
    "codestral-2508" => "codestral-2508",
    "pix" => "pixtral-12b-latest",
    "pix-large" => "pixtral-large-latest",
    "saba" => "mistral-saba-latest",
    "ministral-3b" => "ministral-3b-latest",
    "ministral-8b" => "ministral-8b-latest",
    "devstral-s" => "devstral-small-latest",
    "devstral-m" => "devstral-medium-latest",
    "mag-s" => "magistral-small-latest",
    "mag-m" => "magistral-medium-latest",

    # Google Gemini
    # 1–2 letter shorthands
    "g" => "gemini-2.5-pro",
    "gf" => "gemini-2.5-flash",

    "gemini" => "gemini-2.5-pro",
    "flash"  => "gemini-2.5-flash",
    # Broader Google/Gemma shorthands
    "pro" => "gemini-2.5-pro",
    "flash-lite" => "gemini-2.5-flash-lite",
    "1.5-pro" => "gemini-1.5-pro-latest",
    "1.5-flash" => "gemini-1.5-flash",
    "1.5-flash-8b" => "gemini-1.5-flash-8b-latest",
    "2.0-flash" => "gemini-2.0-flash",
    "imagen-4" => "imagen-4.0-generate-preview-06-06",
    "veo2" => "veo-2.0-generate-001",
    # Gemma 3 sizes (Google provider)
    "gemma3-4b" => "gemma-3-4b-it",
    "gemma3-12b" => "gemma-3-12b-it",
    "gemma3-27b" => "gemma-3-27b-it",

    # Anthropic Claude
    # 1–2 letter shorthands
    "h" => "claude-haiku-4-5-20251001",
    "s" => "claude-sonnet-4-5-20250929",
    "o" => "claude-opus-4-5-20251101",

    "sonnet" => "claude-sonnet-4-5-20250929",
    "opus"   => "claude-opus-4-5-20251101",
    "haiku"  => "claude-haiku-4-5-20251001",
    # Specific versioned Anthropic aliases
    "sonnet-4.5" => "claude-sonnet-4-5-20250929",
    "sonnet-4-5" => "claude-sonnet-4-5-20250929",
    "sonnet-3.7" => "claude-3-7-sonnet-20250219",
    "sonnet-3.5" => "claude-3-5-sonnet-20240620",
    "haiku-4.5"  => "claude-haiku-4-5-20251001",
    "haiku-4-5"  => "claude-haiku-4-5-20251001",
    "haiku-3.5"  => "claude-3-5-haiku-20241022",
    "opus-4"     => "claude-opus-4-20250514",
    "opus-4.1"   => "claude-opus-4-1-20250805",
    "opus-4.5"   => "claude-opus-4-5-20251101",

    # DeepSeek
    # 1–2 letter shorthands
    "r" => "deepseek-reasoner",
    "d" => "deepseek-chat",

    "r1" => "deepseek-reasoner",
    "v3" => "deepseek-chat",

    # OpenRouter popular slugs
    "grok-4" => "x-ai/grok-4",
    "grok-3" => "x-ai/grok-3",
    "grok-3-mini" => "x-ai/grok-3-mini",
    "kimi-k2" => "moonshotai/kimi-k2",
    "kimi-dev-72b" => "moonshotai/kimi-dev-72b",
    "glm-4.5" => "z-ai/glm-4.5",
    "glm-4.5v" => "z-ai/glm-4.5v",
    "glm-4.5-air" => "z-ai/glm-4.5-air",
    "command-r" => "cohere/command-r",
    "command-r+" => "cohere/command-r-plus",
    "sonar-pro" => "perplexity/sonar-pro",
    "sonar-reason" => "perplexity/sonar-reasoning",
    "nova-micro" => "amazon/nova-micro-v1",
    "nova-lite" => "amazon/nova-lite-v1",
    "nova-pro" => "amazon/nova-pro-v1",
    "gemma3-27b-or" => "google/gemma-3-27b-it",
    # Ollama local models
    "gemma3-4b-ollama" => "gemma3:4b",
    "gemma3-12b-ollama" => "gemma3:12b",
    "qwen3-14b-ollama" => "qwen3:14b",
    "phi4-r" => "phi4-reasoning",
    "gemma3n-e4b" => "gemma3n:e4b",
    "gemma3n-e2b" => "gemma3n:e2b",
    "oss-120b" => "gpt-oss",
    # Shorter gpt-oss aliases
    "oss" => "gpt-oss",
    "oss20" => "gpt-oss:20b",

    # OpenAI GPT
    "4o"      => "gpt-4o",
    "4o-mini" => "gpt-4o-mini",
    "3.5"     => "gpt-3.5-turbo",
    "5"       => "gpt-5",
    "5-mini"  => "gpt-5-mini",
    # Additional OpenAI families
    "5-nano" => "gpt-5-nano",
    "5-chat" => "gpt-5-chat-latest",
    "5.1" => "gpt-5.1",
    "5.1-chat" => "gpt-5.1-chat-latest",
    "5.1-codex" => "gpt-5.1-codex",
    "5.1-codex-mini" => "gpt-5.1-codex-mini",
    "oss-120b" => "gpt-oss:120b",
    "oss120b" => "gpt-oss:120b",
    "o1" => "o1",
    "o1-mini" => "o1-mini",
    "o1-pro" => "o1-pro",
    "o3" => "o3",
    "o3-mini" => "o3-mini",
    "o3-mini-high" => "o3-mini-high",
    "o4-mini" => "o4-mini",
    "4.1" => "gpt-4.1",
    "4.1-mini" => "gpt-4.1-mini",
    "4.1-nano" => "gpt-4.1-nano",
    "4o-audio" => "gpt-4o-audio-preview",
    "4o-rt" => "gpt-4o-realtime-preview",
    "4o-search" => "gpt-4o-search-preview",
    "4o-mini-search" => "gpt-4o-mini-search-preview",
    "4o-transcribe" => "gpt-4o-transcribe",
)

@enum ThinkLevel begin
    ThinkAutomatic = -1
    ThinkNone      = 0
    ThinkMinimal   = 1
    ThinkLow       = 2
    ThinkMedium    = 3
    ThinkHigh      = 4
end
export ThinkLevel, ThinkAutomatic, ThinkNone, ThinkMinimal, ThinkLow, ThinkMedium, ThinkHigh
