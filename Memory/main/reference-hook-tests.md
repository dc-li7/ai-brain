---
name: reference-hook-tests
description: The guard hooks have regression tests in AI/hooks/tests; run them after any change to a hook
metadata:
  type: reference
---

`AI/hooks/tests/test-secrets-guard.sh` and `AI/hooks/tests/test-sudo-block.sh` test the guard hooks against known bypasses. Both exit non-zero on any failure.

Run them after editing a hook: `bash AI/hooks/tests/test-sudo-block.sh && bash AI/hooks/tests/test-secrets-guard.sh`

The "OBSERVED" lines in the secrets-guard output are documented edge cases, not failures.
