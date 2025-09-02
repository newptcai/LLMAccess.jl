"""
    post_request(url, headers, payload)

Send an HTTP POST and return the response or throw an ErrorException with details.
"""
function post_request(url, headers, payload)
    response = nothing
    try
        @debug "Payload" payload
        temp = "/tmp/payload.jls"
        @debug "Saving payload to $temp"
        serialize(temp, payload)
        json_payload = JSON.json(payload)
        response = HTTP.request("POST", url, headers, json_payload; proxy=get(ENV, "http_proxy", ""), status_exception=false)
    catch http_error
        @debug "HTTP request error occurred" exception=(http_error, catch_backtrace())
        throw(ErrorException("HTTP request failed: $(http_error)"))
    end

    if 200 <= response.status < 300
        return response
    else
        api_error_message = ""
        try
            error_data = JSON.parse(String(response.body))
            if haskey(error_data, "error") && haskey(error_data["error"], "message")
                api_error_message = error_data["error"]["message"]
            elseif haskey(error_data, "message")
                api_error_message = error_data["message"]
            elseif haskey(error_data, "detail")
                api_error_message = error_data["detail"]
            else
                api_error_message = String(response.body)
            end
        catch
            api_error_message = String(response.body)
        end
        throw(ErrorException("HTTP request failed with status $(response.status): $(api_error_message)"))
    end
end

"""
    get_request(url, header=Dict())

Send an HTTP GET and return the response or throw an ErrorException with details.
"""
function get_request(url, header=Dict())
    response = nothing
    try
        @debug "Sending GET request to $url"
        response = HTTP.request("GET", url, header; proxy=get(ENV, "http_proxy", ""), status_exception=false)
    catch http_error
        @debug "HTTP GET request error occurred" exception=(http_error, catch_backtrace())
        throw(ErrorException("HTTP GET request failed: $(http_error)"))
    end

    if 200 <= response.status < 300
        return response
    else
        api_error_message = ""
        try
            error_data = JSON.parse(String(response.body))
            if haskey(error_data, "error") && haskey(error_data["error"], "message")
                api_error_message = error_data["error"]["message"]
            elseif haskey(error_data, "message")
                api_error_message = error_data["message"]
            elseif haskey(error_data, "detail")
                api_error_message = error_data["detail"]
            else
                api_error_message = String(response.body)
            end
        catch
            api_error_message = String(response.body)
        end
        throw(ErrorException("HTTP GET request failed with status $(response.status): $(api_error_message)"))
    end
end

"""
    handle_json_response(response, extraction_path)

Parse JSON body and extract nested value at `extraction_path`.
"""
function handle_json_response(response, extraction_path)
    try
        response_data = JSON.parse(String(response.body))
        extracted_data = get_nested(response_data, extraction_path)
        return extracted_data
    catch error
        if error isa KeyError
            @debug "Failed to extract data at path $extraction_path: $error"
            throw(ErrorException("Missing key in JSON response: $(error.key)"))
        else
            @debug "Failed to parse JSON response: $error"
            throw(ErrorException("Invalid JSON response: $(String(response.body))"))
        end
    end
end

"""
    extract_google_text(response::HTTP.Response)

Extract the first text part from Google Generative Language API response.
"""
function extract_google_text(response::HTTP.Response)
    try
        payload = JSON.parse(String(response.body))
        candidates = get(payload, "candidates", Any[])
        if isempty(candidates)
            throw(ErrorException("Google API returned no candidates: $(String(response.body))"))
        end
        candidate = candidates[1]
        content = get(candidate, "content", Dict{String,Any}())
        parts = get(content, "parts", Any[])
        for part in parts
            if haskey(part, "text") && !isempty(String(part["text"]))
                return String(part["text"])
            end
        end
        finish_reason = get(candidate, "finishReason", "UNKNOWN")
        prompt_fb = get(payload, "promptFeedback", nothing)
        if prompt_fb !== nothing
            block_reason = get(prompt_fb, "blockReason", "")
            throw(ErrorException("Google API did not return text (finishReason=$(finish_reason), blockReason=$(block_reason))"))
        end
        throw(ErrorException("Google API did not return text parts (finishReason=$(finish_reason)). Body: $(String(response.body))"))
    catch err
        if err isa ErrorException
            rethrow()
        else
            @debug "Failed to parse Google JSON response" error=err body=String(response.body)
            throw(ErrorException("Invalid or unexpected JSON response format from Google: $(String(response.body))"))
        end
    end
end

