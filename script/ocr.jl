#!/usr/bin/env -S julia -O 0 --compile=min --startup-file=no --project=@script

using LLMAccess
using ArgParse

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
        parser = settings -> parse_commandline(settings; require_input=false, omit_args=omitted),
    ) do args
        attachment = strip(String(get(args, "attachment", "")))
        if isempty(attachment)
            error("no attachment provided; pass --attachment <path> to OCR an image or PDF")
        end

        args["input_text"] = user_prompt
        result = call_llm(system_instruction, args)
        trimmed_text = replace(result, r"\s+$"m => "")

        output_path = strip(String(get(args, "output", "")))
        if isempty(output_path)
            println(trimmed_text)
        else
            open(output_path, "w") do io
                write(io, trimmed_text)
                write(io, '\n')
            end
        end
        nothing
    end
end

@main
