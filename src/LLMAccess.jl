module LLMAccess

export call_llm,
       list_llm_models,
       get_llm_type,
       get_llm_list,
       parse_commandline,
       run_cli,
        jina_reader,
       pandoc_reader

# ─────────────────────────────────────────────────────────────────────────────
# Submodules
# ─────────────────────────────────────────────────────────────────────────────

module Core
    using Logging
    using JSON
    using HTTP
    using Base64
    using MIMEs
    using Serialization

    include("core/types_constants.jl")
    include("core/utils.jl")
    include("core/http.jl")

    # Export commonly used types, constants, and helpers so other submodules
    # can simply `using ..Core` without listing every symbol.
    export AbstractLLM,
           OpenAICompatibleLLM,
           OpenAILLM,
           OpenRouterLLM,
           GroqLLM,
           AnthropicLLM,
           GoogleLLM,
           OllamaLLM,
           MistralLLM,
           DeepSeekLLM,
           ZaiLLM,
           DEFAULT_MODELS,
           DEFAULT_TEMPERATURE,
           DEFAULT_LLM,
           PROVIDER_ALIASES,
           MODEL_ALIASES,
           get_default_llm,
           get_default_temperature,
           get_llm_list,
           get_default_model,
           resolve_provider_alias,
           resolve_model_alias,
           default_think_for_model,
           is_anthropic_thinking_model,
           encode_file_to_base64,
           post_request,
           get_request,
           handle_json_response,
           extract_google_text,
           get_nested
end # module Core

module Providers
    using ..Core
    using JSON

    include("providers/openai_compat.jl")
    include("providers/anthropic.jl")
    include("providers/google.jl")
    include("providers/mistral.jl")
    include("providers/ollama.jl")

    export call_llm
end # module Providers

module Models
    using ..Core
    include("models.jl")
    export list_llm_models
end # module Models

module CLI
    using ArgParse
    using Logging
    using ..Core
    include("cli.jl")
    export parse_commandline, run_cli, create_default_settings
end # module CLI

module Readers
    using HTTP
    using Pandoc
    include("readers.jl")
    export jina_reader, pandoc_reader
end # module Readers

module Dispatch
    using ..Core
    import ..Providers: call_llm
    using InteractiveUtils: clipboard
    include("dispatch.jl")
    export call_llm, get_llm_type
end # module Dispatch

# ─────────────────────────────────────────────────────────────────────────────
# Public re-exports for backward compatibility
# ─────────────────────────────────────────────────────────────────────────────

using .Dispatch: call_llm, get_llm_type
using .Models: list_llm_models
using .Core: get_llm_list, is_anthropic_thinking_model
using .CLI: parse_commandline, run_cli, create_default_settings
using .Readers: jina_reader, pandoc_reader

end # module LLMAccess
