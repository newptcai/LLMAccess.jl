# LLMAccess.jl

LLMAccess.jl provides a lightweight, composable interface and CLI to interact with multiple LLM providers (OpenAI, Anthropic, Google, Ollama, Mistral, OpenRouter, Groq, DeepSeek, Z.ai) from Julia.

- Flexible provider abstraction with typed methods
- Sensible defaults via environment variables
- Small CLI helpers for quick usage in shells and scripts

See the README for end-to-end examples and environment setup.

## Installation

This package is a standard Julia project. From the package REPL:

```julia
pkg> dev /path/to/llmaccess.jl
```

Instantiate dependencies:

```bash
julia --project -e 'using Pkg; Pkg.instantiate()'
```

## Quick Start

Programmatic usage:

```julia
using LLMAccess

# Call by provider name (keywords for options)
text = LLMAccess.call_llm(
    "google",
    "You are helpful",
    "Hello!";
    model = LLMAccess.get_default_model("google"),
    temperature = LLMAccess.get_default_temperature(),
)
println(text)
```

Notes:
- For attachments (e.g., images), use the typed form which accepts an attachment path positionally: `call_llm(GoogleLLM(), system, input, model, temperature, attach_file)`. The name-based helper does not take attachments.

CLI examples (see also the CLI page):

```bash
julia --project script/ask.jl --llm google "Hello"
julia --project script/cmd.jl --llm openai "list files changed today"
julia --project script/ask.jl --alias
julia --project script/ask.jl --llm-alias
julia --project script/ask.jl --llm zai --model glm-4.5-air "What is the capital of France?"
```

## Configuration

Configure API keys and defaults via environment variables (examples):

- `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`, `MISTRAL_API_KEY`, `GROQ_API_KEY`, `DEEPSEEK_API_KEY`, `Z_API_KEY`
- `DEFAULT_LLM`, `DEFAULT_OPENAI_MODEL`, `DEFAULT_GOOGLE_MODEL`, etc.
- `DEFAULT_TEMPERATURE`

Refer to README for full details.

## Contents

```@contents
Pages = [
    "cli.md",
    "api.md",
]
Depth = 2
```
