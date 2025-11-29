function call_llm(
    llm::MistralLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("mistral"),
    temperature::Float64 = get_default_temperature(),
    attach_file = "";
    kwargs...
)
    think = get(kwargs, :think, ThinkNone)
    if think != ThinkNone && !occursin("magistral", lowercase(model))
        error("The selected Mistral model '$model' does not support thinking. Only 'magistral-...' models do. Use --think 0 or choose a different model.")
    end

    @debug "Making API request" llm system_instruction input_text model temperature attach_file
    dry_run = get(kwargs, :dry_run, false)

    api_key = ENV["MISTRAL_API_KEY"]
    headers = [
        "Content-Type"  => "application/json",
        "Accept"        => "application/json",
        "Authorization" => "Bearer $api_key",
    ]

    # Special handling for OCR models that use a different endpoint and payload shape.
    if startswith(lowercase(model), "mistral-ocr")
        return handle_mistral_ocr_request(model, attach_file, dry_run, headers)
    end

    # Default chat/completions path (supports multimodal via OpenAI-compatible payload)
    url     = "https://api.mistral.ai/v1/chat/completions"

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

    if think != ThinkNone && occursin("magistral", lowercase(model))
        @debug "Enabling reasoning mode for Magistral model"
        data["prompt_mode"] = "reasoning"
    end

    schema_content_raw = get(kwargs, :schema_content, "")
    if !isempty(schema_content_raw)
        schema_content = try
            JSON.parse(schema_content_raw)
        catch e
            error("Failed to parse schema content: $e")
        end

        # Mistral requires specific structure for json_schema: {name, schema, strict}
        # If the provided content looks like a raw schema (has "type" or "properties"), wrap it.
        formatted_schema = if !haskey(schema_content, "schema") && (haskey(schema_content, "type") || haskey(schema_content, "properties"))
             Dict(
                "name" => "output_schema",
                "schema" => schema_content,
                "strict" => true
            )
        else
            schema_content
        end

        data["response_format"] = Dict("type" => "json_schema", "json_schema" => formatted_schema)
    end

    if dry_run
        return JSON.json(data)
    end

    response = post_request(url, headers, data)
    return handle_json_response(response, ["choices", 1, "message", "content"])
end

function handle_mistral_ocr_request(model, attach_file, dry_run, headers)
    if isempty(attach_file)
        error("mistral-ocr models require an attachment. Provide --attachment <image path>.")
    end

    # Build OCR payload per Mistral API, switching between image/document inputs automatically.
    mime_type, b64 = encode_file_to_base64(attach_file)
    mime_string = string(mime_type)
    data_url = "data:$(mime_string);base64,$b64"
    is_image = startswith(lowercase(mime_string), "image/")
    document_payload = if is_image
        Dict(
            "type" => "image_url",
            "image_url" => data_url,
        )
    else
        Dict(
            "type" => "document_url",
            "document_url" => data_url,
        )
    end

    url = "https://api.mistral.ai/v1/ocr"
    data = Dict(
        "model" => model,
        "document" => document_payload,
        # Provide image bytes in response to simplify offline inspection.
        "include_image_base64" => true,
    )

    if dry_run
        return JSON.json(data)
    end

    response = post_request(url, headers, data)
    return parse_mistral_ocr_response(response)
end

function parse_mistral_ocr_response(response)
    # Try to extract text robustly; fallback to raw JSON if structure is unknown.
    try
        payload = JSON.parse(String(response.body))
        if haskey(payload, "text") && !isempty(String(payload["text"]))
            return String(payload["text"])  # common field name
        end
        if haskey(payload, "ocr_text") && !isempty(String(payload["ocr_text"]))
            return String(payload["ocr_text"])  # alternate field name
        end
        if haskey(payload, "result") && !isempty(String(payload["result"]))
            return String(payload["result"])  # generic field name
        end
        if haskey(payload, "markdown") && !isempty(String(payload["markdown"]))
            return String(payload["markdown"])  # top-level markdown if provided
        end
        if haskey(payload, "pages") && payload["pages"] isa AbstractVector
            # Concatenate page-level text if present
            page_texts = String[]
            for page in payload["pages"]
                if page isa AbstractDict
                    if haskey(page, "markdown") && !isempty(String(page["markdown"]))
                        push!(page_texts, String(page["markdown"]))
                        continue
                    end
                    if haskey(page, "text")
                        push!(page_texts, String(page["text"]))
                    elseif haskey(page, "ocr_text")
                        push!(page_texts, String(page["ocr_text"]))
                    end
                end
            end
            if !isempty(page_texts)
                return join(page_texts, "\n\n")
            end
        end
        # Unknown structure: return compact JSON for visibility
        return JSON.json(payload)
    catch
        # As a last resort, return raw body
        return String(response.body)
    end
end
