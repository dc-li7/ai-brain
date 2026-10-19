#!/usr/bin/env bash
# Tests for confirm-run and confirm-open. Runs confirm-run inside a pseudo-terminal
# (util-linux `script`), so the real Yes/No prompt is exercised, with gum or without.
#   bash AI/setup/tests/test-confirm-run.sh
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RUN="${CONFIRM_RUN:-$ROOT/AI/setup/confirm-run}"  # override to test a variant
OPEN="$ROOT/AI/setup/confirm-open"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
pass=0; fail=0
check() { if eval "$2"; then echo "PASS $1"; pass=$((pass+1)); else echo "FAIL $1"; fail=$((fail+1)); fi; }
# window <job> <keys>: run confirm-run in a 30x110 pseudo-terminal and type <keys>.
# "y" picks Yes in gum and answers the typed prompt. \r is the Enter key (in raw
# mode a terminal sends CR, and gum ignores LF). gum may swallow the keys meant
# for the final "Press Enter to close", so each window is closed after a few seconds;
# the result file is written before that prompt.
window() { printf "$2" | timeout 4 script -qec "stty rows 30 cols 110; bash $RUN $1" /dev/null >/dev/null 2>&1; }

printf 'echo hello > %s/ran\n' "$T" > "$T/ok.sh"
window "$T/ok.sh" 'y\r\r'
check "Yes runs the job" '[ -f "$T/ran" ] && grep -q "^exit=0" "$T/ok.sh.result"'
check "result records the job fingerprint" 'grep -q "^job_sha256=$(sha256sum < "$T/ok.sh" | cut -d" " -f1)$" "$T/ok.sh.result"'

# Enter is pressed after gum is up, like a person would: typed ahead, the terminal
# would still be in line mode and turn it into a LF, which gum ignores.
rm -f "$T/ran" "$T/ok.sh.result"
{ sleep 1; printf '\r'; sleep 0.5; printf '\r'; } | timeout 5 script -qec "stty rows 30 cols 110; bash $RUN $T/ok.sh" /dev/null >/dev/null 2>&1
check "a bare Enter cancels (No is the default)" '[ ! -f "$T/ran" ] && grep -q "^cancelled" "$T/ok.sh.result"'
window "$T/ok.sh" 'n\r\r'
check "No cancels" '[ ! -f "$T/ran" ] && grep -q "^cancelled" "$T/ok.sh.result"'

printf 'echo safe\ntouch %s/hidden\033[1A\033[2K\n' "$T" > "$T/esc.sh"
printf 'echo safe\rtouch %s/hidden\n' "$T" > "$T/cr.sh"
printf 'echo \xe2\x80\xae touch %s/hidden\n' "$T" > "$T/rtl.sh"
printf '# step one \xe2\x80\x94 harmless\ntouch %s/hidden\n' "$T" > "$T/dash.sh"
printf 'echo \xd0\xb0pproved; touch %s/hidden\n' "$T" > "$T/cyr.sh"
for j in esc cr rtl dash cyr; do window "$T/$j.sh" 'y\r\r\r'; done
check "escape codes, carriage returns and right-to-left tricks are refused" '[ ! -f "$T/hidden" ] && grep -q "not plain ASCII" "$T/esc.sh.result" && grep -q "not plain ASCII" "$T/cr.sh.result" && grep -q "not plain ASCII" "$T/rtl.sh.result"'
check "em dashes and Cyrillic look-alike letters are refused too" '[ ! -f "$T/hidden" ] && grep -q "not plain ASCII" "$T/dash.sh.result" && grep -q "not plain ASCII" "$T/cyr.sh.result"'

{ printf '(touch %s/hidden) &' "$T"; printf ' %.0s' $(seq 1 3000); printf '\necho visible\n'; } > "$T/wide.sh"
window "$T/wide.sh" 'y\r\r\r'
check "a line long enough to wrap out of view is refused" '[ ! -f "$T/hidden" ] && grep -q "a line is" "$T/wide.sh.result"'

{ for i in $(seq 1 60); do echo "echo line $i"; done; } > "$T/long.sh"
window "$T/long.sh" '\rqy\r\r'
check "a job taller than the window is paged, then runs on Yes" 'grep -q "^line 60$" "$T/long.sh.result" && grep -q "^exit=0" "$T/long.sh.result"'
{ for i in $(seq 1 12); do printf 'echo %0250d\n' 0; done; } > "$T/wrap.sh"
out=$(printf '\rqn\r\r' | timeout 4 script -qec "stty rows 30 cols 110; bash $RUN $T/wrap.sh" /dev/null 2>&1)
check "few lines that wrap past the window height are paged too" '[[ $out == *"longer than the window"* ]]'

echo "precious" > "$T/victim"; rm -f "$T/ok.sh.result"; ln -s "$T/victim" "$T/ok.sh.result"
window "$T/ok.sh" 'y\r\r'
check "a planted link is never written through" '[ "$(cat "$T/victim")" = precious ] && grep -q "^exit=0" "$T/ok.sh.result" && [ ! -L "$T/ok.sh.result" ]'

# The window itself is started without BASH_ENV by confirm-open; this checks that
# confirm-run also keeps it away from the job.
printf 'echo "seen=[${BASH_ENV:-}]"\n' > "$T/be.sh"; echo ':' > "$T/env-file"
printf 'y\r\r' | timeout 4 script -qec "stty rows 30 cols 110; BASH_ENV=$T/env-file bash $RUN $T/be.sh" /dev/null >/dev/null 2>&1
check "BASH_ENV does not reach the job" 'grep -q "^seen=\[\]$" "$T/be.sh.result"'

# A fake cat first on PATH must change neither what the window shows nor what runs.
mkdir -p "$T/fake"; printf '#!/bin/sh\necho "echo looks harmless"\n' > "$T/fake/cat"; chmod +x "$T/fake/cat"
printf 'echo "cat is $(command -v cat)"\n' > "$T/path.sh"
out=$(printf 'y\r\r' | PATH="$T/fake:$PATH" timeout 4 script -qec "stty rows 30 cols 110; bash $RUN $T/path.sh" /dev/null 2>&1)
check "a fake cat on PATH changes neither the display nor the job" '[[ $out == *"command -v cat"* && $out != *"looks harmless"* ]] && grep -q "^cat is /usr/" "$T/path.sh.result" && ! grep -q "$T/fake" "$T/path.sh.result"'

# A fake tr that reports "nothing bad here" must not get an escape code past the check.
printf '#!/bin/sh\nexit 0\n' > "$T/fake/tr"; chmod +x "$T/fake/tr"
printf 'echo safe\ntouch %s/hidden2\033[1A\033[2K\n' "$T" > "$T/esc2.sh"
printf 'y\r\r\r' | PATH="$T/fake:$PATH" timeout 4 script -qec "stty rows 30 cols 110; bash $RUN $T/esc2.sh" /dev/null >/dev/null 2>&1
check "a fake tr on PATH can't get an escape code past the check" '[ ! -f "$T/hidden2" ] && grep -q "not plain ASCII" "$T/esc2.sh.result"'

mkdir -p "$T/a;b"; printf 'echo x\n' > "$T/a;b/j.sh"
out=$(PATH="$ROOT/AI/setup:$PATH" bash "$OPEN" "$T/a;b/j.sh" 2>&1)
check "confirm-open refuses shell characters in the job path" '[[ $out == *"may only use"* ]]'

echo "passed: $pass  failed: $fail"
(( fail == 0 ))
