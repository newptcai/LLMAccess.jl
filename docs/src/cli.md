# CLI Usage

LLMAccess includes simple scripts in the `script/` directory for quick interaction with providers.

## Scripts

- `script/ask.jl`: Send a prompt and print the model response.
- `script/cmd.jl`: Generate a shell command, copy it to clipboard by default, and optionally execute after confirmation. Supports `--cmd CMD` to bypass the LLM and still use the copy/execute flow. Use `--no-copy` to disable clipboard copying for this script.
- `script/echo.jl`: Simple echo utility using the library.

Run with the project environment:

```bash
julia --project script/ask.jl --llm google "Hello"
```

## Common Flags

- `--llm, -l`: Provider (`openai`, `anthropic`, `minimax`, `google`, `ollama`, `ollama_cloud`, `mistral`, `openrouter`, `groq`, `deepseek`, `zai`).
- `--model, -m`: Model name (supports aliases; defaults per provider or env).
- `--attachment, -a`: Path to file to attach (e.g., image for vision models).
- `--file, -f`: Input file path (optional; script-specific).
- `--temperature, -t`: Sampling temperature (Float64; default 1.0 unless overridden by env).
- `--debug, -d`: Enable debug logging and verbose error output.
- `--copy, -c`: Copy response to clipboard (if supported by script).
- `--no-copy`: For `script/cmd.jl` only, disable the default clipboard copying.
- `--think, -k`: Thinking budget for supported providers (e.g., Gemini, Claude).
- `--alias`: Print all model aliases and exit.
- `--llm-alias`: Print provider aliases for `--llm` and exit.
- `--providers`: Print supported LLM providers (valid `--llm` choices) and exit.
- `--dry-run`: Print the exact JSON payload that would be sent and exit (no network call).
- `--no-normalize`: Disable punctuation normalization (dashes/quotes) in output.

## Examples

```bash
# Print response
julia --project script/ask.jl --llm openai -m gpt-4o-mini "Summarize this repo"

# Use alias
julia --project script/ask.jl --llm google -m flash "Hi"

# Call MiniMax (defaults to MiniMax-M2)
julia --project script/ask.jl --llm minimax "Give me three bullet talking points"

# Attach an image (vision-enabled models)
julia --project script/ask.jl --llm openai -m gpt-4o --attachment path/to/image.png "Describe this image"

# Show available aliases
julia --project script/ask.jl --alias

# Show valid provider choices
julia --project script/ask.jl --providers

# Dry run to inspect payload (no request made)
julia --project script/ask.jl --llm ollama --dry-run "Hello"
julia --project script/ask.jl --llm google --attachment image.png --dry-run "describe"

# Show provider alias map
julia --project script/ask.jl --llm-alias

# Generate shell commands
julia --project script/cmd.jl --llm openai "list files changed today"

# Bypass the LLM and still get copy/execute flow
julia --project script/cmd.jl --cmd 'echo hi'
```

## Output normalization

By default, responses are normalized to replace certain Unicode punctuation with ASCII-friendly characters:

- Em dash — -> `---`
- En dash – -> `--`
- Smart double quotes “ ” „ ‟ « » -> `"`
- Smart single quotes ‘ ’ ‚ ‛ ʼ -> `'`

Disable with:

```bash
julia --project script/ask.jl --no-normalize --llm google "“Quotes” and — dashes –"
```

## Aliases

- Use short aliases for common models via `-m/--model`.
- Use short aliases for providers via `-l/--llm` (e.g., `g` for `google`, `oa` for `openai`, `mm` for `minimax`).
- Print model aliases: `julia --project script/ask.jl --alias`.
- Print provider aliases: `julia --project script/ask.jl --llm-alias`.

Common examples

- OpenAI: `4o`, `4o-mini`, `o1`, `o1-mini`, `o3`, `o3-mini`, `o4-mini`, `4.1`, `4o-search`
- Google: `g` (Gemini Pro), `gf` (Gemini Flash), `1.5-pro`, `1.5-flash`, `1.5-flash-8b`, `flash-lite`, `gemma3-12b`
- Anthropic: `h` (Haiku), `s` (Sonnet), `o` (Opus), `sonnet-3.7`
- MiniMax: `mm2`, `minimax`
- Mistral: `m` (Medium), `ms` (Small), `ml` (Large), `mo` (OCR), `codestral`, `pix`
- Groq: `llama-70b`, `qwen-32b`, `whisper`, `r1-70b`
- OpenRouter: `grok-4`, `glm-4.5`, `command-r+`, `sonar-pro`, `nova-pro`
- Ollama: `gemma3-12b-ollama`, `qwen3-14b-ollama`, `phi4-r`
- Ollama Cloud: `gpt-oss:20b`, `gpt-oss:120b`, `kimi-k2:1t`

See the README “Model Aliases” section for a longer list.
