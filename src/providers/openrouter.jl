"""
    call_llm(llm::OpenRouterLLM; kwargs...)

Make a request to OpenRouter's API and return the response text.
"""
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
    schema_content = get(kwargs, :schema_content, "")

    @debug "Making OpenRouter API request" system_instruction input_text model temperature attach_file think schema_content

    current_input_text = input_text

    headers = [
        "Content-Type" => "application/json",
        "Authorization" => "Bearer $api_key",
        "HTTP-Referer" => "https://github.com/newptcai/llmaccess.jl",
        "X-Title" => "LLMAccess.jl"
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

    # Handle schema if provided
    if !isempty(schema_content)
        schema_parsed = try
            JSON.parse(schema_content)
        catch e
            error("Failed to parse schema content: $e")
        end
        data["response_format"] = Dict("type" => "json_schema", "json_schema" => schema_parsed)
    end

    # Handle OpenRouter reasoning configuration
    if think > 0
        reasoning_config = Dict()

        # Set max_tokens for reasoning (Anthropic-style)
        reasoning_config["max_tokens"] = think * 1000  # Convert think level to tokens

        # Set effort level (OpenAI-style)
        effort = think == 1 ? "minimal" :
                 think == 2 ? "low" :
                 think == 3 ? "medium" : "high"
        reasoning_config["effort"] = effort

        # Enable reasoning
        reasoning_config["enabled"] = true
        reasoning_config["exclude"] = false  # Include reasoning tokens in response

        data["reasoning"] = reasoning_config
        @debug "Setting OpenRouter reasoning configuration" reasoning_config think
    end

    if dry_run
        return JSON.json(data)
    end
    response = post_request(url, headers, data)
    return handle_json_response(response, ["choices", 1, "message", "content"])
end