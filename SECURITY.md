# Security Policy — `skills-dev`

## Security Objective

The skills provided in `skills-dev` guide the writing of Rust/TypeScript code and the configuration of network and amateur radio services. Consequently, a bad example in a `SKILL.md` directly introduces vulnerabilities for end users.

Contributions must systematically prohibit:
- Unauthenticated or unencrypted defaults without a warning and an explicit opt-in flag.
- Passing secrets via cleartext CLI arguments instead of `--token-file` or secure stdin.
- Panicking calls in application Rust code (`unwrap()`, `expect()`) and unparameterized SQL/HTML constructions (`dangerouslySetInnerHTML` without strict sanitization).
- Using GitHub Actions not pinned by full SHA-1.

## Reporting a Vulnerability or Dangerous Recommendation

If you identify a security error in a skill or workflow of this repository, please open a private report with the maintainers (`security@dtn-postmaster.org`) or via the GitHub Security Advisories tab prior to any public disclosure.
