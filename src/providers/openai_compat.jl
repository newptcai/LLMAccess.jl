"""
    call_llm(llm::AbstractLLM; kwargs...)

Abstract method for provider call. Implemented per-concrete type.
"""
function call_llm(llm::AbstractLLM; kwargs...)
    error("Not implemented for $(typeof(llm))")
end

"""
    make_api_request(llm, api_key, url, system_instruction, input_text, model, temperature, attach_file; dry_run=false)

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
    dry_run::Bool = false
)
    @debug "Making API request" llm system_instruction input_text model temperature attach_file
    headers = [
        "Content-Type" => "application/json",
        "Authorization" => "Bearer $api_key",
    ]
    text_data = Dict("type" => "text", "text" => input_text)
    content = attach_file != "" ? [text_data, encode_file_to_base64(llm, attach_file)] : [text_data]
    user_message   = Dict("role" => "user", "content" => content)
    system_message = Dict("role" => "system", "content" => system_instruction)
    messages = [user_message]
    if !isempty(system_instruction)
        push!(messages, system_message)
    end
    data = Dict("model" => model, "temperature" => temperature, "messages" => messages)
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
    return make_api_request(llm, api_key, url, system_instruction, input_text, model, temperature, attach_file; dry_run=dry_run)
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
    return make_api_request(llm, api_key, url, system_instruction, input_text, model, temperature, attach_file; dry_run=dry_run)
end

# Groq (OpenAI-compatible, with small tweak)
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
    url     = "https://api.groq.com/openai/v1/chat/completions"
    sys_instruction = attach_file != "" ? "" : system_instruction
    dry_run = get(kwargs, :dry_run, false)
    return make_api_request(llm, api_key, url, sys_instruction, input_text, model, temperature, attach_file; dry_run=dry_run)
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
    return make_api_request(llm, api_key, url, system_instruction, input_text, model, temperature, attach_file; dry_run=dry_run)
end

# Z.ai (OpenAI-compatible)
function call_llm(
    llm::ZaiLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("zai"),
    temperature::Float64 = get_default_temperature(),
    attach_file = "";
    kwargs...
)
    api_key = ENV["Z_API_KEY"]
    url     = "https://api.z.ai/api/paas/v4/chat/completions"
    dry_run = get(kwargs, :dry_run, false)
    # Normalize OpenRouter-style aliases like "z-ai/glm-4.5" back to model id
    normalized_model = occursin("/", model) ? split(model, "/")[end] : model
    return make_api_request(llm, api_key, url, system_instruction, input_text, normalized_model, temperature, attach_file; dry_run=dry_run)
end
