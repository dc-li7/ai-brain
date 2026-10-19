# Git commands:

## Branch Naming
Prefixes: `feature|fix|refactor|docs|chore|hotfix`
Format: `<prefix>/<scope>/<desc>`
Regex: `^(feature|fix|refactor|docs|chore|hotfix)/[a-z0-9._-]+/[a-z0-9._-]+$`

All work branches start from `main` and come back through a pull request.
`main`, `master`, `release/*` and `prod/*` are protected: never push to them directly.

## Commit Format
`<type>(<scope>): <summary>` (a ticket ID, if the project has one, goes at the end of the summary)
Types: `feature|fix|refactor|docs|chore|test|build|ci`

## Commands

### Stage files
- `git add <files>` - specific files
- `git add .` - all changes
- `git add -p` - interactive

### List/manage branches
- `git branch [-r|-a]` - local/remote/all

### Change branch
- `git checkout <branch>`
- `git switch <branch>`

### Create & switch branch
- `git checkout -b <name> [<start>]`

### Record changes
- `git commit -m "<msg>"` - single line
- `git commit -m "<title>" -m "<body>"` - multi-line
- `git commit --amend` - modify last

### Compare changes
- `git diff [<ref>]` - unstaged/vs ref
- `git diff --staged` - staged changes

### Show history
- `git log --oneline -n <count>`
- `git log --stat -n <count>`
- `git log --graph --all`

### Upload commits
- `git push [-u origin <branch>]`

### Fetch & merge
- `git pull [--rebase]`

### Combine branches
- `git merge [--no-ff] <branch>`

### Store changes temporarily
- `git stash [save "<msg>"]`
- `git stash pop|list`