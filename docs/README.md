# Qubix OS — Documentation

Documentation for **Qubix OS**, a custom immutable Fedora Atomic image built with
[BlueBuild](https://blue-build.org) on top of Universal Blue's Aurora DX.

This documentation is written for **both human developers and AI agents**. Agents have
additional, mandatory working rules in [`../AGENTS.md`](../AGENTS.md).

## Start here

| Document | What it covers |
|---|---|
| [`overview.md`](overview.md) | What Qubix OS is, what it's made of, and the project's goals. |
| [`architecture.md`](architecture.md) | How the image is assembled, layer by layer. |
| [`design-decisions.md`](design-decisions.md) | **Why** the project is built the way it is (DD-001…). |
| [`recipe-reference.md`](recipe-reference.md) | Every module in `recipes/recipe.yml`, explained. |
| [`desktops.md`](desktops.md) | The two desktop sessions, switching between them, and Niri's configuration. |
| [`branding.md`](branding.md) | The branding asset map — which file overrides what. |
| [`build-and-release.md`](build-and-release.md) | CI, tagging, signing, and the release cadence. |
| [`usage.md`](usage.md) | Installing, rebasing, verifying, and building an ISO. |
| [`contributing.md`](contributing.md) | The development workflow everyone (human and agent) follows. |
| [`glossary.md`](glossary.md) | Terminology used across these documents. |

## Related, outside `docs/`

| Path | What it is |
|---|---|
| [`../AGENTS.md`](../AGENTS.md) | Mandatory instructions for AI coding agents. Single source of truth. |
| [`../.agent/plan.md`](../.agent/plan.md) | The task tracker. All work is a task with an ID and acceptance criteria. |
| [`../.agent/context/`](../.agent/context/README.md) | Context cache: a short summary of every file and module. |

## Documentation rules

1. **One source of truth per topic.** If two files would say the same thing, one links to
   the other.
2. **Markdown only**, with headings and tables. Reference material goes in tables.
3. **Docs change in the same commit as the behaviour they describe.**
4. Design decisions get an ID (`DD-###`) and are never silently rewritten — they are
   superseded, with the old record kept and marked.
