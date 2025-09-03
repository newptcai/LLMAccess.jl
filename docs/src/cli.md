# CLI Usage

LLMAccess includes simple scripts in the `script/` directory for quick interaction with providers.

## Scripts

- `script/ask.jl`: Send a prompt and print the model response.
- `script/cmd.jl`: Generate a shell command, copy it to clipboard, and optionally execute after confirmation. Supports `--cmd CMD` to bypass the LLM and still use the copy/execute flow.
- `script/echo.jl`: Simple echo utility using the library.

Run with the project environment:

```bash
julia --project script/ask.jl --llm google "Hello"
```

## Common Flags

- `--llm, -l`: Provider (`openai`, `anthropic`, `google`, `ollama`, `mistral`, `openrouter`, `groq`, `deepseek`).
- `--model, -m`: Model name (supports aliases; defaults per provider or env).
- `--attachment, -a`: Path to file to attach (e.g., image for vision models).
- `--file, -f`: Input file path (optional; script-specific).
- `--temperature, -t`: Sampling temperature (Float64; default 1.0 unless overridden by env).
- `--debug, -d`: Enable debug logging and verbose error output.
- `--copy, -c`: Copy response to clipboard (if supported by script).
- `--think, -k`: Thinking budget for supported providers (e.g., Gemini, Claude).
- `--alias, -A`: Print all model aliases and exit.
- `--dry-run, -D`: Print the exact JSON payload that would be sent and exit (no network call).

## Examples

```bash
# Print response
julia --project script/ask.jl --llm openai -m gpt-4o-mini "Summarize this repo"

# Use alias
julia --project script/ask.jl --llm google -m flash "Hi"

# Attach an image (vision-enabled models)
julia --project script/ask.jl --llm openai -m gpt-4o --attachment path/to/image.png "Describe this image"

# Show available aliases
julia --project script/ask.jl --alias

# Dry run to inspect payload (no request made)
julia --project script/ask.jl --llm ollama -D "Hello"
julia --project script/ask.jl --llm google --attachment image.png --dry-run "describe"

# Generate shell commands
julia --project script/cmd.jl --llm openai "list files changed today"

# Bypass the LLM and still get copy/execute flow
julia --project script/cmd.jl --cmd 'echo hi'
```
