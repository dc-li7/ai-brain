# CTF Crypto Reference

Checklist for crypto-category CTF challenges. Load when the challenge involves encryption, hashing, encoding, or any "recover the key / plaintext / flag from ciphertext" task.

## Triage

1. **Identify the scheme.** The challenge usually tells you (RSA, AES, XOR, Vigenère). If not:
   - Output length divisible by 16 → likely AES (or another 128-bit block cipher)
   - Long base64/hex number pairs → likely RSA
   - Short alphabetic output, spaces preserved → classical cipher
   - Output has repeating 16-byte blocks for repeating plaintext → AES-ECB
2. **Check for obvious weakness.** CTF crypto challenges almost always have an intended flaw — brute-forcing AES is never the answer.

## Classical / encoding

Not really crypto but often the first step:

- `base64`, `base32`, `base16`/hex, `base58`, `base85`
- ROT13 / Caesar / ROTn
- Vigenère — crack with Kasiski or Friedman if key length unknown
- XOR — single-byte key: brute force 256; multi-byte: `xortool` or Kasiski-equivalent
- Morse, binary, octal, ASCII decimal
- Tool: **CyberChef** is the Swiss army knife for encoding/decoding

## AES / symmetric

### ECB weakness
Same plaintext block → same ciphertext block. Detect: look for repeated 16-byte blocks in the ciphertext.

Attacks:
- **ECB byte-at-a-time**: append your input to unknown plaintext, encrypt under ECB. Recover the unknown byte by byte.
- **ECB cut-and-paste**: rearrange blocks to forge things (classic: profile manager role escalation).

### CBC weakness
- **Padding oracle**: if the server tells you whether a decryption's padding is valid, you can decrypt arbitrary ciphertext. Tool: `padbuster` or roll your own.
- **Bit-flipping**: XOR a byte in ciphertext block N to flip a byte in plaintext block N+1 (predictably).
- **IV reuse / known IV**: breaks confidentiality in specific constructions.

### Key / IV mistakes
- Hardcoded key in source
- Key derived from low-entropy source (PID, time, predictable)
- IV = 0 or IV = key
- ECB with the claim "we're using AES so it's safe"

## RSA

The CTF workhorse. Common weaknesses:

### Small e
- `e = 3` and `m^3 < n`: `plaintext = cuberoot(c)`
- Håstad broadcast: same message encrypted with e=3 under three different moduli → CRT → cube root

### Small d (Wiener's attack)
- When `d < n^0.25`, `d` recoverable from continued fractions of `e/n`

### Common modulus
- Same `n`, two different `e`s (gcd=1) → Bezout → recover plaintext

### Shared primes
- Two moduli share a prime: `gcd(n1, n2) = p`. Trivial factor.

### Fermat factorization
- When `p` and `q` are close, `n = p*q` and `p ≈ q ≈ sqrt(n)`. Iterate.

### Factordb / known factorizations
- Try `factordb.com` before anything else — many CTF n's are already factored

### Tool: RsaCtfTool
```bash
RsaCtfTool --publickey pubkey.pem --uncipher cipher.bin
```
Tries all common weaknesses automatically. Good first pass.

### Padding: PKCS#1 v1.5
- Bleichenbacher's attack if the server is a padding oracle
- Manger's attack for OAEP implementation flaws

## ECC

- Singular curve (discriminant zero) → DLP reduces to multiplicative group
- Smart's attack: when curve order = field order
- Pohlig-Hellman when the order factors into small primes
- Invalid curve attack: pass points not on the curve, recover key mod small subgroup

## Hashing

- Length extension: MD5/SHA1/SHA256 vulnerable if used as `H(secret || data)`. Tool: `hashpump`.
- Collision: MD5 broken; SHA1 broken (SHAttered). If a challenge claims MD5 for integrity, there's your angle.
- Rainbow tables / `hashcat` / `john` for cracking — identify with `hashid` / `name-that-hash`

## PRNG

- Mersenne Twister (Python `random`): recoverable from 624 consecutive outputs. Tool: `randcrack`.
- LCG: recoverable from a few outputs via Gaussian elimination over the modulus
- `time(NULL)` seed: brute force the narrow time window

## Sage and z3

When the math gets hairy:
- **SageMath** — number theory + algebraic geometry. CTF standard for lattice attacks, ECC, Coppersmith.
- **z3** — SMT solver. Good for reversing crypto-like checks when you can express them as constraints.

## Workflow when stuck

1. Identify the scheme precisely — what are the parameters, what's public, what's private?
2. Look up the scheme's known attacks — don't invent one
3. Check parameter sizes for obvious weakness (small e, small d, close primes, low-entropy seed)
4. Search CTFTime / writeups for the exact challenge wording — many are reused
5. If the challenge has an interactive oracle, think "what does it tell me on each query"
