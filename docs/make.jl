using Documenter
using LLMAccess

# Doctest setup across the docs
DocMeta.setdocmeta!(LLMAccess, :DocTestSetup, :(using LLMAccess); recursive=true)

makedocs(
    sitename = "LLMAccess.jl",
    modules = [LLMAccess],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = nothing,
        assets = String[],
    ),
    remotes = nothing,
    clean = true,
    warnonly = [:missing_docs, :cross_references],
    pages = [
        "Home" => "index.md",
        "CLI" => "cli.md",
        "API" => "api.md",
    ],
)
# In GitLab CI, publish docs by uploading `docs/build` as the Pages artifact.
# See `.gitlab-ci.yml` for the `pages` job that moves `docs/build` to `public/`.
