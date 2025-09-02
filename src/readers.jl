"""
    jina_reader(url)

Convert web page to markdown with the Jina reader service.
"""
function jina_reader(url)
    request_url = "https://r.jina.ai/$url"
    api_key = ENV["JINA_API_KEY"]
    headers = ["Authorization" => "Bearer $api_key"]
    response = HTTP.request("GET", request_url, headers, proxy = get(ENV, "http_proxy", ""))
    return String(response.body)
end

"""
    pandoc_reader(url)

Fetch content from URL and convert HTML to Markdown via Pandoc.
"""
function pandoc_reader(url::String)
    response = HTTP.get(url)
    content = String(response.body)
    c = Pandoc.Converter(input = content)
    c.from = "html"
    c.to = "markdown"
    return String(run(c))
end

