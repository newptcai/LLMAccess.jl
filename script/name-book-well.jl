#!/usr/bin/env -S julia -O 0 --compile=min --startup-file=no --project=@script

using LLMAccess
using ArgParse
using JSON

const MAX_BASENAME_LEN = 100

re_esc(s::AbstractString) = replace(String(s), r"([\\.^$|?*+()[\]{}])" => s"\\\\1")

function has_exiftool()
    Sys.which("exiftool") !== nothing
end

function read_exiftool_metadata(path::AbstractString)
    if !has_exiftool()
        return Dict{String,Any}()
    end
    try
        raw = read(`exiftool -json -s $path`, String)
        data = JSON.parse(raw)
        if data isa Vector && !isempty(data) && data[1] isa Dict
            # Normalize keys to String for convenience
            d = Dict{String,Any}()
            for (k, v) in data[1]
                d[string(k)] = v
            end
            return d
        end
    catch
        # ignore and fall through
    end
    return Dict{String,Any}()
end

function clean_slug(s::AbstractString)
    # Lowercase, replace separators with '-', keep only ascii alnum and '-'
    t = lowercase(String(s))
    # common punctuation and whitespace -> '-'
    t = replace(t, r"[\s_:/\\.,;!'\"()[\]{}]+" => "-")
    # collapse repeated '-'
    t = replace(t, r"-+" => "-")
    # filter to ascii, letters/digits, and '-'
    t = String(join(filter(c -> (isascii(c) && ((isletter(c) || isdigit(c)) || c == '-')), t)))
    # trim leading/trailing '-'
    t = strip(t, '-')
    # truncate politely
    if length(t) > MAX_BASENAME_LEN
        cut = findlast('-', t[1:MAX_BASENAME_LEN])
        if cut !== nothing && cut > 1
            t = t[1:cut-1]
            t = strip(t, '-')
        else
            t = first(t, MAX_BASENAME_LEN)
            t = strip(t, '-')
        end
    end
    return t
end

const AUTHOR_SUFFIX_CANONICAL = Dict(
    "jr" => "Jr",
    "sr" => "Sr",
    "ii" => "II",
    "iii" => "III",
    "iv" => "IV",
    "v" => "V",
    "vi" => "VI",
    "vii" => "VII",
    "viii" => "VIII",
    "ix" => "IX",
    "x" => "X",
)

const AUTHOR_SUFFIXES = Set(keys(AUTHOR_SUFFIX_CANONICAL))

function slugify_author_name(name::AbstractString)

    # First, clean the whole name string to replace separators with dashes
    # but without lowercasing
    s = String(name)
    s = replace(s, r"[\s_:/\\.,;!'\"()[\]{}]+" => "-")
    s = replace(s, r"-+" => "-")
    s = String(join(filter(c -> (isascii(c) && ((isletter(c) || isdigit(c)) || c == '-')), s)))
    s = strip(s, '-')

    # Now, split into parts and handle capitalization
    parts = split(s, '-')
    slug_parts = String[]
    for part in parts
        if isempty(part)
            continue
        end

        low_part = lowercase(part)
        if low_part in AUTHOR_SUFFIXES
            push!(slug_parts, AUTHOR_SUFFIX_CANONICAL[low_part])
        else
            push!(slug_parts, uppercasefirst(low_part))
        end
    end

    return join(slug_parts, "-")
end

const ROMAN_VALUES = Dict(
    'I' => 1,
    'V' => 5,
    'X' => 10,
    'L' => 50,
    'C' => 100,
    'D' => 500,
    'M' => 1000,
)

function roman_to_int(s::AbstractString)
    chars = uppercase(strip(s))
    isempty(chars) && return nothing
    total = 0
    prev = 0
    for ch in reverse(chars)
        val = get(ROMAN_VALUES, ch, 0)
        val == 0 && return nothing
        if val < prev
            total -= val
        else
            total += val
            prev = val
        end
    end
    return total
end

function parse_volume_value(text::AbstractString)
    s = strip(String(text))
    isempty(s) && return nothing
    m_num = match(r"(\d+)", s)
    if m_num !== nothing
        return string(parse(Int, m_num.captures[1]))
    end
    m_roman = match(r"\b([ivxlcdm]+)\b"i, s)
    if m_roman !== nothing
        roman_val = roman_to_int(m_roman.captures[1])
        roman_val !== nothing && return string(roman_val)
    end
    return nothing
end

function build_volume_slug(volume::Any)
    val = parse_volume_value(string(volume))
    if val !== nothing
        return "-v" * val
    end
    slug = clean_slug(string(volume))
    return isempty(slug) ? "" : "-" * slug
end

function abbreviate_volume_tokens(slug::AbstractString)
    pattern = r"-(?:volume|vol)-[a-z0-9]+"
    return replace(String(slug), pattern => s -> begin
        seg = String(s)
        dash_idx = findlast('-', seg)
        dash_idx === nothing && return seg
        dash_idx == lastindex(seg) && return seg
        token = seg[dash_idx+1:end]
        num = try parse(Int, token) catch; nothing end
        if num === nothing
            roman_val = roman_to_int(token)
            roman_val === nothing && return seg
            return "-v" * string(roman_val)
        else
            return "-v" * string(num)
        end
    end)
end

function extract_last_name_from_name(name::AbstractString)
    s = strip(String(name))
    isempty(s) && return ""

    segment = occursin(',', s) ? strip(first(split(s, ',', limit=2))) : s
    segment = replace(segment, r"[()\[\]{}]+" => " ")

    tokens = split(segment, r"\s+"; keepempty=false)
    cleaned = String[]
    for token in tokens
        t = strip(replace(token, "." => ""))
        isempty(t) && continue
        push!(cleaned, t)
    end

    while !isempty(cleaned)
        token_lc = lowercase(cleaned[end])
        if token_lc in AUTHOR_SUFFIXES
            pop!(cleaned)
        else
            break
        end
    end

    return isempty(cleaned) ? "" : cleaned[end]
end

function extract_last_name_from_slug_segment(segment::AbstractString)
    s = strip(String(segment), '-')
    isempty(s) && return ""
    tokens = split(s, '-'; keepempty=false)
    while !isempty(tokens)
        token_lc = lowercase(tokens[end])
        if token_lc in AUTHOR_SUFFIXES
            pop!(tokens)
        else
            break
        end
    end
    return isempty(tokens) ? "" : tokens[end]
end

function author_slug_from_name(name::AbstractString)
    last = extract_last_name_from_name(name)
    if isempty(last)
        return slugify_author_name(name)
    end
    return slugify_author_name(last)
end

function author_slug_from_slug_segment(segment::AbstractString)
    last = extract_last_name_from_slug_segment(segment)
    if isempty(last)
        return slugify_author_name(segment)
    end
    return slugify_author_name(last)
end

function canonicalize_author_segment(slug::AbstractString)
    s = String(slug)
    by_idx = findfirst("-by-", s)
    by_idx === nothing && return s

    prefix = by_idx.start > 1 ? s[1:by_idx.start-1] : ""
    rest = by_idx.stop < lastindex(s) ? s[by_idx.stop+1:end] : ""
    has_etal = endswith(rest, "-et-al")
    author_seg = has_etal ? rest[1:end-length("-et-al")] : rest
    author_seg = strip(author_seg, '-')

    if isempty(author_seg)
        return s
    end

    canonical_author = author_slug_from_slug_segment(author_seg)
    isempty(canonical_author) && return s
    suffix = has_etal ? "-et-al" : ""

    return string(prefix, "-by-", canonical_author, suffix)
end

function drop_unknown_author(slug::AbstractString)
    s = String(slug)
    by_idx = findfirst("-by-", s)
    by_idx === nothing && return s

    rest = s[by_idx.stop+1:end]
    has_etal = endswith(rest, "-et-al")
    author_seg = has_etal ? rest[1:end-length("-et-al")] : rest
    author_seg = strip(author_seg, '-')

    # Tokens commonly used when author is unknown; if matched, drop author part entirely
    unknowns = Set(["author", "unknown", "anonymous", "various", "na", "n-a", "n/a", "none"])
    if isempty(author_seg) || (lowercase(author_seg) in unknowns)
        # Return everything before '-by-'
        return s[1:by_idx.start-1]
    end
    return s
end

function next_version_name(dir::AbstractString, base::AbstractString, ext::AbstractString; version::Union{Nothing,Int}=nothing)
    ext_lc = lowercase(ext)

    if version === nothing
        # No version detected. Return plain base.ext_lc.
        # If this causes a collision, the mv operation will fail,
        # which is the desired behavior as per user's request to not add version info.
        return basename(joinpath(dir, base * ext_lc))
    else
        # A specific version was detected. Try to use base-v<version>.ext_lc
        current_version_to_check = version
        while true
            candidate_versioned_name = string(base, "-v", current_version_to_check, ext_lc)
            candidate_versioned_path = joinpath(dir, candidate_versioned_name)
            if !isfile(candidate_versioned_path)
                return basename(candidate_versioned_path)
            end
            current_version_to_check += 1 # Increment to find next available if collision
        end
    end
end

function detect_version(meta::Dict{String,Any}, original_name::AbstractString)
    texts = String[
        original_name,
        string(get(meta, "Title", "")),
        string(get(meta, "Subject", "")),
        string(get(meta, "Author", "")),
        string(get(meta, "Creator", "")),
        string(get(meta, "Keywords", "")),
        string(get(meta, "Description", "")),
    ]
    # Prefer explicit vN or version N, then edition N
    pats = [
        r"\bv\s*(\d{1,3})\b"i,
        r"\bversion\s*(\d{1,3})\b"i,
        r"\brev\.?:s*(\d{1,3})\b"i,
        r"\b(\d{1,3})(?:st|nd|rd|th)\s+ed(?:ition)?\b"i,
        r"\bed(?:ition)?\s*(\d{1,3})\b"i,
    ]
    for t in texts
        for p in pats
            m = match(p, t)
            if m !== nothing
                n = try parse(Int, m.captures[1]) catch; nothing end
                if n !== nothing && n >= 1
                    return n
                end
            end
        end
        # handle v1.2 -> 1
        m = match(r"\bv\s*(\d{1,3})\.(\d+)\b"i, t)
        if m !== nothing
            n = try parse(Int, m.captures[1]) catch; nothing end
            if n !== nothing && n >= 1
                return n
            end
        end
    end
    return nothing
end


function build_prompt(original_name::AbstractString, meta::Dict{String,Any})
    meta_json = JSON.json(meta, 2)

    meta_block = """
    Original Filename:
    $(original_name)

    PDF Metadata (if any):
    $(meta_json)
    """

    return """
    You are an expert librarian. You analyze book information from filenames and metadata to extract structured data.

    Task:
    - Analyze the provided filename and metadata to identify the book's main title, all its authors, the edition, and the volume (if explicitly mentioned).
    - The main title should not include subtitles (material after a colon or dash), but do keep explicit volume indicators such as "Volume 3" or "Vol. II" when they appear.
    - Provide a list of all authors. Preserve their names as accurately as possible.
    - Identify the ordinal edition of the book (e.g., "2nd", "4th"), if available. Do not include descriptive editions like "Revised Edition".
    - If the author cannot be determined, return an empty list for authors.
    - Ignore format/source tags and noise such as "djvu", "pdf", "epub", "azw3", "ocr", "z-library", "libgen", etc., that are not part of the title or author names.
    - Return the result as a JSON object matching the provided schema. Do not return any other text or explanation.

    Context:
    $meta_block
    """
end

function try_parse_dict(json_str::AbstractString)
    try
        parsed = JSON.parse(json_str)
        return parsed isa Dict ? parsed : nothing
    catch
        return nothing
    end
end

function extract_json_dict(text::AbstractString)
    sanitized = replace(String(text), '\r' => '\n')
    block = match(r"```json\s*(\{.*?\})\s*```"s, sanitized)
    if block !== nothing
        parsed = try_parse_dict(block.captures[1])
        parsed !== nothing && return parsed
    end

    json_start = findfirst('{', sanitized)
    json_end = findlast('}', sanitized)
    if json_start !== nothing && json_end !== nothing && json_start < json_end
        parsed = try_parse_dict(sanitized[json_start:json_end])
        if parsed !== nothing
            if haskey(parsed, "choices")
                choices = parsed["choices"]
                if choices isa AbstractVector && !isempty(choices)
                    first_choice = choices[1]
                    if first_choice isa Dict
                        message = get(first_choice, "message", nothing)
                        if message isa Dict && haskey(message, "content")
                            nested = extract_json_dict(String(message["content"]))
                            nested !== nothing && return nested
                        end
                    end
                end
            end
            return parsed
        end
    end
    return nothing
end

function parse_json_string_literal(str_lit::AbstractString)
    try
        return JSON.parse(str_lit)
    catch
        return nothing
    end
end

function extract_string_field(text::AbstractString, keys::Vector{String})
    for key in keys
        pattern = Regex("\\\"" * key * "\\\"\\s*:\\s*(\"(?:\\\\.|[^\"\\\\])*\")")
        m = match(pattern, text)
        if m !== nothing
            val = parse_json_string_literal(m.captures[1])
            val !== nothing && return val
        end
    end
    return nothing
end

function extract_array_field(text::AbstractString, key::String)
    pattern = Regex("\\\"" * key * "\\\"\\s*:\\s*(\\[.*?\\])", "s")
    m = match(pattern, text)
    if m === nothing
        return nothing
    end
    try
        arr = JSON.parse(m.captures[1])
        return arr isa Vector ? arr : nothing
    catch
        return nothing
    end
end

function extract_json_by_patterns(text::AbstractString)
    base = String(text)
    variants = String[]
    seen = Set{String}()
    function push_variant!(v)
        if !(v in seen)
            push!(variants, v)
            push!(seen, v)
        end
    end
    push_variant!(base)
    push_variant!(replace(base, "\\n" => "\n"))
    push_variant!(replace(base, "\\\"" => "\""))
    push_variant!(replace(replace(base, "\\n" => "\n"), "\\\"" => "\""))

    for variant in variants
        title = extract_string_field(variant, ["title", "main_title"])
        authors = extract_array_field(variant, "authors")
        edition = extract_string_field(variant, ["edition"])

        if title !== nothing || (authors !== nothing && !isempty(authors))
            data = Dict{String,Any}()
            title !== nothing && (data["title"] = title)
            authors !== nothing && (data["authors"] = authors)
            if edition !== nothing && !isempty(strip(edition))
                data["edition"] = edition
            end
            return data
        end
    end
    return nothing
end

function parse_llm_payload(text::AbstractString)
    data = extract_json_dict(text)
    data isa Dict && return data
    return extract_json_by_patterns(text)
end

function main(_)
    system_instruction = "" # not strictly needed for most providers

    custom_settings = ArgParseSettings(
        prog = "name-book-well.jl",
        description = "Use LLM to rename a book PDF to 'book-title-by-author1-[et-al]-[-vN].pdf'.",
        epilog = """
        Examples:
          ./name-book-well.jl -f mybook.pdf
          ./name-book-well.jl -y -f ~/Downloads/SomeBook.pdf

          # From filename with authors in parentheses, ignoring tags like (Z-Library)
          ./name-book-well.jl -y -f "Probability and Random Processes (Geoffrey R. Grimmett, David R. Stirzaker) (Z-Library).pdf"
          # Suggests -> probability-and-random-processes-by-Geoffrey-R-Grimmett-et-al.pdf
        """,
        add_version = true,
        version = "v1.2.0",
        preformatted_description = true,
        preformatted_epilog = true,
    )

    @add_arg_table! custom_settings begin
        "--yes", "-y"
        help = "Confirm the rename without prompting"
        action = :store_true
    end

    run_cli_with_args(
        custom_settings;
        parser = settings -> parse_commandline(settings; omit_args=["attachement"], require_input=false)
    ) do args

        # Accept -f/--file primarily; fall back to --attachment if provided
        infile = String(get(args, "file", ""))
        if isempty(infile)
            infile = String(get(args, "attachment", ""))
        end
        if isempty(infile)
            println(stderr, "error: please provide a file with -f <path>.")
            exit(2)
        end
        inpath = abspath(infile)
        if !isfile(inpath)
            println(stderr, "error: file not found: " * inpath)
            exit(2)
        end

        dir = dirname(inpath)
        name = basename(inpath)
        base, ext = splitext(name)
        if lowercase(ext) != ".pdf"
            println(stderr, "warning: input is not a PDF; proceeding with original extension " * ext)
        end

        meta = read_exiftool_metadata(inpath)

        prompt = build_prompt(name, meta)
        schema_dict = Dict(
            "type" => "object",
            "properties" => Dict(
                "title" => Dict(
                    "type" => "string",
                    "description" => "The main title of the book, without subtitles.",
                ),
                "authors" => Dict(
                    "type" => "array",
                    "items" => Dict("type" => "string"),
                    "description" => "A list of author names, in order. Example: [\"William Strunk Jr.\", \"E. B. White\"]",
                ),
                "volume" => Dict(
                    "type" => "string",
                    "description" => "The explicit volume designation if the book is part of a numbered multi-volume set (e.g., 3, Vol. II, Volume Three).",
                ),
                "edition" => Dict(
                    "type" => "string",
                    "description" => "The ordinal edition of the book, if available (e.g., 2nd, 4th). Can be omitted if not found or if the edition is descriptive such as Revised Edition.",
                ),
            ),
            "required" => ["title", "authors"],
        )
        schema = JSON.json(schema_dict, 2)

        # Pass prompt to LLM; attachment is available as args["attachment"] already
        args["input_text"] = prompt
        args["schema"] = schema
        raw = call_llm(system_instruction, args)
        sanitized = replace(String(raw), '\r' => '\n')

        llm_data = parse_llm_payload(sanitized)
        if llm_data isa Dict
            if !haskey(llm_data, "title") && haskey(llm_data, "main_title")
                llm_data["title"] = llm_data["main_title"]
            end
        end

        invalid = llm_data === nothing || !isa(llm_data, Dict) || !haskey(llm_data, "title") || !haskey(llm_data, "authors") || isempty(strip(llm_data["title"]))

        slug = ""
        if invalid
            println(stderr, "warning: LLM parsing failed, falling back to basic slug from filename.")
            slug = clean_slug(base)
        else
            title_slug = clean_slug(llm_data["title"])

            volume_slug_part = ""
            if haskey(llm_data, "volume")
                volume_val = llm_data["volume"]
                if volume_val !== nothing && !isempty(strip(String(volume_val)))
                    volume_slug = build_volume_slug(volume_val)
                    volume_slug_part = volume_slug
                end
            end

            edition_slug_part = ""
            if haskey(llm_data, "edition")
                edition_val = llm_data["edition"]
                if edition_val !== nothing && !isempty(strip(String(edition_val)))
                    edition_slug = clean_slug(String(edition_val))
                    if !isempty(edition_slug)
                        edition_suffix = endswith(edition_slug, "-ed") ? "" : "-ed"
                        edition_slug_part = "-" * edition_slug * edition_suffix
                    end
                end
            end

            authors = llm_data["authors"]
            author_slug_part = ""
            if !isempty(authors)
                first_author_slug = author_slug_from_name(authors[1])
                if !isempty(first_author_slug)
                    author_slug_part = "-by-" * first_author_slug
                    if length(authors) > 1
                        author_slug_part *= "-et-al"
                    end
                end
            end

            slug = title_slug * volume_slug_part * edition_slug_part * author_slug_part
        end


        if isempty(slug)
            println(stderr, "error: empty slug after processing.")
            exit(1)
        end

        slug = abbreviate_volume_tokens(slug)
        slug = drop_unknown_author(slug)
        slug = canonicalize_author_segment(slug)

        # Determine version if present
        ver = detect_version(meta, name)
        # Determine final filename, handling collisions with -vN; ensure lowercase extension
        final_name = next_version_name(dir, slug, ext; version=ver)

        if final_name == name
            println("ℹ️ File already follows the suggested naming; no changes made.")
            exit(0)
        end

        # Confirmation and dry-run behavior
        if get(args, "dry-run", false)
            println("---" * " Proposed Rename ---")
            println("Original: " * name)
            println("Suggest : " * final_name)
            exit(0)
        elseif get(args, "yes", false)
            println("Original: " * name)
            println("Renamed:  " * final_name)
        else
            println("---" * " Proposed Rename ---")
            println("Original: " * name)
            println("Suggest : " * final_name)
            print("❓ Confirm rename? (y/N): ")
            ans = try
                lowercase(strip(readline()))
            catch
                ""
            end
            if ans != "y"
                println("❌ Rename aborted.")
                exit(2)
            end
        end

        try
            mv(inpath, joinpath(dir, final_name))
            println("✅ File renamed to " * final_name)
        catch e
            println(stderr, "error: failed to rename: " * sprint(showerror, e))
            exit(1)
        end
        nothing
    end
end

@main
