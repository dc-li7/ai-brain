---
name: bash-strict
description: Use this skill whenever you are writing or editing shell scripts — any file with a #!/bin/bash or #!/usr/bin/env bash shebang, any .sh file, any zsh script under ~/.config/zsh/, any systemd ExecStart that runs inline shell, any inline heredoc script being pasted for the user to run, or anything that looks like more than a one-line throwaway command. This skill enforces `set -euo pipefail`, safe quoting, shellcheck-clean patterns, proper arg parsing, and trap-based cleanup. It applies even when the script is short — small scripts are where unsafe habits compound.
---

# bash-strict

Bash is unforgiving. A missing quote turns into a security bug; an unset variable turns into `rm -rf /` in the wrong context. This skill keeps your shell scripts defensible by default.

## Required skeleton

Every non-trivial bash script starts like this:

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Optional: trap cleanup
cleanup() {
    local rc=$?
    # remove temp files, kill child procs, etc.
    rm -rf "${TMPDIR:-}" 2>/dev/null || true
    exit "$rc"
}
trap cleanup EXIT INT TERM

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

### Why each flag

- `set -e` — exit on any command failure. Prevents scripts from limping past unexpected errors. Catches ~70% of bugs.
- `set -u` — error on unset variables. Catches typos and missing inputs.
- `set -o pipefail` — fail a pipeline if any stage fails, not just the last. Without this, `failing | succeeding` exits 0.
- `IFS=$'\n\t'` — safer word splitting. Spaces in filenames stop being a footgun.

### Why the trap

Scripts create temp files, start background processes, lock files. If they die mid-run (error, Ctrl+C, SIGTERM), the cleanup should fire. `trap ... EXIT` fires on any exit path. Adding `INT TERM` ensures it fires on signals too.

## Quoting rules

- **Always quote variable expansions**: `"$var"`, not `$var`. Unquoted `$var` with a space or glob in it expands unpredictably.
- **Always quote `"$@"`**, never `$@` or `$*`. `"$@"` preserves arguments exactly as received.
- **Use `"${var}"` over `"$var"` when ambiguity matters**: `"${var}_suffix"` vs `"$var_suffix"` (the latter looks up `$var_suffix`).
- **Arrays**: `"${arr[@]}"` to expand all elements as separate words; `"${arr[*]}"` concatenates. Almost always the first.

Running through `shellcheck` catches most quoting mistakes automatically — use it.

## Argument parsing

For anything with more than a positional arg or two, use `getopts`:

```bash
usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [options] <target>

Options:
  -v              verbose output
  -o <file>       output file
  -t <timeout>    timeout in seconds (default: 30)
  -h              this help
EOF
}

verbose=0
output=""
timeout=30

while getopts ":vo:t:h" opt; do
    case "$opt" in
        v) verbose=1 ;;
        o) output="$OPTARG" ;;
        t) timeout="$OPTARG" ;;
        h) usage; exit 0 ;;
        \?) echo "$SCRIPT_NAME: unknown option -$OPTARG" >&2; usage >&2; exit 2 ;;
        :)  echo "$SCRIPT_NAME: -$OPTARG requires an argument" >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))

if (( $# < 1 )); then
    echo "$SCRIPT_NAME: missing target" >&2
    usage >&2
    exit 2
fi
target="$1"
```

Long options (`--verbose`) require either `getopt` (GNU, non-portable syntax) or hand-rolled parsing. Usually not worth it for internal scripts.

## Safe patterns

### Check commands exist
```bash
need() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "$SCRIPT_NAME: required command not found: $1" >&2
        exit 127
    }
}
need nmap
need jq
```

### Temp files
```bash
TMPDIR="$(mktemp -d)"       # readonly caught by trap above
# use: "$TMPDIR/workfile"
```

Never `/tmp/myscript.$$` — race conditions and predictable names. Always `mktemp`.

### Reading a file line-by-line
```bash
while IFS= read -r line; do
    printf '%s\n' "$line"
done < "$file"
```

`IFS=` preserves leading/trailing whitespace; `-r` disables backslash interpretation. Both matter.

### Checking if a variable is set
```bash
: "${MY_VAR:?MY_VAR must be set}"      # exit with message
: "${MY_VAR:=default}"                 # set default if unset
```

### Error helper
```bash
die() {
    echo "$SCRIPT_NAME: $*" >&2
    exit 1
}
```

## Unsafe patterns (avoid)

### Unquoted variables
```bash
# BAD
rm $file           # splits on whitespace, expands globs
cd $HOME/work
for f in $(ls);    # parses ls output, breaks on spaces

# GOOD
rm -- "$file"
cd "$HOME/work" || die "cd failed"
for f in *;
```

### Parsing ls
Never. Use globs (`for f in *.txt`) or `find ... -print0 | while IFS= read -r -d '' f`.

### Using `which`
`command -v` is POSIX and reliable. `which` is external and varies by distro.

### `eval`
Almost always wrong. If you think you need `eval`, think harder — it's usually a hint the data model is wrong.

### `cat file | cmd` instead of `cmd < file` or `cmd file`
Useless use of cat. `< file` is more efficient and clearer.

### Overwriting files without intent
```bash
# BAD
cmd > important.log   # silently overwrites

# GOOD
cmd >> important.log  # append
cmd > "${important_log:?}" # fail if unset
```

## Cleanup patterns

### Kill children on exit
```bash
pids=()

start_worker() {
    long_running_cmd &
    pids+=("$!")
}

cleanup() {
    local rc=$?
    for pid in "${pids[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    wait "${pids[@]}" 2>/dev/null || true
    exit "$rc"
}
trap cleanup EXIT INT TERM
```

### Lock file
```bash
exec 9>/var/lock/myscript.lock
flock -n 9 || die "another instance is running"
# lock released when fd 9 closes (on exit)
```

## Running shellcheck

Either install it and run manually, or lean on editor integration. Treat shellcheck warnings as errors until proven otherwise — the ones it lets through are usually style, not safety.

```bash
shellcheck -x script.sh
```

## Zsh differences

If your interactive shell is zsh, scripts should still target `#!/usr/bin/env bash` unless there's a reason — bash is more portable, and zsh's quoting semantics differ subtly (word splitting, array indexing) in ways that trip up shared scripts.

If a script is zsh-specific, mark it explicitly: `#!/usr/bin/env zsh` and note why at the top.

## When this skill doesn't apply

- One-line commands in a terminal — this is about *scripts*, not REPL usage
- Makefiles — different semantics, different quoting rules
- Systemd units where `ExecStart=` points to a separate script file (then apply to the file)
