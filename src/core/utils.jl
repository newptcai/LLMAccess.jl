"""
    get_default_llm()

Returns the default LLM provider from `ENV["DEFAULT_LLM"]` or `DEFAULT_LLM`.
"""
function get_default_llm()
    return get(ENV, "DEFAULT_LLM", DEFAULT_LLM)
end

"""
    normalize_output_text(text::AbstractString) :: String

Normalize LLM output by replacing certain Unicode punctuation with ASCII-friendly
alternatives:

- Em dash (—) -> "---"
- En dash (–) -> "--"
- Smart double quotes (“ ” „ ‟ « ») -> '"'
- Smart single quotes (‘ ’ ‚ ‛ ʼ) -> "'"

This is a minimal, opinionated normalization intended for plain-text output.
"""
function normalize_output_text(text::AbstractString)::String
    isempty(text) && return String(text)
    return replace(
        String(text),
        '—' => "---",
        '–' => "--",
        '“' => '"',
        '”' => '"',
        '„' => '"',
        '‟' => '"',
        '«' => '"',
        '»' => '"',
        '‘' => '\'',
        '’' => '\'',
        '‚' => '\'',
        '‛' => '\'',
        'ʼ' => '\''
    )
end

"""
    get_default_temperature()

Returns the default temperature from `ENV["DEFAULT_TEMPERATURE"]` or `DEFAULT_TEMPERATURE`.
"""
function get_default_temperature()
    return parse(Float64, get(ENV, "DEFAULT_TEMPERATURE", string(DEFAULT_TEMPERATURE)))
end

"""
    get_llm_list()

Returns an iterable of LLM provider names.
"""
function get_llm_list()
    return keys(DEFAULT_MODELS)
end

"""
    resolve_provider_alias(llm_name::AbstractString) :: String

Resolve short provider aliases (e.g., "g", "oa", "an") to canonical
provider names (e.g., "google", "openai", "anthropic"). Returns the
original name if no alias mapping is found.
"""
function resolve_provider_alias(llm_name::AbstractString)::String
    name = lowercase(String(llm_name))
    resolved = get(PROVIDER_ALIASES, name, name)
    if resolved != name
        @debug "Resolved provider alias" name resolved
    end
    return resolved
end

"""
    get_default_model(llm_name)

Returns the default model for a provider using `ENV["DEFAULT_<LLM>_MODEL"]` or `DEFAULT_MODELS`.
"""
function get_default_model(llm_name)
    return get(ENV, "DEFAULT_" * uppercase(llm_name) * "_MODEL", DEFAULT_MODELS[llm_name])
end

"""
    resolve_model_alias(model_name)

Return the full model name if `model_name` is an alias; otherwise return it unchanged.
"""
function resolve_model_alias(model_name)
    resolved_name = get(MODEL_ALIASES, model_name, model_name)
    if resolved_name != model_name
        @debug "Resolved model alias: '$model_name' -> '$resolved_name'"
    else
        @debug "Model name '$model_name' is not an alias or not found in MODEL_ALIASES."
    end
    return resolved_name
end

"""
    default_think_for_model(model_name::String) :: Int

Suggest a default `--think/-k` based on the model.
"""
function default_think_for_model(model_name::String)::Int
    m = lowercase(model_name)
    if startswith(m, "gemini-")
        return -1
    end
    if occursin("claude-sonnet-", m) || occursin("-sonnet-", m)
        return 0
    end
    if occursin("deepseek-reasoner", m)
        return 0
    end
    if startswith(m, "mistral-")
        return 0
    end
    return 0
end

"""
    is_anthropic_thinking_model(model_name::String)

Check if an Anthropic model supports the 'thinking' feature by name and version.
"""
function is_anthropic_thinking_model(model_name::String)
    m1 = match(r"claude-(sonnet|opus)-([0-9]+(?:[\.\-][0-9]+)?)-", model_name)
    if m1 !== nothing
        type = m1.captures[1]
        version_str = replace(m1.captures[2], "-" => ".")
        version = tryparse(Float64, version_str)
        if version !== nothing
            if type == "sonnet" && version >= 3.7
                return true
            end
            if type == "opus" && version >= 4
                return true
            end
        end
    end
    m2 = match(r"claude-([0-9]+(?:[\.\-][0-9]+)?)-(sonnet|opus)-", model_name)
    if m2 !== nothing
        version_str = replace(m2.captures[1], "-" => ".")
        type = m2.captures[2]
        version = tryparse(Float64, version_str)
        if version !== nothing
            if type == "sonnet" && version >= 3.7
                return true
            end
            if type == "opus" && version >= 4
                return true
            end
        end
    end
    return false
end

"""
    encode_file_to_base64(file_path)

Read a file and return `(mime_type, base64_string)`.
"""
function encode_file_to_base64(file_path)
    @debug "Encoding $file_path to Base64"
    file_content = read(file_path)
    file_extension = splitext(file_path)[2]
    mime_type = mime_from_extension(file_extension)
    io = IOBuffer()
    iob64 = Base64EncodePipe(io)
    write(iob64, file_content)
    close(iob64)
    return (mime_type, String(take!(io)))
end

"""
    encode_file_to_base64(llm, file_path)

Return LLM-specific attachment JSON for the encoded file.
"""
function encode_file_to_base64(::Union{OpenAICompatibleLLM, MistralLLM}, file_path)
    mime_type, base64_encoded = encode_file_to_base64(file_path)
    return Dict(
        "type" => "image_url",
        "image_url" => Dict("url" => "data:$(mime_type);base64,$base64_encoded"),
    )
end

function encode_file_to_base64(::GoogleLLM, file_path)
    mime_type, base64_encoded = encode_file_to_base64(file_path)
    return Dict("inline_data" => Dict("mime_type" => "$(mime_type)", "data" => "$(base64_encoded)"))
end

function encode_file_to_base64(::AnthropicLLM, file_path)
    mime_type, base64_encoded = encode_file_to_base64(file_path)
    return Dict(
        "type" => "image",
        "source" => Dict("type" => "base64", "media_type" => "$(mime_type)", "data" => "$(base64_encoded)"),
    )
end

"""
    get_nested(data, path)

Navigate a nested structure by keys/indexes and return the value.
"""
function get_nested(data, path)
    for key in path
        data = data[key]
    end
    return data
end
