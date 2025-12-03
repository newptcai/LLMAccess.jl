#!/usr/bin/env -S julia -O 0 --compile=min --startup-file=no --project=@script

using LLMAccess
using ArgParse
using JSON

const DEF_MAX_DEFINITIONS = 3
const CACHE_FILENAME = "word-cache.json"

const IPA_REPLACEMENTS = (
    "ɹ" => "r",
    "ɾ" => "r",
    "ɫ" => "l",
    "ɡ" => "g",
    "ɐ" => "ə",
    "ɘ" => "ə",
    "ᵻ" => "ɪ",
    "əʊ" => "oʊ",
    "əː" => "ɜː",
)

const POS_LABELS = Dict(
    "n" => "noun",
    "v" => "verb",
    "a" => "adjective",
    "s" => "adjective",
    "r" => "adverb",
    "p" => "adjective",
    "adj" => "adjective",
    "adv" => "adverb",
)

function load_cache(cache_file::String)
    if isfile(cache_file)
        return JSON.parsefile(cache_file)
    else
        return Dict{String, Any}()
    end
end

function save_cache(cache_file::String, cache_dict)
    open(cache_file, "w") do f
        JSON.print(f, cache_dict, 4)
    end
end

function normalize_ipa_symbols(ipa::AbstractString)
    normalized = ipa
    for (needle, replacement) in IPA_REPLACEMENTS
        normalized = replace(normalized, needle => replacement)
    end
    replace(normalized, r"\s+" => " ")
end

function phonetic_spelling(word_to_lookup::AbstractString)
    cmd = Cmd(["espeak-ng", "-v", "en-gb", "--ipa", "-q", word_to_lookup])
    try
        output = strip(read(cmd, String))
        output = normalize_ipa_symbols(output)
        return isempty(output) ? "" : output
    catch
        return ""
    end
end

function normalize_whitespace(str::AbstractString)
    replace(str, r"\s+" => " ")
end

function remove_empty_lines(str::AbstractString)
    lines = split(str, '\n'; keepempty = true)
    compact = String[]
    previous_blank = false
    for line in lines
        if isempty(strip(line))
            if !previous_blank
                push!(compact, "")
                previous_blank = true
            end
            continue
        end
        push!(compact, line)
        previous_blank = false
    end
    return join(compact, "\n")
end

function cache_entry_stale(text::AbstractString)
    occursin("From WordNet", text)
end

function format_entry(word_to_lookup, ipa, senses, _synonyms; max_defs = DEF_MAX_DEFINITIONS)
    _lines, width = displaysize(stdout)
    header = isempty(ipa) ? "$(word_to_lookup) ---" : "$(word_to_lookup) /$(ipa)/ ---"
    limited = max_defs >= length(senses) ? senses : senses[1:max_defs]
    output_lines = String[header]
    for (idx, sense) in enumerate(limited)
        label = get(POS_LABELS, sense.pos, lowercase(sense.pos))
        
        line_prefix = string(idx, ". (", label, "): ")
        line_content = sense.definition
        
        words = split(line_content, ' ')
        if !isempty(words)
            current_line = line_prefix * popfirst!(words)
            for word in words
                if length(current_line) + 1 + length(word) > width
                    push!(output_lines, current_line)
                    current_line = " " ^ length(line_prefix) * word
                else
                    current_line *= " " * word
                end
            end
            push!(output_lines, current_line)
        else
            push!(output_lines, line_prefix)
        end

        if !isempty(sense.examples)
            ex_prefix = "   Example: "
            ex_content = sense.examples[1]
            
            words = split(ex_content, ' ')
            if !isempty(words)
                current_line = ex_prefix * popfirst!(words)
                for word in words
                    if length(current_line) + 1 + length(word) > width
                        push!(output_lines, current_line)
                        current_line = " " ^ length(ex_prefix) * word
                    else
                        current_line *= " " * word
                    end
                end
                push!(output_lines, current_line)
            else
                push!(output_lines, ex_prefix)
            end
        end
    end

    join(output_lines, "\n")
end

function sanitize_field(value)
    if value === nothing
        return ""
    end
    if value isa AbstractString
        return strip(normalize_whitespace(String(value)))
    end
    return strip(normalize_whitespace(string(value)))
end

function strip_triple_backticks(text::AbstractString)
    stripped = strip(text)
    if startswith(stripped, "```")
        stripped = replace(stripped, r"^```[^\n]*\n?" => "")
    end
    if endswith(stripped, "```")
        stripped = replace(stripped, r"\n?```$" => "")
    end
    return strip(stripped)
end

function resolve_ipa(word_to_lookup, llm_ipa)
    ipa = phonetic_spelling(word_to_lookup)
    if isempty(ipa) && !isempty(llm_ipa)
        ipa = llm_ipa
    end
    ipa
end

function prepare_llm_args(base_args, prompt, schema)
    llm_args = copy(base_args)
    llm_args["input_text"] = prompt
    llm_args["schema"] = schema
    llm_args
end

function run_llm_definitions(word_to_lookup, args)
    context = args["context"]
    max_defs = args["max-definitions"]
    schema = Dict(
        "type" => "object",
        "properties" => Dict(
            "ipa" => Dict("type" => "string", "description" => "International Phonetic Alphabet spelling, may be empty"),
            "definitions" => Dict(
                "type" => "array",
                "items" => Dict(
                    "type" => "object",
                    "properties" => Dict(
                        "pos" => Dict("type" => "string", "enum" => ["Noun", "Verb", "Adjective", "Adverb", "Other"]),
                        "definition" => Dict("type" => "string", "description" => "Concise definition"),
                        "example" => Dict("type" => "string", "description" => "Short example sentence"),
                    ),
                    "required" => ["pos", "definition"],
                    "additionalProperties" => false,
                ),
            ),
            "synonyms" => Dict(
                "type" => "array",
                "items" => Dict("type" => "string"),
            ),
        ),
        "required" => ["definitions", "synonyms"],
        "additionalProperties" => false,
    )

    system_instruction = """
    You are a precise lexicographer. Respond with a JSON object matching the provided schema.
    - Provide at most $(max_defs) everyday definitions, ordered by commonness.
    - Only keep the most common defintions.
    - Include an example sentence for each definition when possible.
    - Synonyms array must list at least three relevant synonyms when they exist.
    - Do not repeat the target word in the synonyms array.
    - If the word is a common derivative (e.g., ends with -ish, -ness, -ly), provide a clear everyday gloss for the derivative form.
    """
    prompt_lines = ["Word: $(word_to_lookup)"]
    if !isempty(context)
        push!(prompt_lines, "Context to respect: $(context)")
    end
    prompt = join(prompt_lines, "\n")
    llm_args = prepare_llm_args(args, prompt, JSON.json(schema))
    
    raw_output = try
        call_llm(system_instruction, llm_args)
    catch err
        println(stderr, "error: LLM lookup failed: $(err)")
        exit(1)
    end
    
    payload = strip_triple_backticks(raw_output)
    # Basic sanitization: remove control chars that aren't \n, \r, \t
    payload = replace(payload, r"[\x00-\x08\x0B\x0C\x0E-\x1F]" => "")
    parsed = JSON.parse(payload)

    senses = []
    defs = get(parsed, "definitions", [])
    for (idx, entry) in enumerate(defs)
        definition = sanitize_field(get(entry, "definition", ""))
        isempty(definition) && continue
        pos = sanitize_field(get(entry, "pos", ""))
        pos = isempty(pos) ? "n" : lowercase(pos)
        example = sanitize_field(get(entry, "example", ""))
        examples = isempty(example) ? String[] : String[example]
        push!(senses, (
            index = idx,
            pos = pos,
            definition = definition,
            examples = examples,
            synonyms = String[],
            antonyms = String[],
        ))
        if length(senses) >= max_defs
            break
        end
    end

    synonyms_any = get(parsed, "synonyms", [])
    synonyms = String[]
    seen_syns = Set{String}()
    target = lowercase(strip(word_to_lookup))
    for syn_any in synonyms_any
        syn_str = sanitize_field(syn_any)
        if isempty(syn_str)
            continue
        end
        lowered = lowercase(syn_str)
        if lowered == target || lowered in seen_syns
            continue
        end
        push!(synonyms, syn_str)
        push!(seen_syns, lowered)
    end

    ipa = ""
    if haskey(parsed, "ipa")
        ipa = sanitize_field(parsed["ipa"])
    end

    (senses = senses, synonyms = synonyms, ipa = ipa)
end

function build_result_from_llm(word_to_lookup, args)
    llm_data = run_llm_definitions(word_to_lookup, args)
    senses = llm_data.senses
    isempty(senses) && return nothing

    synonyms = llm_data.synonyms
    ipa = resolve_ipa(word_to_lookup, llm_data.ipa)
    text = format_entry(word_to_lookup, ipa, senses, synonyms; max_defs = args["max-definitions"])
    (text, :llm, true)
end

function normalize_mode_arg(str)
    lowercase(replace(strip(str), '_' => '-'))
end

function main(_)
    custom_settings = ArgParseSettings(
        prog = "wl.jl",
        description = "Look up word/phrase definitions with a cache-first, LLM fallback flow.",
        epilog = """
        Examples:
          wl.jl port
          wl.jl --refresh set
          wl.jl --lookup=llm -C "as used in networking" port
          wl.jl --cache-write=llm-only molecule
          wl.jl --list
        """,
        add_version = true,
        version = "v2.0.2",
        preformatted_description = true,
        preformatted_epilog = true,
    )

    @add_arg_table! custom_settings begin
        "--list", "-L"
            help = "list all words currently stored in the cache"
            action = :store_true
        "--remove", "-R"
            help = "remove a specific WORD from the cache"
            metavar = "WORD"
            default = ""
        "--context", "-C"
            help = "Context or request guiding how to explain the word"
            metavar = "CONTEXT"
            default = ""
        "--lookup"
            help = "lookup MODE (default: auto): auto, cache, or llm"
            metavar = "MODE"
            arg_type = String
            default = ""
        "--refresh"
            help = "shorthand for --lookup=llm"
            action = :store_true
        "--cache-read"
            help = "cache read POLICY (default: auto): auto or never"
            metavar = "POLICY"
            arg_type = String
            default = ""
        "--no-cache-read"
            help = "alias for --cache-read=never"
            action = :store_true
        "--cache-write"
            help = "cache write POLICY (default: auto): auto, never, or llm-only"
            metavar = "POLICY"
            arg_type = String
            default = ""
        "--no-cache-write"
            help = "alias for --cache-write=never"
            action = :store_true
        "--max-definitions", "-M"
            arg_type = Int
            help = "maximum number of defintions to return"
            default = DEF_MAX_DEFINITIONS
            required = false
    end

    omitted = ["file", "schema", "schema-file", "attachment"]
    run_cli_with_args(
        custom_settings;
        parser = settings -> parse_commandline(settings; require_input=false, omit_args=omitted),
    ) do args
        max_defs = args["max-definitions"]
        dry_run = args["dry_run"]
        cache_file = joinpath(@__DIR__, CACHE_FILENAME)
        cache = load_cache(cache_file)

        # Handle cache management commands first
        if get(args, "list", false)
            words = sort!(collect(keys(cache)))
            if isempty(words)
                println("(cache is empty)")
            else
                for w in words
                    println(w)
                end
            end
            return nothing
        end

        remove_word = strip(get(args, "remove", ""))
        if !isempty(remove_word)
            remove_key = String(remove_word)
            if haskey(cache, remove_key)
                delete!(cache, remove_key)
                save_cache(cache_file, cache)
                println("removed: " * remove_key)
            else
                println("not found: " * remove_key)
            end
            return nothing
        end

        # Standard lookup flow
        word = get(args, "input_text", "")
        if isempty(strip(word))
            error("no input provided; pass a word/phrase, or use --list/--remove")
        end
        context = strip(get(args, "context", ""))

        lookup_raw = normalize_mode_arg(get(args, "lookup", ""))
        lookup_mode = isempty(lookup_raw) ? "auto" : lookup_raw
        if get(args, "refresh", false)
            if !isempty(lookup_raw)
                error("--refresh cannot be combined with --lookup")
            end
            lookup_mode = "llm"
        end
        if !(lookup_mode in ["auto", "cache", "llm"])
            error("unsupported lookup mode '" * lookup_mode * "'; valid modes: auto, cache, llm")
        end

        cache_read_raw = normalize_mode_arg(get(args, "cache-read", ""))
        cache_read_mode = isempty(cache_read_raw) ? "auto" : cache_read_raw
        if get(args, "no-cache-read", false)
            if !isempty(cache_read_raw)
                error("--no-cache-read cannot be combined with --cache-read")
            end
            cache_read_mode = "never"
        end
        if !(cache_read_mode in ["auto", "never"])
            error("unsupported cache read policy '" * cache_read_mode * "'; valid policies: auto, never")
        end
        cache_read_enabled = cache_read_mode != "never"

        cache_write_raw = normalize_mode_arg(get(args, "cache-write", ""))
        cache_write_mode = isempty(cache_write_raw) ? "auto" : cache_write_raw
        if get(args, "no-cache-write", false)
            if !isempty(cache_write_raw)
                error("--no-cache-write cannot be combined with --cache-write")
            end
            cache_write_mode = "never"
        end
        if !(cache_write_mode in ["auto", "never", "llm-only"])
            error("unsupported cache write policy '" * cache_write_mode * "'; valid policies: auto, never, llm-only")
        end

        if lookup_mode == "cache" && !cache_read_enabled
            error("lookup mode 'cache' requires cache reads; re-enable with --cache-read=auto")
        end

        lookup_result = nothing

        function run_cache_step()
             if !cache_read_enabled || !haskey(cache, word)
                return nothing
            end
            cached = cache[word]
            if cache_entry_stale(cached)
                return nothing
            end
            return (cached, :cache, false)
        end

        try
            if lookup_mode == "cache"
                lookup_result = run_cache_step()
                if lookup_result === nothing
                    error("'" * word * "' is not in the cache; use --lookup=llm to fetch")
                end
            elseif lookup_mode == "llm"
                lookup_result = build_result_from_llm(word, args)
                if lookup_result === nothing
                    error("unable to generate a definition via LLM for '" * word * "'; try adding --context context")
                end
            else # auto
                lookup_result = run_cache_step()
                if lookup_result === nothing
                    lookup_result = build_result_from_llm(word, args)
                end
                if lookup_result === nothing
                    error("unable to generate a definition for '" * word * "'")
                end
            end
        catch err
            if !dry_run
                rethrow(err)
            else
                exit(0)
            end
        end

        result_text, source, cache_needs_update = lookup_result

        compact_text = remove_empty_lines(result_text)
        if compact_text != result_text
            result_text = compact_text
            cache_needs_update = true
        end

        should_persist = cache_write_mode == "auto" ? (source != :cache || cache_needs_update) :
                         (cache_write_mode == "llm-only" ? (source == :llm) : false)

        if cache_needs_update || should_persist
            cache[word] = result_text
            if should_persist
                save_cache(cache_file, cache)
            end
        end

        print(result_text)
        if isempty(result_text) || result_text[end] != '\n'
            println()
        end
        
    end
end

@main
