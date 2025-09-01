#!/usr/bin/env -S julia -O 0 --compile=min --startup-file=no --project=@script

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
        description = "Generate a bash command with LLM, copy it to clipboard, then optionally execute it after confirmation.",
        add_version = true,
        version = "v1.0.0"
    )

    # Optional: allow directly supplying a command (bypasses LLM), useful for offline/testing
    @add_arg_table! custom_settings begin
        "--cmd"; help = "Direct command to use instead of calling LLM"; metavar = "CMD"; default = ""
    end

    # Mirror ask.jl: delegate error handling and Ctrl+C to run_cli
    args_ref = Ref{Any}(nothing)
    run_cli(() -> begin
        # Avoid blocking for input when --cmd is provided (or in tests)
        args = parse_commandline(custom_settings; require_input = false)
        args_ref[] = args

        result = if isempty(strip(get(args, "cmd", "")))
            call_llm(system_instruction, args)
        else
            String(args["cmd"])
        end

        # Use regex to remove trailing whitespace on each line (with multiline mode)
        trimmed_text = replace(result, r"\s+$"m => "")
        println(trimmed_text)
        clipboard(trimmed_text)

        # Ask for confirmation before executing
        print("⚠️ Execute this command now? [y/N]: ")
        flush(stdout)
        reply = try
            readline(stdin)
        catch
            ""
        end
        ans = lowercase(strip(reply))
        if ans == "y" || ans == "yes"
            # Use bash -lc to support pipes, redirects, and multi-line commands
            run(Cmd(["bash", "-lc", "set -euo pipefail; " * trimmed_text]))
        end
        nothing
    end; settings=custom_settings,
         debug_getter=() -> begin
             a = args_ref[]
             a === nothing ? false : get(a, "debug", false)
         end)
end

@main
