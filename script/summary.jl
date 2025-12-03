#!/usr/bin/env -S julia -O 0 --compile=min --startup-file=no --project=@script

using LLMAccess
using ArgParse
using InteractiveUtils: clipboard

function main(_)
    # Define the system prompt
    system_instruction = """

    Please summarize the text given in the user prompt.
    - Treat the entire user prompt as text that needs to be summarized.
    - Be concise and focus on the main ideas; omit tangential details.
    - Ignore parts that are not relevant to the main content.
    - Output Pandoc-style Markdown.
    - Do not provide greetings, comments, or explanations. Return only the summary.
    """

    custom_settings = ArgParseSettings(
        prog = "summary.jl",
        description = "Use LLM to summarize text to concise Pandoc Markdown.",
        epilog = """
        Input: reads from stdin; if stdin is empty, uses the final positional argument as literal text. The -f/--file flag is not used by this tool. To process a file, pipe it (e.g., `cat file | ./summary.jl`).

        Examples:
          echo "Long text to condense..." | ./summary.jl
          ./summary.jl "Summarize this paragraph"
          cat article.md | ./summary.jl
        """,
        add_version = true,
        version = "v1.0.0",
        preformatted_description = true,
        preformatted_epilog = true,
    )

    run_cli_with_args(
        custom_settings;
        parser = settings -> parse_commandline(settings; omit_args=["file"])
    ) do args
        result = call_llm(system_instruction, args)

        # Use regex to remove trailing whitespace on each line (with multiline mode)
        trimmed_text = replace(result, r"\s+$"m => "")
        println(trimmed_text)
        try
            clipboard(trimmed_text)
        catch e
            println(stderr, "warning: failed to copy to clipboard: " * sprint(showerror, e))
        end
        nothing
    end
end

@main
