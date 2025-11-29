#!/usr/bin/env -S julia -O 0 --compile=min --startup-file=no --project=@script

using LLMAccess
using ArgParse

const WRITER_SHORTCUTS = Dict(
    "tnh" => "Thich Nhat Hanh",
    "jg" => "John Green",
    "mo" => "Mary Oliver",
    "ps" => "Peter Singer",
    "pc" => "Pema Chodron",
    "al" => "Ada Limon",
    "esm" => "Emily St. John Mandel",
    "mg" => "Mahatma Gandhi",
    "tb" => "Tara Brach",
    "jk" => "Jack Kornfield",
    "bh" => "bell hooks",
    "ds" => "David Sedaris",
    "bb" => "Bill Bryson",
    "ynh" => "Yuval Noah Harari",
    "vw" => "Virginia Woolf",
    "hm" => "Haruki Murakami",
    "ng" => "Neil Gaiman",
    "tm" => "Toni Morrison",
    "sk" => "Stephen King",
    "dm" => "David McCullough",
    "at" => "Adrian Tchaikovsky",
)

function main(_)
    custom_settings = ArgParseSettings(
        prog = "writer.jl",
        description = "Use LLM to revise the text in the style of a specified writer.",
        epilog = """
        Input: reads from stdin; if stdin is empty, uses the final positional argument as literal text. The -f/--file flag is not used by this tool. To process a file, pipe it (e.g., `cat file | ./writer.jl`).

        Examples:
          echo "Rewrite this paragraph." | ./writer.jl -w "Ursula K. Le Guin" -S "lyrical, clear"
          ./writer.jl -w tnh "make this calmer and kinder"
          cat draft.txt | ./writer.jl -w mg

        Shorthands:
          tnh  -> Thich Nhat Hanh
          jg   -> John Green
          mo   -> Mary Oliver
          ps   -> Peter Singer
          pc   -> Pema Chodron
          al   -> Ada Limon
          esm  -> Emily St. John Mandel
          mg   -> Mahatma Gandhi
          tb   -> Tara Brach
          jk   -> Jack Kornfield
          bh   -> bell hooks
          ds   -> David Sedaris
          bb   -> Bill Bryson
          ynh  -> Yuval Noah Harari
          vw   -> Virginia Woolf
          hm   -> Haruki Murakami
          ng   -> Neil Gaiman
          tm   -> Toni Morrison
          sk   -> Stephen King
          dm   -> David McCullough
          at   -> Adrian Tchaikovsky
        """,
        add_version = true,
        version = "v1.0.0",
        preformatted_description = true,
        preformatted_epilog = true,
    )

    @add_arg_table! custom_settings begin
        "--writer", "-w"
        help = "The voice of the writer to use (see Shorthands in --help)."
        default = "Thich Nhat Hanh"
        "--style", "-S"
        help = "The writing style to use"
        default = "concise, poetic, and philosopical"
    end

    omitted = ["file", "schema", "schema-file", "attachment"]
    run_cli_with_args(
        custom_settings;
        parser = settings -> parse_commandline(settings; omit_args=omitted),
    ) do args
        writer = String(args["writer"])
        writer_key = lowercase(strip(writer))
        writer = get(WRITER_SHORTCUTS, writer_key, writer)
        style = String(args["style"])

        # Define the system prompt
        system_instruction = """
        You are the world-class writer $writer.

        Please:
        - Enhance the text given as user prompt with your ($writer's)
          typical tone with a $style style.
        - Limit the length of response to about the same as original text.
        - Add line breaks after punctuation marks such as periods or commas,
          or at logical conjunctions.
        - Insert an empty line between each paragraph.
        - Correct all English grammar mistakes, typos, and word choices in the text.
        - Do not provide greetings, comments, or explanations.
        - Replace American spellings and words with British spellings and words.
        """

        result = call_llm(system_instruction, args)

        # Use regex to remove trailing whitespace on each line (with multiline mode)
        trimmed_text = replace(result, r"\s+$"m => "")
        print(trimmed_text)
        print("\n")
        nothing
    end
end

@main
