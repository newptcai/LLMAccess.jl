# CLI Usage

LLMAccess includes simple scripts in the `script/` directory for quick interaction with providers.

## Scripts

- `script/ask.jl`: Send a prompt and print the model response.
- `script/cmd.jl`: Generate a shell command, copy it to clipboard by default, and optionally execute after confirmation. Supports `--cmd CMD` to bypass the LLM and still use the copy/execute flow. Use `--no-copy` to disable clipboard copying for this script. Prompts can reference `{{FILE}}` (or the shorthand `{{F}}`) to inject the `-f/--file` path, or `{{FILE|cmd}}`/`{{F|cmd}}` to run a shell snippet (`bash -lc`) where the original path is piped via STDIN and exposed as `$FILE_PLACEHOLDER`. For simple tweaks, prefix the helper name with a colon to call built-ins such as `{{F|:ext=pdf}}`, `{{F|:basename}}`, `{{F|:dirname}}`, `{{F|:stem}}`, `{{F|:ext}}`, or `{{F|:remove-ext}}`. They avoid the need for sed/awk by handling basic path manipulations inline.

The built-in helpers currently cover `basename`, `dirname`, `stem`/`without-ext`, `ext`, and `remove-ext`. `:ext` returns the extension when used alone; pass a new value (using either a space or `=`) to replace it, and omit the dot to have it added automatically. Providing an empty value is equivalent to dropping the extension entirely. The older `path:` prefix remains available for compatibility, but `:` is the preferred shorthand.
- `script/echo.jl`: Simple echo utility using the library.

Run with the project environment:

```bash
julia --project script/ask.jl --llm google "Hello"
```

## Common Flags

- `--llm, -l`: Provider (`openai`, `anthropic`, `google`, `ollama`, `ollama_cloud`, `mistral`, `openrouter`, `deepseek`, `cerebras`, `groq`).
- `--model, -m`: Model name (supports aliases; defaults per provider or env).
- `--attachment, -a`: Path to file to attach (e.g., image for vision models).
- `--file, -f`: Input file path (optional; script-specific). `script/cmd.jl` uses this to power the `{{FILE}}`/`{{F}}` placeholder system described above.
- `--schema-file`: Path to a JSON schema file for the response.
- `--schema`: JSON schema for the response as a string.
- `--temperature, -t`: Sampling temperature (Float64; default 1.0 unless overridden by env).
- `--debug, -d`: Enable debug logging and verbose error output.
- `--copy, -c`: Copy response to clipboard (if supported by script).
- `--no-copy`: For `script/cmd.jl` only, disable the default clipboard copying.
- `--think, -k`: Thinking budget for supported providers (e.g., Gemini, Claude, GPT-5). Any non-zero value toggles reasoning for Ollama (local + cloud).
- `--alias`: Print all model aliases and exit.
- `--llm-alias`: Print provider aliases for `--llm` and exit.
- `--providers`: Print supported LLM providers (valid `--llm` choices) and exit.
- `--dry-run`: Print the exact JSON payload that would be sent and exit (no network call).
- `--no-normalize`: Disable punctuation normalization (dashes/quotes) in output (not exposed by `script/cmd.jl` so commands remain untouched).

## Examples

```bash
# Print response
julia --project script/ask.jl --llm openai -m gpt-4o-mini "Summarize this repo"

# Use alias
julia --project script/ask.jl --llm google -m flash "Hi"

# Prompt the local Ollama daemon
julia --project script/ask.jl --llm ollama --model gemma3-4b-ollama "Give me three bullet talking points"

# Prompt Ollama Cloud (hosted API; requires OLLAMA_API_KEY)
julia --project script/ask.jl --llm ollama_cloud --model gpt-oss:120b "Share a fun fact"

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

# Inject a file path (and tweak its extension via the built-in helper)
julia --project script/cmd.jl -f ./script/example.sh --llm openai "Review {{F|:ext=md}}"

# Bypass the LLM and still get copy/execute flow
julia --project script/cmd.jl --cmd 'echo hi'
```

## Output normalization

By default, responses are normalized for readability:

#### Punctuation
- Em dash — -> `---`
- En dash – -> `--`
- Smart double quotes “ ” „ ‟ « » -> `"`
- Smart single quotes ‘ ’ ‚ ‛ ʼ -> `'`

#### Text Formatting
- Empty line after each Markdown heading
- Empty line before/after list items, with wrapped list continuations indented
- Long lines (>80 chars) wrapped at word boundaries
- Trailing whitespace on each line removed
- Surrounding ``` fences stripped when the entire response is wrapped in a code block

Disable with:

```bash
julia --project script/ask.jl --no-normalize --llm google "“Quotes” and — dashes –"
```

## Aliases

- Use short aliases for common models via `-m/--model`.
- Use short aliases for providers via `-l/--llm` (e.g., `g` for `google`, `oa` for `openai`, `ol` for `ollama`, `oc` for `ollama_cloud`, `c` for `cerebras`, `gr` for `groq`).
- Print model aliases: `julia --project script/ask.jl --alias`.
- Print provider aliases: `julia --project script/ask.jl --llm-alias`.

Common examples

- OpenAI: `4o`, `4o-mini`, `o1`, `o1-mini`, `o3`, `o3-mini`, `o4-mini`, `4.1`, `4o-search`, `5.1`, `5.1-chat`, `5.1-codex`
- Google: `g` (Gemini Pro), `gf` (Gemini Flash), `1.5-pro`, `1.5-flash`, `1.5-flash-8b`, `flash-lite`, `gemma3-12b`
- Anthropic: `h` (Haiku), `s` (Sonnet), `o` (Opus), `sonnet-3.7`
- Mistral: `m` (Medium), `ms` (Small), `ml` (Large), `mo` (OCR), `codestral`, `pix`
- OpenRouter: `grok-4`, `glm-4.5`, `command-r+`, `sonar-pro`, `nova-pro`
- Ollama: `gemma3-12b-ollama`, `qwen3-14b-ollama`, `phi4-r`, `oss-120b`
- Ollama Cloud: `gpt-oss:120b`
- DeepSeek: `r` (Reasoner), `d` (Chat), `r1-8b`

See the README “Model Aliases” section for a longer list.
