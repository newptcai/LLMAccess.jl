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
    think::Int = 0,
    max_tokens = nothing
)
    @debug "Making API request" llm system_instruction input_text model temperature attach_file think
    headers = [
        "Content-Type" => "application/json",
        "Authorization" => "Bearer $api_key",
    ]
    text_data = Dict("type" => "text", "text" => input_text)
    content = attach_file != "" ? [text_data, encode_file_to_base64(llm, attach_file)] : [text_data]
    user_message   = Dict("role" => "user", "content" => content)
    system_message = Dict("role" => "system", "content" => system_instruction)
    messages = Vector{Dict{String, Any}}()
    if !isempty(system_instruction)
        push!(messages, system_message)
    end
    push!(messages, user_message)
    data = Dict("model" => model, "temperature" => temperature, "messages" => messages)

    # Handle max_tokens if provided
    if max_tokens !== nothing
        data["max_tokens"] = max_tokens
    end

    # Handle reasoning effort for GPT-5 models
    if occursin("gpt-5", lowercase(model)) || startswith(lowercase(model), "o")
        reasoning_effort = think == 0 ? "none" :
                          think == 1 ? "minimal" :
                          think == 2 ? "low" :
                          think == 3 ? "medium" : "high"

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
    think = get(kwargs, :think, 0)
    return make_api_request(llm, api_key, url, system_instruction, input_text, model, temperature, attach_file; dry_run=dry_run, think=think)
end

# OpenRouter
function call_llm(
    llm::OpenRouterLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("openrouter"),
    temperature::Float64 = get_default_temperature(),
    attach_file = "";
    kwargs...
)
    api_key = ENV["OPENROUTER_API_KEY"]
    url     = "https://openrouter.ai/api/v1/chat/completions"
    dry_run = get(kwargs, :dry_run, false)
    think = get(kwargs, :think, 0)
    return make_api_request(llm, api_key, url, system_instruction, input_text, model, temperature, attach_file; dry_run=dry_run, think=think)
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
    think = get(kwargs, :think, 0)

    # For DeepSeek R1 models, use thinking budget as max_tokens if provided
    max_tokens = nothing
    if think != 0 && (occursin("r1", lowercase(model)) || occursin("deepseek-reasoner", lowercase(model)))
        max_tokens = think
    end

    return make_api_request(llm, api_key, url, system_instruction, input_text, model, temperature, attach_file; dry_run=dry_run, think=think, max_tokens=max_tokens)
end
