# CTF Binary Reference

Checklist for pwn / reverse-engineering challenges. Load when the challenge provides a binary or the category is pwn/rev.

## Triage a binary

```bash
file <binary>                    # arch, bits, static/dynamic, stripped?
checksec <binary>                # NX / PIE / canary / RELRO / fortify
strings -n 8 <binary> | less     # obvious flags, hints, symbols
nm <binary>                      # exported symbols (if not stripped)
readelf -a <binary> | less       # sections, dynamic info
ldd <binary>                     # shared libs (pwn: libc version!)
```

For reverse-engineering, hand off to Ghidra / IDA / radare2 / Binary Ninja. Ghidra is free and the default.

## Mitigations matter

`checksec` output tells you what's possible:

| Mitigation | What it blocks | How to bypass |
|---|---|---|
| NX | Shellcode on stack | ROP, ret2libc, JIT spray |
| Canary | Stack overflow → RIP control | Leak canary first, or overflow via format string |
| PIE | Fixed code addresses | Leak a code pointer, compute base |
| RELRO (full) | GOT overwrite | Overwrite something else (e.g., function pointers, vtables) |
| ASLR | Fixed libc | Leak a libc pointer, compute base |
| Fortify | Unsafe libc calls | Trigger via different path |

## Pwn common patterns

### Buffer overflow → RIP control
1. Find offset to saved RIP: `pattern create 200` → run → `pattern offset <value>`
2. Control RIP with a ROP chain or ret2libc
3. Leak libc address (e.g., via `puts@plt(puts@got)`), compute base
4. Return to `system("/bin/sh")` or `one_gadget`

### Format string
- `%x` to leak stack, `%p` for clean pointers
- `%s` to dereference a stack slot (careful, can crash)
- `%n` for arbitrary write (32-bit easier, 64-bit needs direct access like `%10$n`)
- Tool: `gef` / `pwndbg` has format-string helpers

### Heap
- UAF → tcache/fastbin poisoning → arbitrary write
- Tcache bin count (glibc ≥2.26): 7 before it becomes "normal"
- `malloc_hook` / `free_hook` overwrites (pre-glibc 2.34); post-2.34 use IO_FILE / exit handlers
- Tool: `pwndbg` with `vis_heap_chunks`, `tcachebins`, `fastbins`

### Shellcode
- When NX is off and you control execution: write shellcode, jump to it
- `pwntools` has `shellcraft` — generates per-arch shellcode
- Avoid null bytes if the input goes through `strcpy` etc.

## pwntools skeleton

```python
from pwn import *
context.binary = elf = ELF("./chall")
libc = ELF("./libc.so.6")       # when provided

# Local vs remote
p = process() if args.LOCAL else remote("host", 1337)

# Optional gdb attach (local only): p = gdb.debug("./chall", "b *main+N\nc")

# ... build payload ...
p.sendlineafter(b"> ", payload)
p.interactive()
```

Run with `python exploit.py LOCAL` vs `python exploit.py` to flip.

## Reverse-engineering approach

1. **Run it** (safely) — understand what it does at the level of "what input does it want, what does it output"
2. **Strings pass** — `strings` sometimes literally contains the flag or a flag-checking string
3. **Find main** — if stripped, trace from `_start` → `__libc_start_main`'s first arg
4. **Find the flag check** — usually a loop comparing input to something
5. **Invert the check** — brute force, SMT solver (z3), or algebraic reversal

### Anti-debug / anti-analysis
- `ptrace(PTRACE_TRACEME)` — use `LD_PRELOAD` stub that makes it return 0
- Timing checks — patch the comparison
- VM detection — irrelevant in CTF usually, but happens
- Packed binaries — unpack with `upx -d` (UPX) or dump from memory

### SMT with z3
When the flag check is a series of constraints on bytes:

```python
from z3 import *
s = Solver()
flag = [BitVec(f"f{i}", 8) for i in range(32)]
for b in flag:
    s.add(b >= 0x20, b < 0x7f)
# add constraints from the reversed check
# s.add(flag[0] + flag[1] == 0xAB)
# ...
if s.check() == sat:
    m = s.model()
    print(bytes(m[b].as_long() for b in flag))
```

## Useful tools (install once)

- **pwntools** (`pip install pwntools`) — exploit framework
- **pwndbg** or **gef** — gdb enhancements for exploit dev
- **ROPgadget** / **ropper** — find gadgets
- **one_gadget** (Ruby gem) — libc magic gadgets for ret2libc
- **Ghidra** — free decompiler
- **angr** — symbolic execution (overkill for easy, gold for hard)
- **checksec** (from pwntools or standalone)
- **pwninit** — auto-set up a pwn challenge directory
