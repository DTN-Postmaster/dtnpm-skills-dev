# Contributing to `skills-dev`

Thank you for contributing to the developer skills for the `dtn-postmaster` ecosystem.

## Adding or Modifying a Skill

1. Create a `kebab-case` directory under `skills/<skill-name>/` containing a `SKILL.md` file.
2. Verify that the YAML frontmatter contains `name` (= directory name) and `description` (clear, concise, third-person, explicit triggers).
3. Verify every trait name, template path, CLI flag, or fuzz target directly in the relevant repository (`template-dtnpm-*`, `dtnpm-core`, `dtnpm-web-core`, `dtnpm`, `dtnpm-cla-*`) before documenting it.
4. Avoid temporary files and unfinished task markers.
5. Run `./scripts/validate-skills.sh` and verify that all checks pass before opening a Pull Request.
