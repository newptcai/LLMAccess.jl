#!/usr/bin/env -S julia -O 0 --compile=min --project="${SRC_DIR}/bin/"

using LLMAccess
using ArgParse
using InteractiveUtils: clipboard

function main(_)
    # Define the system prompt
    system_instruction = """
    You are an assistant designed to generate Linux bash commands.
    Your goal is to provide precise,
    valid commands that solve a given task efficiently.
    Your responses should be concise,
    output only the necessary bash commands without explanations.
    Be mindful of the use of piping, redirection, and appropriate flags.
    Commands should work in a typical Unix environment.
    Absolutely do not put the command in codeblocks.

    Examples:

    1. **Input:** List all files in the current directory that were modified in the last 7 days.
    **Response:**
    find . -type f -mtime -7

    2. **Input:** Create a symbolic link for the file `/path/to/source/file.txt` in the `/path/to/destination/` directory.
    **Response:**
    ln -s /path/to/source/file.txt /path/to/destination/
    """

    custom_settings = ArgParseSettings(
        prog = "cmd.jl",
        description = "Use LLM to generate command line.",
        add_version = true,
        version = "v1.0.0"
    )

    args = parse_commandline(custom_settings)

    try
        result = call_llm(
            system_instruction,
            args
        )

        # Use regex to remove trailing whitespace on each line (with multiline mode)
        trimmed_text = replace(result, r"\s+$"m => "")
        println(trimmed_text)
        clipboard(trimmed_text)
        exit(0)
    catch err
        @error "Command generation failed" exception=(err, catch_backtrace())
        exit(1)
    end
end

@main
