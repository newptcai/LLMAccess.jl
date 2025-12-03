#!/usr/bin/env -S julia -O 0 --compile=min --startup-file=no --project=@script

using LLMAccess
using ArgParse
using InteractiveUtils: clipboard

function main(_)
    # Define the system prompt
    system_instruction = """
    You are a world-class expert in mathematics and computer science.

    Please:
    Treat the entire user prompt as text that needs to be corrected.
    Correct all English grammar mistakes, typos, and word choices in the text.
    Replace American spellings and words with Canadian spellings and words.
    Make the language clearer and more professional.
    Return only the corrected text.
    Insert one empty line between each paragraphs.
    Do not provide greetings, comments, or explanations.
    Do not wrap the output in code blocks or fences (no ```).
    Do not replace placeholders.
    Add linebreaks after punctuation marks such as periods or commas.
    Do not change line indentation.
    Do not change any LaTeX commands.
    Do not change file names.
    Use --- instead of : whenever possible, unless it's an emoji like :bulb:
    """

    custom_settings = ArgParseSettings(
        prog = "fix.jl",
        description = "Fix and optionally modify math/CS text (preserves LaTeX, placeholders, filenames).",
        epilog = """
        Input: reads from stdin; if stdin is empty, uses the final positional argument as literal text. The -f/--file flag is not used by this tool. To process a file, pipe it (e.g., `cat file | ./fix.jl`).

        Examples:

        Basic fix from stdin:
          echo "Teh algoritm is fast" | ./fix.jl

        Apply a specific change:
          echo "We denote complexity O(n^2)" | ./fix.jl -C "Use inline LaTeX math for all symbols and complexity notations"

        Another targeted tweak (with inline input text):
          ./fix.jl -C "Replace the term 'iff' with 'if and only if'" "A iff B."

        From a file via pipe:
          cat notes.tex | ./fix.jl -C "Prefer 'runtime' over 'run time'"

        Profiles (use -p/--profile; short-hands in parentheses):
          CSM (c, cs, csm)        — default math/CS focus
          Buddhist (b, tnh)       — Thich Nhat Hanh: calm, compassionate, mindful
          Poetic (p, mo)          — Mary Oliver: spare, luminous, nature-inflected
          Humour (h, humor, jg)   — John Green: warm, witty, lightly self-aware
          Professor (prof, instructor, teacher, course) — respectful, supportive academic tone
          Friendly (friend, friendly, casual, warm)     — warm, relaxed, conversational (with contractions)
          Business (biz, business, corporate, formal)   — concise, formal, professional

        Examples with profiles:
          echo "Teh algoritm is fast" | ./fix.jl -p b
          echo "note about limits"    | ./fix.jl -p poetic
          echo "intro paragraph"       | ./fix.jl -p h -C "Prefer contractions"
          echo "assignment note"       | ./fix.jl -p prof
          echo "quick update"          | ./fix.jl -p friend
          echo "client email"          | ./fix.jl -p business

        Note: The instruction is embedded into the user message; no separate system prompt is sent.
        """,
        add_version = true,
        version = "v1.4.0",
        preformatted_description = true,
        preformatted_epilog = true,
    )

    @add_arg_table! custom_settings begin
        "--context", "-C"
        help = "Describe a specific change to apply (natural language)."
        metavar = "MODIFY"
        default = ""
        "--profile", "-p"
        help = "Editing profile/tone (short-hands: c/csm, b/tnh, p/poetic/mo, h/humor/jg, prof, friend, business)."
        metavar = "PROFILE"
        default = "CSM"
    end

    omitted = ["file", "schema", "schema-file", "attachment"]
    run_cli_with_args(
        custom_settings;
        parser = settings -> parse_commandline(settings; omit_args=omitted),
    ) do args
        function normalize_profile(p)
            t = lowercase(String(p)) |> strip
            if t in ("c", "cs", "csm", "default", "std")
                return :csm
            elseif t in ("b", "tnh", "buddha", "buddhist", "mindful", "zen")
                return :buddhist
            elseif t in ("p", "poet", "poetic", "mo", "oliver", "mary-oliver", "mary")
                return :poetic
            elseif t in ("h", "humour", "humor", "jg", "john-green", "green", "john")
                return :humour
            elseif t in ("prof", "professor", "instructor", "teacher", "course", "uni", "academic")
                return :professor
            elseif t in ("friend", "friends", "friendly", "casual", "warm", "informal")
                return :friendly
            elseif t in ("biz", "business", "corporate", "professional", "formal", "office")
                return :business
            else
                return :csm
            end
        end

        prof = normalize_profile(get(args, "profile", "CSM"))

        # Profile-specific guidance (nudge word choice only; preserve content and structure)
        profile_clause = begin
            if prof === :buddhist
                "\n    Profile: Buddhist (Thich Nhat Hanh).\n    Nudge wording toward a calm, compassionate, mindful tone with gentle simplicity and non-judgmental clarity.\n    Use plain, concise sentences and avoid religious jargon. Influence tone only via word choice—do not add or remove content.\n"
            elseif prof === :poetic
                "\n    Profile: Poetic (Mary Oliver).\n    Nudge wording toward spare, luminous clarity with a light, nature-inflected lyricism when appropriate.\n    Keep language direct and grounded; influence tone only via word choice—do not add or remove content.\n"
            elseif prof === :humour
                "\n    Profile: Humour (John Green).\n    Nudge wording toward warm, witty, lightly self-aware phrasing while remaining professional and concise.\n    Avoid sarcasm or snark; influence tone only via word choice—do not add or remove content.\n"
            elseif prof === :professor
                "\n    Profile: Professor (writing to university students).\n    Nudge wording toward a respectful, supportive instructional tone that reduces anxiety and clarifies expectations.\n    Keep sentences concise and approachable; minimize jargon or briefly clarify terms. Influence tone only via word choice—do not add or remove content.\n"
            elseif prof === :friendly
                "\n    Profile: Friendly (writing to a friend).\n    Nudge wording toward a warm, relaxed, conversational tone with natural contractions while staying courteous and clear.\n    Avoid slang that changes meaning; influence tone only via word choice—do not add or remove content.\n"
            elseif prof === :business
                "\n    Profile: Business (professional).\n    Nudge wording toward a concise, formal business tone suitable for emails, memos, and reports.\n    Prefer precise, unambiguous phrasing; avoid idioms and humour; influence tone only via word choice—do not add or remove content.\n"
            else
                ""  # CSM default: the base instruction already targets math/CS
            end
        end

        # If -C/--context is provided, instruct the model to apply the targeted change as well.
        context_clause = ""
        if haskey(args, "context") && !isempty(strip(args["context"]))
            context_clause = "\n    Additionally, apply this targeted change to the text: \n    '$(args["context"])'\n"
        end

        # Incorporate profile guidance and any targeted modification into the instruction.
        sys_with_mod = string(system_instruction, profile_clause, context_clause)

        # Always fold the instruction into the user content; call with empty system prompt
        original = String(get(args, "input_text", ""))
        instruction_user = """
        Instructions:
        $sys_with_mod

        Text to fix:
        
        $original

        """
        args["input_text"] = instruction_user
        result = call_llm("", args)

        println(result)
        try
            clipboard(result)
        catch e
            println(stderr, "warning: failed to copy to clipboard: " * sprint(showerror, e))
        end
        nothing
    end
end

@main
