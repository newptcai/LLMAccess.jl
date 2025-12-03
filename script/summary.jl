#!/usr/bin/env -S julia -O 0 --compile=min --startup-file=no --project=@script

using LLMAccess
using ArgParse
using InteractiveUtils: clipboard

function main(_)
    # Define the summarization instructions (later embedded into the user prompt)
    system_instruction = """
    You are an expert summarization assistant for math, CS, and technical content.

    Please:
    - Treat the entire user prompt as text that needs to be summarized.
    - Capture key ideas, structure, and conclusions while omitting tangents and fluff.
    - Highlight important data or constraints when present.
    - Output concise Pandoc-style Markdown; short bullet lists are welcome when clearer.
    - Return only the summary—no greetings, commentary, or code fences.
    """

    custom_settings = ArgParseSettings(
        prog = "summary.jl",
        description = "Use LLM to summarize text to concise Pandoc Markdown.",
        epilog = """
        Input: reads from stdin; if stdin is empty, uses the final positional argument as literal text. The -f/--file flag is not used by this tool. To process a file, pipe it (e.g., `cat file | ./summary.jl`).

        Profiles (use -p/--profile; each has one short alias and one full name):
          CSM (c / csm)           — default math/CS focus with neutral tone
          Buddhist (b / buddhist) — calm, compassionate, mindful summaries
          Poetic (p / poetic)     — luminous, imagery-aware phrasing
          Humour (h / humour)     — warm, lightly witty summaries
          Professor (prof / professor) — supportive academic framing
          Friendly (fr / friendly)    — relaxed, conversational recap
          Business (biz / business)   — concise executive summary tone

        Examples:
          echo "Long text to condense..." | ./summary.jl
          ./summary.jl "Summarize this paragraph"
          cat article.md | ./summary.jl -C "Call out risks and timelines" -p business
        """,
        add_version = true,
        version = "v1.1.0",
        preformatted_description = true,
        preformatted_epilog = true,
    )

    @add_arg_table! custom_settings begin
        "--context", "-C"
        help = "Optional focus or extra instruction for the summary."
        metavar = "DETAIL"
        default = ""
        "--profile", "-p"
        help = "Summary profile/tone (short/full: c/csm, b/buddhist, p/poetic, h/humour, prof/professor, fr/friendly, biz/business)."
        metavar = "PROFILE"
        default = "CSM"
    end

    omitted = ["file", "schema", "schema-file", "attachment"]
    run_cli_with_args(
        custom_settings;
        parser = settings -> parse_commandline(settings; omit_args=omitted)
    ) do args
        function normalize_profile(p)
            t = lowercase(String(p)) |> strip
            if t in ("c", "csm")
                return :csm
            elseif t in ("b", "buddhist")
                return :buddhist
            elseif t in ("p", "poetic")
                return :poetic
            elseif t in ("h", "humour")
                return :humour
            elseif t in ("prof", "professor")
                return :professor
            elseif t in ("fr", "friendly")
                return :friendly
            elseif t in ("biz", "business")
                return :business
            else
                return :csm
            end
        end

        prof = normalize_profile(get(args, "profile", "CSM"))

        profile_clause = begin
            if prof === :buddhist
                "\n    Profile: Buddhist (Thich Nhat Hanh).\n    Summaries should feel calm, compassionate, and mindful while remaining precise.\n    Use gentle, clear language; influence tone only via word choice—do not add or remove content.\n"
            elseif prof === :poetic
                "\n    Profile: Poetic (Mary Oliver).\n    Summaries may use spare, luminous phrasing or light nature-inflected imagery when suitable.\n    Keep sentences concise and grounded; influence tone only via word choice—avoid inventing details.\n"
            elseif prof === :humour
                "\n    Profile: Humour (John Green).\n    Summaries should be warm, lightly witty, and empathetic without sarcasm.\n    Maintain clarity first; influence tone only via word choice—do not alter the facts.\n"
            elseif prof === :professor
                "\n    Profile: Professor (supportive academic).\n    Summaries should guide a student, clarifying structure and implications in plain language.\n    Keep phrasing respectful and confidence-building; influence tone only via word choice.\n"
            elseif prof === :friendly
                "\n    Profile: Friendly (writing to a peer).\n    Summaries should sound relaxed and conversational with natural contractions while staying accurate.\n    Avoid slang that changes meaning; influence tone only via word choice.\n"
            elseif prof === :business
                "\n    Profile: Business (executive briefing).\n    Summaries should emphasize decisions, risks, and outcomes with concise, formal language.\n    Prefer unambiguous phrases; influence tone only via word choice.\n"
            else
                ""  # CSM default
            end
        end

        context_clause = ""
        if haskey(args, "context") && !isempty(strip(args["context"]))
            context_clause = "\n    Additionally, emphasize this focus: \n    '$(args["context"])'\n"
        end

        original = String(get(args, "input_text", ""))
        if isempty(strip(original))
            error("no input provided; pass text as an argument or pipe it via stdin")
        end

        instruction_user = """
        Instructions:
        $system_instruction$profile_clause$context_clause

        Text to summarize:

        $original

        """
        args["input_text"] = instruction_user

        result = call_llm("", args)

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
