"""
    call_llm(llm::AbstractLLM; kwargs...)

Abstract method for provider call. Implemented per-concrete type.
"""
function call_llm(llm::AbstractLLM; kwargs...)
    error("Not implemented for $(typeof(llm))")
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

    # Handle reasoning effort for GPT-5 and gpt-oss models
    if occursin("gpt-5", lowercase(model)) || startswith(lowercase(model), "o") || occursin("gpt-oss", lowercase(model))
        reasoning_effort = if think == ThinkNone
            "none"
        elseif think == ThinkMinimal
            "minimal"
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
    think = get(kwargs, :think, ThinkNone)
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
        elseif think == ThinkMedium
            2048
        elseif think == ThinkHigh || think == ThinkAutomatic
            4096
        else
            nothing
        end
    end

    return make_api_request(llm, api_key, url, system_instruction, input_text, model, temperature, attach_file; dry_run=dry_run, think=think, max_tokens=max_tokens, schema_content=schema_content)
end
