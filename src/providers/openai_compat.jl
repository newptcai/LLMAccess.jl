"""
    call_llm(llm::AbstractLLM; kwargs...)

Abstract method for provider call. Implemented per-concrete type.
"""
function call_llm(llm::AbstractLLM; kwargs...)
    error("Not implemented for $(typeof(llm))")
end

"""
    get_default_think_level(::Type{T}, model::String) where T <: AbstractLLM

Get the default thinking level for a given provider and model.
"""
function get_default_think_level(::Type{T}, model::String) where T <: AbstractLLM
    return ThinkNone  # default for most providers
end

function get_default_think_level(::Type{GroqLLM}, model::String)
    # Qwen models: use minimal reasoning by default (maps to "default")
    if occursin("qwen", lowercase(model))
        return ThinkMinimal
    end

    # gpt-oss models: use low reasoning by default
    if occursin("gpt-oss", lowercase(model))
        return ThinkLow
    end

    return ThinkNone
end

function get_default_think_level(::Type{CerebrasLLM}, model::String)
    # Cerebras gpt-oss-120b: documentation says medium is default
    # but API doesn't support reasoning yet, so disable for now
    return ThinkNone
end

function get_default_think_level(::Type{OpenAILLM}, model::String)
    # GPT-5 and O1 models: use minimal reasoning by default
    if occursin("gpt-5", lowercase(model)) || startswith(lowercase(model), "o")
        return ThinkMinimal
    end

    return ThinkNone
end

"""
    get_reasoning_effort(llm::T, think::ThinkLevel, model::String) where T <: AbstractLLM

Get reasoning effort for a specific provider, think level, and model.
Returns nothing if reasoning parameter should be omitted entirely.
"""
function get_reasoning_effort(llm::T, think::ThinkLevel, model::String) where T <: AbstractLLM
    return nothing  # default for providers that don't support reasoning
end

function get_reasoning_effort(llm::GroqLLM, think::ThinkLevel, model::String)
    # Qwen models: support "none", "default", "low", "medium", "high"
    if occursin("qwen", lowercase(model))
        if think == ThinkNone
            return "none"      # disable reasoning
        else
            return "default"    # let Qwen reason
        end
    end

    # gpt-oss models: support "low", "medium", "high"
    if occursin("gpt-oss", lowercase(model))
        if think == ThinkNone
            return nothing      # omit parameter entirely
        else
            return if think == ThinkMinimal || think == ThinkLow
                "low"
            elseif think == ThinkMedium
                "medium"
            else  # ThinkHigh, ThinkAutomatic
                "high"
            end
        end
    end

    return nothing
end

function get_reasoning_effort(llm::CerebrasLLM, think::ThinkLevel, model::String)
    # Cerebras documentation mentions reasoning effort for gpt-oss-120b model
    # but current API doesn't support it yet - return nothing for all cases
    return nothing
end

function get_reasoning_effort(llm::OpenAICompatibleLLM, think::ThinkLevel, model::String)
    # This handles OpenAI, DeepSeek (OpenAI-compatible)
    reasoning_effort = if think == ThinkNone
        "none"
    elseif think == ThinkMinimal
        "minimal"
    elseif think == ThinkLow
        "low"
    elseif think == ThinkMedium
        "medium"
    elseif think == ThinkHigh || think == ThinkAutomatic
        "high"
    else
        "none"
    end

    # GPT-5.1 supports none, low, medium, high (no minimal)
    if occursin("gpt-5.1", lowercase(model)) && reasoning_effort == "minimal"
        reasoning_effort = "low"
    end

    # GPT-5-pro only supports high
    if occursin("gpt-5-pro", lowercase(model))
        reasoning_effort = "high"
    end

    return reasoning_effort
end

"""
    make_api_request(llm, api_key, url, system_instruction, input_text, model, temperature, attach_file; dry_run=false, think=0, max_tokens=nothing)

Prepare and send an OpenAI-compatible chat.completions request and return text.
"""
function make_api_request(
    llm::OpenAICompatibleLLM,
    api_key,
    url,
    system_instruction,
    input_text,
    model,
    temperature::Float64,
    attach_file;
    dry_run::Bool = false,
    think::ThinkLevel = ThinkNone,
    max_tokens = nothing,
    schema_content::String = ""
)
    @debug "Making API request" llm system_instruction input_text model temperature attach_file think schema_content
    
    current_input_text = input_text
    add_deepseek_response_format = false

    # gpt-oss workaround
    if occursin("gpt-oss", lowercase(model)) && !isempty(schema_content)
        current_input_text = """
        $current_input_text

        Use the provided JSON schema for your reply:
        ```
        $schema_content
        ```
        """
    # DeepSeek workaround
    elseif llm isa DeepSeekLLM && !isempty(schema_content)
        current_input_text = """
        $current_input_text

        Use the provided JSON schema for your reply:
        ```
        $schema_content
        ```
        """
        add_deepseek_response_format = true
    end

    headers = [
        "Content-Type" => "application/json",
        "Authorization" => "Bearer $api_key",
    ]
    text_data = Dict("type" => "text", "text" => current_input_text)
    content = attach_file != "" ? [text_data, encode_file_to_base64(llm, attach_file)] : [text_data]
    user_message   = Dict("role" => "user", "content" => content)
    system_message = Dict("role" => "system", "content" => system_instruction)
    messages = Vector{Dict{String, Any}}()
    if !isempty(system_instruction)
        push!(messages, system_message)
    end
    push!(messages, user_message)
    data = Dict("model" => model, "temperature" => temperature, "messages" => messages)

    # Handle schema if provided (for non-gpt-oss and non-DeepSeek models)
    if !occursin("gpt-oss", lowercase(model)) && !(llm isa DeepSeekLLM) && !isempty(schema_content)
        schema_parsed = try
            JSON.parse(schema_content)
        catch e
            error("Failed to parse schema content: $e")
        end
        data["response_format"] = Dict("type" => "json_schema", "json_schema" => schema_parsed)
    elseif add_deepseek_response_format # For DeepSeek
        data["response_format"] = Dict("type" => "json_object")
    end

    # Handle max_tokens if provided
    if max_tokens !== nothing
        data["max_tokens"] = max_tokens
    end

    # Handle reasoning effort using type-dispatched functions
    reasoning_effort = get_reasoning_effort(llm, think, model)
    if reasoning_effort !== nothing
        data["reasoning"] = Dict("effort" => reasoning_effort)
        @debug "Setting reasoning effort" model reasoning_effort think
    end
    if dry_run
        return JSON.json(data)
    end
    response = post_request(url, headers, data)
    return handle_json_response(response, ["choices", 1, "message", "content"])
end

# OpenAI
function call_llm(
    llm::OpenAILLM,
    system_instruction="",
    input_text="",
    model = get_default_model("openai"),
    temperature::Float64 = get_default_temperature(),
    attach_file = "";
    kwargs...
)
    api_key = ENV["OPENAI_API_KEY"]
    url     = "https://api.openai.com/v1/chat/completions"
    dry_run = get(kwargs, :dry_run, false)
    think = get(kwargs, :think) do
        get_default_think_level(OpenAILLM, model)
    end
    schema_content = get(kwargs, :schema_content, "")
    return make_api_request(llm, api_key, url, system_instruction, input_text, model, temperature, attach_file; dry_run=dry_run, think=think, schema_content=schema_content)
end

# DeepSeek (OpenAI-compatible)
function call_llm(
    llm::DeepSeekLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("deepseek"),
    temperature::Float64 = get_default_temperature(),
    attach_file = "";
    kwargs...
)
    api_key = ENV["DEEPSEEK_API_KEY"]
    url     = "https://api.deepseek.com/v1/chat/completions"
    dry_run = get(kwargs, :dry_run, false)
    think = get(kwargs, :think, ThinkNone)
    schema_content = get(kwargs, :schema_content, "")

    # For DeepSeek R1 models, use thinking budget as max_tokens if provided
    max_tokens = nothing
    if think != ThinkNone && (occursin("r1", lowercase(model)) || occursin("deepseek-reasoner", lowercase(model)))
        max_tokens = if think == ThinkMinimal
            1024
        elseif think == ThinkLow
            2048
        elseif think == ThinkHigh || think == ThinkAutomatic
            4096
        else
            nothing
        end
    end

    return make_api_request(llm, api_key, url, system_instruction, input_text, model, temperature, attach_file; dry_run=dry_run, think=think, max_tokens=max_tokens, schema_content=schema_content)
end

# Cerebras (OpenAI-compatible)
function call_llm(
    llm::CerebrasLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("cerebras"),
    temperature::Float64 = get_default_temperature(),
    attach_file = "";
    kwargs...
)
    api_key = ENV["CEREBRAS_API_KEY"]
    url     = "https://api.cerebras.ai/v1/chat/completions"
    dry_run = get(kwargs, :dry_run, false)
    think = get(kwargs, :think) do
        get_default_think_level(CerebrasLLM, model)
    end
    schema_content = get(kwargs, :schema_content, "")
    return make_api_request(llm, api_key, url, system_instruction, input_text, model, temperature, attach_file; dry_run=dry_run, think=think, schema_content=schema_content)
end

# Groq (OpenAI-compatible)
function call_llm(
    llm::GroqLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("groq"),
    temperature::Float64 = get_default_temperature(),
    attach_file = "";
    kwargs...
)
    api_key = ENV["GROQ_API_KEY"]
    url     = "https://api.groq.com/openai/v1/chat/completions" # Assuming standard OpenAI compatible endpoint
    dry_run = get(kwargs, :dry_run, false)
    think = get(kwargs, :think) do
        get_default_think_level(GroqLLM, model)
    end
    schema_content = get(kwargs, :schema_content, "")
    return make_api_request(llm, api_key, url, system_instruction, input_text, model, temperature, attach_file; dry_run=dry_run, think=think, schema_content=schema_content)
end
