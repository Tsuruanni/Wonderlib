---
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
argument-hint: "[optional commit message]"
---

# Update Docs and Commit

Analyze recent git changes and update project documentation, then commit everything.

## Arguments
$ARGUMENTS - Optional: commit message or description of changes. If empty, generate from git diff.

## Instructions

### Step 1: Analyze Git Changes
Run these commands to understand what changed:
```bash
git status
git diff --stat
git diff
```

If there are no staged or unstaged changes, inform the user and stop.

### Step 2: Update docs/changelog.md

Read the current changelog and add entries for new changes under `## [Unreleased]`.

**Format to follow:**
- Group changes by date with a descriptive header (e.g., `### Feature Name (YYYY-MM-DD)`)
- Use bullet points with **bold** for key items
- Categories: Added, Changed, Fixed, Removed, Infrastructure

**Only add entries for:**
- New features or functionality
- Bug fixes
- Breaking changes
- Significant refactors

**Do NOT add entries for:**
- Minor code cleanups
- Internal refactors with no user impact
- Documentation-only changes (those go in the commit, not changelog)

### Step 3: Update docs/architecture.md (if needed)

Only update if there are **structural changes** such as:
- New directories or modules added
- New repository/provider patterns
- Database schema changes
- New external integrations

Read the current architecture.md first. If no structural changes, skip this step.

### Step 4: Update docs/project_status.md

Read the current project_status.md and:

1. **Update "Current Phase"** if a phase was completed
2. **Check off completed items** in the Roadmap checkboxes `[x]`
3. **Move completed tasks** from "In Progress" to "Recently Completed" table
4. **Update "Blockers"** - cross out resolved blockers with ~~strikethrough~~
5. **Update "Tech Debt"** - cross out resolved items
6. **Update the "Son güncelleme" date** at the top

### Step 5: Stage and Commit

```bash
# Stage all changes including docs
git add -A

# Create commit with descriptive message
git commit -m "$(cat <<'EOF'
<type>: <short description>

<body - what changed and why>

Docs updated:
- changelog.md
- project_status.md
- architecture.md (if changed)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

**Commit types:**
- `feat:` - new feature
- `fix:` - bug fix
- `refactor:` - code restructuring
- `docs:` - documentation only
- `chore:` - maintenance tasks

### Step 6: Report

After committing, show:
1. The commit hash and message
2. Summary of documentation updates
3. Files changed count

## Notes
- If the user provided $ARGUMENTS, use that as the basis for the commit message
- Keep changelog entries concise but informative
- Use English for all documentation updates
- Do not push to remote unless explicitly asked
