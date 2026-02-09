# Atomic Commit - Precise Git Commits

Create atomic commits that only include explicitly specified files.

## Why Atomic Commits?

- **Clarity**: Each commit contains only related changes
- **Safety**: Prevents accidental inclusion of unrelated files, secrets, or temp files
- **Reviewability**: Easier code review with focused changesets
- **Revertability**: Easy to revert specific changes without side effects

## Instructions

When committing changes, ALWAYS:

1. **List files explicitly** - Never use `git add .` or `git add -A`
2. **Verify the changeset** - Run `git diff --staged` before committing
3. **Use scoped messages** - Prefix with type: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`

## Commands

### For tracked files (modified):
```bash
git commit -m "<scoped message>" -- path/to/file1 path/to/file2
```

### For new files (untracked):
```bash
git restore --staged :/ && git add "path/to/file1" "path/to/file2" && git commit -m "<scoped message>"
```

### For mixed (new + modified):
```bash
git restore --staged :/ && git add "path/to/file1" "path/to/file2" && git commit -m "<scoped message>" -- path/to/file1 path/to/file2
```

## Arguments: $ARGUMENTS

If arguments are provided:
- `status` - Show current git status with file paths
- `staged` - Show what's currently staged
- `<message>` - Create commit with the staged files using the provided message

## Example Usage

```
/atomic-commit status                    # See what files changed
/atomic-commit "feat: add user auth"     # Commit staged files with message
```

## Commit Message Format

```
<type>(<scope>): <description>

[optional body]

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

## Best Practices

1. **One logical change per commit** - Don't mix features with refactors
2. **Commit often** - Smaller commits are easier to understand
3. **Test before committing** - Ensure the code works
4. **Review staged changes** - Always check `git diff --staged`
