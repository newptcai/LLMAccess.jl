function call_llm(
    llm::MistralLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("mistral"),
    temperature::Float64 = get_default_temperature(),
    attach_file = "";
    kwargs...
)
    @debug "Making API request" llm system_instruction input_text model temperature attach_file
    dry_run = get(kwargs, :dry_run, false)

    api_key = ENV["MISTRAL_API_KEY"]
    url     = "https://api.mistral.ai/v1/chat/completions"
    headers = [
        "Content-Type"  => "application/json",
        "Accept"        => "application/json",
        "Authorization" => "Bearer $api_key",
    ]

    user_content = if isempty(attach_file)
        input_text
    else
        text_data = Dict("type" => "text", "text" => input_text)
        [text_data, encode_file_to_base64(llm, attach_file)]
    end

    messages = []
    if !isempty(system_instruction)
        push!(messages, Dict("role" => "system", "content" => system_instruction))
    end
    push!(messages, Dict("role" => "user", "content" => user_content))

    data = Dict(
        "model"       => model,
        "temperature" => temperature,
        "messages"    => messages,
    )

    if dry_run
        return JSON.json(data)
    end

    response = post_request(url, headers, data)
    return handle_json_response(response, ["choices", 1, "message", "content"])
end

