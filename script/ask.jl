#!/usr/bin/env -S julia -O 0 --compile=min --startup-file=no --project=@script

using LLMAccess
using ArgParse
using Logging

function main(_)
    # Define the system prompt
    system_instruction = "Answer the above question concisely and do not suggest following up questions."

    custom_settings = ArgParseSettings(
        prog = "ask.jl",
        description = "Use LLM to answer simple question.",
        add_version = true,
        version = "v1.0.0",
    )

    # Delegate CLI plumbing + --debug handling to the shared helper.
    run_cli_with_args(custom_settings) do args
        # 1) Parse CLI args (provides defaults, reads stdin when needed, etc.)
        # 2) Validate input and prepend system instruction
        original = String(get(args, "input_text", ""))
        if isempty(strip(original))
            error("no input provided; pass a question as argument, pipe from stdin, or use -f/--file")
        end
        instruction_user = """
        Question:

        $original

        Instructions:
        $system_instruction
        """

        args["input_text"] = instruction_user
        result = call_llm("", args)
        result = replace(result, r"\s+$"m => "")

        print(result)
        print("\n")
        nothing
    end
end

@main
