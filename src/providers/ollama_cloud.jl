function call_llm(
    llm::OllamaCloudLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("ollama_cloud"),
    temperature::Float64 = get_default_temperature(),
    attach_file = "";
    kwargs...
)
    dry_run = get(kwargs, :dry_run, false)
    think = get(kwargs, :think, nothing)
    if think !== nothing && think != 0
        @debug "Ignoring think parameter for Ollama Cloud" think
    end

    if !isempty(attach_file)
        throw(ArgumentError("Attachments are not currently supported for Ollama Cloud."))
    end

    @debug "Making Ollama Cloud request" llm system_instruction input_text model temperature

    api_key = ENV["OLLAMA_API_KEY"]
    url = "https://ollama.com/api/chat"
    headers = [
        "Content-Type" => "application/json",
        "Authorization" => "Bearer $api_key",
    ]

    messages = Vector{Dict{String, Any}}()
    if !isempty(system_instruction)
        push!(messages, Dict("role" => "system", "content" => String(system_instruction)))
    end
    push!(messages, Dict("role" => "user", "content" => String(input_text)))

    payload = Dict{String, Any}(
        "model" => model,
        "messages" => messages,
        "stream" => false,
        "options" => Dict("temperature" => temperature),
    )

    if dry_run
        return JSON.json(payload)
    end

    response = post_request(url, headers, payload)
    body = JSON.parse(String(response.body))
    convert_to_text(value) = value isa AbstractString ? String(value) : JSON.json(value)

    message = get(body, "message", nothing)
    if message isa AbstractDict
        content = get(message, "content", nothing)
        if content !== nothing
            return convert_to_text(content)
        end
    end

    response_field = get(body, "response", nothing)
    if response_field !== nothing
        return convert_to_text(response_field)
    end

    messages_field = get(body, "messages", nothing)
    if messages_field isa AbstractVector && !isempty(messages_field)
        last_msg = messages_field[end]
        if last_msg isa AbstractDict
            content = get(last_msg, "content", nothing)
            if content !== nothing
                return convert_to_text(content)
            end
        end
    end

    choices = get(body, "choices", nothing)
    if choices isa AbstractVector && !isempty(choices)
        first_choice = choices[1]
        if first_choice isa AbstractDict
            msg = get(first_choice, "message", nothing)
            if msg isa AbstractDict
                content = get(msg, "content", nothing)
                if content !== nothing
                    return convert_to_text(content)
                end
            end
            direct_content = get(first_choice, "content", nothing)
            if direct_content !== nothing
                return convert_to_text(direct_content)
            end
        elseif first_choice !== nothing
            return convert_to_text(first_choice)
        end
    end

    throw(ErrorException("Unexpected response format from Ollama Cloud: $(String(response.body))"))
end
