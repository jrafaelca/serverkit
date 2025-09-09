Git Commit Instructions (Conventional Commits)

Goal

Ensure all commit messages follow the same structure for readability, changelog generation, and semantic versioning.

⸻

Commit Format

<type>(optional scope): <short imperative description>

[optional body]

[optional footer]

- type: feat | fix | docs | style | refactor | perf | test | build | ci | chore | revert
- scope: optional, one word (e.g. auth, users, api).
- description: required, in English, imperative, ≤72 chars.

Rules
1.	Language: English only.
2.	Imperative style: use “add”, “fix”, “remove” (not “added”, “fixed”).
3.	Atomic commits: one logical change per commit.
4.	Breaking changes: use ! after type/scope or in footer.
5.	PR titles: follow same format as commits.

Examples
- feat(users): add profile update endpoint
- fix(api): handle null payload on webhook
- docs(readme): update setup instructions
- perf(mqtt): reduce JSON stringify calls
- chore(repo): add editorconfig
- feat(auth)!: remove legacy login

BREAKING CHANGE: old /v1/auth endpoint removed.

Checklist Before Commit
- Correct type?
- Clear scope?
- Description in English + imperative?
- Body explains what/why (if needed)?
- Footers for breaking changes/issues?
- Commit is atomic?