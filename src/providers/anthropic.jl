function call_llm(
    llm::AnthropicLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("anthropic"),
    temperature::Float64 = get_default_temperature(),
    attach_file = "";
    kwargs...
)
    think = get(kwargs, :think, ThinkNone)
    dry_run = get(kwargs, :dry_run, false)
    @debug "Making API request" llm system_instruction input_text model temperature attach_file think

    api_key = ENV["ANTHROPIC_API_KEY"]
    url     = "https://api.anthropic.com/v1/messages"

    headers = [
        "content-type"       => "application/json",
        "anthropic-version"  => "2023-06-01",
        "x-api-key"          => "$api_key",
    ]

    text_data = Dict("type" => "text", "text" => input_text)
    content   = attach_file != "" ? [text_data, encode_file_to_base64(llm, attach_file)] : [text_data]

    data = Dict(
        "model"       => model,
        "max_tokens"  => 4096,
        "temperature" => temperature,
        "messages"    => [ Dict("role" => "user", "content" => content) ],
    )

    if !isempty(system_instruction)
        data["system"] = system_instruction
    end

    if is_anthropic_thinking_model(model) && think != ThinkNone
        thinking_budget = if think == ThinkMinimal
            1024
        elseif think == ThinkMedium
            2048
        elseif think == ThinkHigh
            4096
        elseif think == ThinkAutomatic
            1024 # Sensible default
        else
            0 # Should not happen with validation
        end
        
        if thinking_budget > 0
            @debug "Adding thinking budget to Anthropic request" thinking_budget
            data["thinking"] = Dict("type" => "enabled", "budget_tokens" => thinking_budget)
            data["max_tokens"] = ceil(Int, thinking_budget * 1.25)
            data["temperature"] = 1.0
        end
    end

    schema_content_raw = get(kwargs, :schema_content, "")
    if !isempty(schema_content_raw)
        if !is_anthropic_schema_model(model)
            error("The model '$model' does not support structured outputs (JSON schema).")
        end
        push!(headers, "anthropic-beta" => "structured-outputs-2025-11-13")
        schema_parsed = try
            JSON.parse(schema_content_raw)
        catch e
            error("Failed to parse schema content: $e")
        end
        
        final_schema = if haskey(schema_parsed, "schema")
            schema_parsed["schema"]
        else
            schema_parsed
        end

        data["output_format"] = Dict("type" => "json_schema", "schema" => final_schema)
    end

    if dry_run
        return JSON.json(Dict("headers" => headers, "data" => data))
    end

    response = post_request(url, headers, data)

    try
        response_data = JSON.parse(String(response.body))
        content_array = get(response_data, "content", [])

        if !isempty(schema_content_raw)
            text_element_index = findfirst(item -> get(item, "type", "") == "text", content_array)
            if !isnothing(text_element_index)
                json_string = get(content_array[text_element_index], "text", "")
                return JSON.json(JSON.parse(json_string))
            else
                throw(ErrorException("No text content found in Anthropic response when schema was requested"))
            end
        end

        text_element_index = findfirst(item -> get(item, "type", "") == "text", content_array)
        if !isnothing(text_element_index)
            return get(content_array[text_element_index], "text", "")
        else
            if !isempty(content_array) && haskey(content_array[1], "text")
                @warn "Falling back to first content element's text"
                return content_array[1]["text"]
            end
            throw(ErrorException("No text content found in Anthropic response"))
        end
    catch error
        @debug "Failed to parse or process Anthropic JSON response" error=error body=String(response.body)
        throw(ErrorException("Invalid or unexpected JSON response format from Anthropic: $(String(response.body))"))
    end
end

