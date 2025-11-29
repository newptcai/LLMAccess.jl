#!/usr/bin/env -S julia -O 0 --compile=min --startup-file=no --project=@script

using LLMAccess
using ArgParse
using InteractiveUtils: clipboard

const FILE_PLACEHOLDER_PATTERN = r"\{\{(FILE|F)(?:\|([^}]+))?\}\}"

const FILE_SHORTCUT_PREFIX = ":"
const LEGACY_PATH_SHORTCUT_PREFIX = "path:"

const FILE_SHORTCUT_ALIASES = Dict(
    "basename" => :basename,
    "base" => :basename,
    "filename" => :basename,
    "dirname" => :dirname,
    "dir" => :dirname,
    "stem" => :stem,
    "name" => :stem,
    "without-ext" => :stem,
    "no-ext" => :stem,
    "ext" => :extension,
    "extension" => :extension,
    "with-ext" => :extension,
    "change-ext" => :extension,
    "replace-ext" => :extension,
    "set-ext" => :extension,
    "drop-ext" => :remove_ext,
    "remove-ext" => :remove_ext,
    "rm-ext" => :remove_ext,
)

const FILE_SHORTCUT_DESCRIPTIONS = Dict(
    :basename => "Strip directories and return only the filename",
    :dirname => "Return only the directory portion of the path",
    :stem => "Filename without its last extension",
    :extension => "Return the last extension (with the leading dot). Pass a value to replace it (e.g., :ext=pdf)",
    :remove_ext => "Drop the last extension entirely",
)

function normalize_extension(ext::AbstractString)
    stripped = strip(ext)
    isempty(stripped) && return ""
    return startswith(stripped, ".") ? stripped : "." * stripped
end

function list_file_shortcuts()
    grouped = Dict{Symbol,Vector{String}}()
    for (alias, op) in FILE_SHORTCUT_ALIASES
        push!(get!(grouped, op, String[]), alias)
    end
    buf = IOBuffer()
    for pair in sort!(collect(grouped); by = p -> string(p.first))
        op = pair.first
        names = sort(pair.second)
        desc = get(FILE_SHORTCUT_DESCRIPTIONS, op, "")
        println(buf, "  :$(names[1]) -> $desc (aliases: $(join(names, ", ")))")
    end
    return String(take!(buf))
end

function list_file_shortcuts_aliases()
    aliases = String[]
    for (k, v) in FILE_SHORTCUT_ALIASES
        push!(aliases, "  $k -> $v")
    end
    return join(aliases, "\n")
end

function apply_file_shortcut(op::Symbol, args, file_path::AbstractString)
    rooted = abspath(file_path)
    basename_root, ext = splitext(basename(rooted))
    rooted_base, _ = splitext(rooted)
    if op == :basename
        isempty(args) || error("':basename' does not take arguments")
        return basename(rooted)
    elseif op == :dirname
        isempty(args) || error("':dirname' does not take arguments")
        return dirname(rooted)
    elseif op == :stem
        isempty(args) || error("':stem' does not take arguments")
        return basename_root
    elseif op == :extension
        if isempty(args)
            return ext
        elseif length(args) == 1
            new_ext = normalize_extension(args[1])
            return string(rooted_base, new_ext)
        else
            error("':ext' takes zero or one argument")
        end
    elseif op == :remove_ext
        isempty(args) || error("':remove-ext' does not take arguments")
        return rooted_base
    else
        error("Unsupported file shortcut '$op'")
    end
end

function try_file_shortcut(command::AbstractString, file_path::AbstractString)
    stripped = strip(command)
    spec = if startswith(stripped, FILE_SHORTCUT_PREFIX)
        strip(stripped[length(FILE_SHORTCUT_PREFIX)+1:end])
    elseif startswith(lowercase(stripped), LEGACY_PATH_SHORTCUT_PREFIX)
        strip(stripped[length(LEGACY_PATH_SHORTCUT_PREFIX)+1:end])
    else
        return nothing
    end
    tokens = String[]
    if !isempty(spec)
        try
            tokens = Base.shell_split(spec)
        catch err
            error("Failed to parse file shortcut '$command': $(sprint(showerror, err))")
        end
    end
    isempty(tokens) && error("':' requires an operation name. Available shortcuts:\n$(list_file_shortcuts())")
    op_token = tokens[1]
    extra_args = tokens[2:end]
    eq_index = findfirst(==('='), op_token)
    op_name = op_token
    inline_arg = nothing
    if eq_index !== nothing
        op_name = op_token[1:eq_index-1]
        inline_arg = op_token[eq_index+1:end]
    end
    op_name = lowercase(strip(op_name))
    isempty(op_name) && error("File shortcut name cannot be empty")
    op = get(FILE_SHORTCUT_ALIASES, op_name, nothing)
    op === nothing && error("Unknown file shortcut ':$op_name'. Available shortcuts:\n$(list_file_shortcuts())")
    args = inline_arg === nothing ? extra_args : vcat(inline_arg, extra_args)
    return apply_file_shortcut(op, args, file_path)
end

function run_file_placeholder_command(command::AbstractString, file_path::AbstractString)
    script = """
    set -euo pipefail
    FILE_PLACEHOLDER=\$(cat <<'__LLMACCESS_FILE__'
$file_path
__LLMACCESS_FILE__
)
    export FILE_PLACEHOLDER
    printf '%s\n' "\$FILE_PLACEHOLDER" | ( $(command) )
    """
    try
        output = read(`bash -lc $script`, String)
        return chomp(output)
    catch err
        error("placeholder command '$command' failed: $(sprint(showerror, err))")
    end
end

function apply_file_placeholders(input_text, file_arg)
    text = String(input_text)
    if !occursin(FILE_PLACEHOLDER_PATTERN, text)
        return text, false
    end
    raw_file = file_arg === nothing ? "" : String(file_arg)
    cleaned_file = strip(raw_file)
    if isempty(cleaned_file)
        error("{{FILE}}/{{F}} placeholder requires a file path; pass -f/--file")
    end
    resolved_file = abspath(expanduser(cleaned_file))

    function render_placeholder(placeholder::AbstractString)
        inner = placeholder[3:end-2]
        parts = split(inner, '|'; limit=2)
        lhs = uppercase(strip(parts[1]))
        if !(lhs in ("FILE", "F"))
            return placeholder
        end
        if length(parts) == 1 || isempty(strip(parts[2]))
            return resolved_file
        end
        command = strip(parts[2])
        path_result = try_file_shortcut(command, resolved_file)
        if path_result !== nothing
            return path_result
        end
        return run_file_placeholder_command(command, resolved_file)
    end

    replaced_text = replace(text, FILE_PLACEHOLDER_PATTERN => render_placeholder)
    return replaced_text, true
end

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
        epilog = """
        Examples:
          julia --project script/cmd.jl --llm openai "list files changed today"
          julia --project script/cmd.jl -f ./deploy.sh --llm openai "Rewrite {{FILE}} to use rsync"
          julia --project script/cmd.jl -f ./notes.txt --llm openai "Summarize {{F|:ext=md}} and explain the diff"

        Available shortcuts:
        $(rstrip(list_file_shortcuts()))

        Shortcuts aliases:
        $(rstrip(list_file_shortcuts_aliases()))
        """,
        add_version = true,
        version = "v1.1.0",
        preformatted_epilog = true,
    )

    # Optional: allow directly supplying a command (bypasses LLM), useful for offline/testing
    @add_arg_table! custom_settings begin
        "--cmd"; help = "Direct command to use instead of calling LLM"; metavar = "CMD"; default = ""
        "--no-copy"; help = "Do not copy the generated command to the clipboard"; dest_name = "no_copy"; action = :store_true
        "-n", "--non-interactive"; help = "Print the command without prompting to run it"; dest_name = "non_iteractive"; action = :store_true
    end

    # Mirror ask.jl: delegate error handling and Ctrl+C to run_cli_with_args
    omitted_args = ["copy", "no_normalize"]  # --copy conflicts with --no-copy; normalization is unnecessary for shell commands
    run_cli_with_args(
        custom_settings;
        parser = settings -> parse_commandline(settings; require_input = false, omit_args = omitted_args),
    ) do args
        placeholder_used = false
        input_text = get(args, "input_text", nothing)
        if input_text !== nothing
            normalized_text, used = apply_file_placeholders(input_text, get(args, "file", ""))
            args["input_text"] = normalized_text
            placeholder_used = used
        end

        # For this script, copy by default unless --no-copy is provided
        args["copy"] = !get(args, "no_copy", false)

        using_llm = isempty(strip(get(args, "cmd", "")))
        result = if using_llm
            if placeholder_used
                println(stderr, "[cmd.jl] Prompt after {{FILE}}/{{F}} expansion:")
                println(stderr, args["input_text"])
            end
            call_llm(system_instruction, args)  # handles clipboard when args["copy"]
        else
            String(args["cmd"])
        end

        # Use regex to remove trailing whitespace on each line (with multiline mode)
        trimmed_text = replace(result, r"\s+$"m => "")
        println(trimmed_text)
        # When bypassing LLM with --cmd, apply clipboard based on effective default
        if !using_llm && get(args, "copy", false)
            clipboard(trimmed_text)
        end

        # Ask for confirmation before executing
        if !get(args, "non_iteractive", false)
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
        end
        nothing
    end
end

@main
