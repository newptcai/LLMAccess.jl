#!/usr/bin/env -S julia -O 0 --compile=min --startup-file=no --project=@script

using LLMAccess
using ArgParse

is_heading_line(line::AbstractString) = !isempty(line) && startswith(lstrip(line), "#")

function is_table_line(line::AbstractString)
    stripped = strip(line)
    return !isempty(stripped) && startswith(stripped, "|") && count(==('|'), stripped) >= 2
end

function ensure_heading_spacing(lines::Vector{String})
    result = String[]
    last_index = length(lines)
    for (idx, line) in enumerate(lines)
        if is_heading_line(line)
            if !isempty(result) && !isempty(strip(result[end]))
                push!(result, "")
            end
        end

        push!(result, line)

        if is_heading_line(line)
            needs_gap = idx == last_index || !isempty(strip(lines[idx + 1]))
            needs_gap && push!(result, "")
        end
    end
    return result
end

function ensure_table_spacing(lines::Vector{String})
    i = 1
    while i <= length(lines)
        if is_table_line(lines[i])
            start_idx = i
            if start_idx == 1 || !isempty(strip(lines[start_idx - 1]))
                insert!(lines, start_idx, "")
                start_idx += 1
                i += 1
            end

            end_idx = start_idx
            while end_idx <= length(lines) && is_table_line(lines[end_idx])
                end_idx += 1
            end
            end_idx -= 1

            if end_idx == length(lines) || !isempty(strip(lines[end_idx + 1]))
                insert!(lines, end_idx + 1, "")
            end
            i = end_idx + 2
        else
            i += 1
        end
    end
    return lines
end

function postprocess_markdown(text::AbstractString)
    lines = split(text, '\n'; keepempty=true)
    lines = ensure_heading_spacing(String.(lines))
    lines = ensure_table_spacing(lines)
    return join(lines, '\n')
end

function main(_)
    system_instruction = """
    You convert visual documents into clean Markdown.
    Strip headers/footers when obvious, preserve tables, and avoid commentary.
    """

    user_prompt = """
    Please OCR the attached image/PDF and return Markdown only.
    Do not add explanations or extra narration.
    """

    custom_settings = ArgParseSettings(
        prog = "ocr.jl",
        description = "Use an LLM provider to OCR images or PDFs to Markdown.",
        epilog = """
        Examples:
          ./ocr.jl -a scan.pdf
          ./ocr.jl -a page.jpg --model mistral-ocr
        """,
        add_version = true,
        version = "v1.0.0",
        preformatted_description = true,
        preformatted_epilog = true,
    )

    @add_arg_table! custom_settings begin
        "--output", "-o"; help = "Write OCR result to this file instead of stdout"; metavar = "PATH"; default = ""
    end

    omitted = ["schema", "schema-file", "file", "input_text", "no_normalize"]
    run_cli_with_args(
        custom_settings;
        parser = settings -> parse_commandline(settings, "mistral", "mistral-ocr-latest"; require_input=false, omit_args=omitted),
    ) do args
        attachment = strip(String(get(args, "attachment", "")))
        if isempty(attachment)
            error("no attachment provided; pass --attachment <path> to OCR an image or PDF")
        end

        args["input_text"] = user_prompt
        result = call_llm(system_instruction, args)
        trimmed_text = replace(result, r"\s+$"m => "")
        processed_text = postprocess_markdown(trimmed_text)

        output_path = strip(String(get(args, "output", "")))
        if isempty(output_path)
            println(processed_text)
        else
            open(output_path, "w") do io
                write(io, processed_text)
                write(io, '\n')
            end
        end
        nothing
    end
end

@main
