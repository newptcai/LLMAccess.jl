module LLMAccess

using HTTP
using JSON
using ArgParse
using Base64
using MIMEs
using Logging
using Serialization
using Pandoc
using InteractiveUtils

export call_llm,
       list_llm_models,
       get_llm_type,
       get_llm_list,
       parse_commandline,
       run_cli,
       jina_reader,
       pandoc_reader

# Core building blocks
include("core/types_constants.jl")
include("core/utils.jl")
include("core/http.jl")

# Provider implementations
include("providers/openai_compat.jl")
include("providers/anthropic.jl")
include("providers/google.jl")
include("providers/mistral.jl")
include("providers/ollama.jl")

# Model listing APIs
include("models.jl")

# CLI and helpers
include("cli.jl")

# Reader utilities
include("readers.jl")

# Dispatchers (by name / args dict)
include("dispatch.jl")

end # module LLMAccess

