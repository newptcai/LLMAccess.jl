#!/usr/bin/env -S julia -O 0 --compile=min --project="${SRC_DIR}/bin/"

using LLMAccess
using ArgParse

function main(_)
    # Define the system prompt
    system_instruction = ""

    custom_settings = ArgParseSettings(
        prog = "ask.jl",
        description = "Use LLM to answer simple question.",
        add_version = true,
        version = "v1.0.0",
    )

    args = parse_commandline(custom_settings)

    try
        result = call_llm(
            system_instruction,
            args
        )

        print(result)
        if result[end] != '\n'
            print("\n")
        end
        exit(0)
    catch err
        @error "Operation failed" exception=(err, catch_backtrace())
        exit(1)
    end
end

@main
