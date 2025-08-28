# LLMAccess.jl

LLMAccess.jl provides a lightweight, composable interface and CLI to interact with multiple LLM providers (OpenAI, Anthropic, Google, Ollama, Mistral, OpenRouter, Groq, DeepSeek) from Julia.

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

llm = LLMAccess.get_llm_type("google")
text = LLMAccess.call_llm(llm,
    system_instruction = "You are helpful",
    input_text = "Hello!",
    model = LLMAccess.get_default_model("google"),
    temperature = LLMAccess.get_default_temperature(),
    attach_file = "",
)
println(text)
```

CLI examples (see also the CLI page):

```bash
julia --project script/ask.jl --llm google "Hello"
julia --project script/cmd.jl --llm openai "list files changed today"
julia --project script/ask.jl --alias
```

## Configuration

Configure API keys and defaults via environment variables (examples):

- `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`, `MISTRAL_API_KEY`, `GROQ_API_KEY`, `DEEPSEEK_API_KEY`
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

