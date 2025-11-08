# LLMAccess.jl

LLMAccess.jl provides a lightweight, composable interface and CLI to interact with multiple LLM providers (OpenAI, Anthropic, MiniMax, Google, Ollama, Ollama Cloud, Mistral, OpenRouter, Groq, DeepSeek, Z.ai, Cerebras) from Julia.

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
- MiniMax works through the Anthropic-compatible endpoint, so `MinimaxLLM()` shares response formatting with Claude and defaults to `MiniMax-M2`.

Output normalization:

By default the dispatcher normalizes certain punctuation in responses (dashes and smart quotes). To opt out in the name-based helper, pass `normalize_output=false`:

```julia
text = LLMAccess.call_llm("google", "", "“Quotes” and — dashes –"; normalize_output=false)
```

CLI examples (see also the CLI page):

```bash
julia --project script/ask.jl --llm google "Hello"
julia --project script/cmd.jl --llm openai "list files changed today"
julia --project script/ask.jl --alias
julia --project script/ask.jl --llm-alias
julia --project script/ask.jl --llm zai --model glm-4.5-air "What is the capital of France?"
julia --project script/ask.jl --llm cerebras --model zai-glm-4.6 "Summarize the Cerebras docs"

Note: `script/cmd.jl` copies the generated command to your clipboard by default. Use `--no-copy` to disable copying for that script, or `--cmd 'your command'` to bypass the LLM and still use the copy/execute flow.
```

## Configuration

Configure API keys and defaults via environment variables (examples):

- `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `MINIMAX_API_KEY`, `GOOGLE_API_KEY`, `OLLAMA_API_KEY`, `MISTRAL_API_KEY`, `GROQ_API_KEY`, `DEEPSEEK_API_KEY`, `ZAI_API_KEY`, `CEREBRAS_API_KEY`
- `DEFAULT_LLM`, `DEFAULT_OPENAI_MODEL`, `DEFAULT_CEREBRAS_MODEL`, `DEFAULT_GOOGLE_MODEL`, etc.
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
