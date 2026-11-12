# Copilot instructions for Orielle.Repo

## Repository status

This repository is currently a minimal placeholder: the working tree contains only `README.md` and Git metadata. There is no application source code, package manifest, framework config, test suite, or CI configuration yet.

Treat the repo as a blank project scaffold until a real codebase is added. Do not assume a language, framework, or runtime that is not present in the repository.

## Build, test, and lint commands

No build, test, or lint commands are configured in the current repository state.

- There is no `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Makefile`, or similar project entrypoint.
- There are no project-specific scripts to run.
- Do not invent or add framework-specific tooling unless the repo explicitly contains those files.

When a real project stack is added, prefer the commands declared in the repository's actual manifests or docs over generic assumptions.

For future growth, instructions should evolve to match the project:

- Inspect the root manifests (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Makefile`, `justfile`, CI files, and workspace configs) before suggesting commands.
- Prefer the repo-specific single-test or targeted-check flow over full-suite examples when a test runner is present.
- If the repo includes docs such as `README.md`, `CONTRIBUTING.md`, or a `docs/` section, treat those as the canonical source for local workflow and project conventions.
- Only add or recommend commands that are already present in the project or explicitly documented as the supported flow.

## High-level architecture

The current architecture is effectively:

- `README.md`: repository-level description and context
- `.git/`: source control metadata only

There is no application architecture to infer yet. The repository does not currently contain services, libraries, modules, scripts, or multi-package structure. Keep any future additions minimal and aligned with the actual project structure once it exists.

## Key conventions

- Keep changes consistent with the repository's current simplicity: this repo does not yet define a framework or coding style.
- Prefer small, direct additions over broad scaffolding until a project stack is present.
- Use the root-level documentation (`README.md`) as the source of truth for repo intent.
- Do not create new build/test tooling or framework conventions without explicit project files that justify them.
- Once the codebase grows, derive conventions from the actual repo: framework config, workspace layout, CI jobs, docs, and established module boundaries.
- Prefer conventions already reflected in the codebase (for example, app structure, environment variables, testing patterns, and generated files) rather than introducing new ones.

## AI assistant config files

No repository-local AI assistant instruction/config files were found in the project root, including `CLAUDE.md`, `AGENTS.md`, `.cursorrules`, `.windsurfrules`, or `CONVENTIONS.md`.
