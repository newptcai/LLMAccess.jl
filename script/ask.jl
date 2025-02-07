#!/usr/bin/env -S julia -O 0 --compile=min --project="${SRC_DIR}/bin/"

using LLMAccess
using ArgParse

function main()
    # Define the system prompt
    system_instruction = """
    Please answer user question as truthfuly as possible.
    Be concise with your answer.
    """

    custom_settings = ArgParseSettings(
        description = "Use LLM to answer simple question.",
        add_version = true,
        version = "v1.0.0",
    )

    args = parse_commandline(custom_settings)

    result = call_llm(
        system_instruction,
        args
    )

    if args["debug"]
        println("LLM output: ...")
    end

    if result !== nothing
        print(result)
        if result[end] != "\n"
            print("\n")
        end
        exit(0)
    else
        @error "Failed to get a valid response from the server."
        exit(1)
    end
end

main()
