# `idk2` — deobfuscation notes

`idk2` is a **BadVape protected loader**, not an AetherV2 file. It was added in
commit `ebb42ef` ("Create idk2") and is 951 lines / 1.6 MB, of which 1.5 MB is a
single line.

## Result in one line

The loader is **not obfuscated and needed no deobfuscation** — it is the
vendor's own readable build template. Everything it hides, it hides behind
**authenticated encryption**, and the key lives on their licence server. So
this directory contains the annotated loader, a full write-up of the container
format, and a verified tool that finishes the job the moment a key is supplied.

## Files

| File | What it is |
|---|---|
| `loader.lua` | The loader, byte-identical to `idk2` except the 1,572,904-char base85 blob on line 673 is elided and four banner comments mark the builder's seams. Read this instead of `idk2`. |
| `unseal.py` | Standalone offline unsealer — base85, HMAC-SHA256 tag check, ChaCha20, raw DEFLATE. Takes `--release-key`, writes the plaintext Lua. |
| `fetch-release-key.lua` | Run in your own executor with your own licence key; prints the 64-hex `releaseKey` instead of consuming it. |

## What the loader actually does

1. **Place gate** — returns `false` unless `PlaceId` is `6872274481` (BedWars),
   `8444591321`, or `8560631822` (lobbies).
2. **Credential intake** — takes the licence key as the chunk's vararg, either
   a bare string or a table with a `Key` field.
3. **Fingerprinting** — collects HWID via `gethwid` / `get_hwid` /
   `syn.gethwid`, falling back to `RbxAnalyticsService:GetClientId()`, plus the
   executor name from `identifyexecutor` / `getexecutorname`.
4. **Auth POST** to `https://luvit.cc/badvape-api/v1/auth/verify` with
   `{protocolVersion = 4, key, nonce, placeId, releaseId}`, sending HWID and
   executor as `X-HWID` / `X-Executor` headers.
5. **Response validation** — the success body must have *exactly* six keys and
   echo back the request's `nonce`, `placeId` and `releaseId`, which kills
   replay and cross-release substitution. There is a deliberate compatibility
   path for executors that report `StatusCode = 0` on every response.
6. **Unseal and run** — derives keys from the returned `releaseKey`, verifies,
   decrypts, inflates, `loadstring`s the result and calls it with the original
   credential.

Two details worth noting on the way past:

- `safeDetail` scrubs error strings before they reach `shared.BadVapeProtectedFailure`,
  redacting the licence key, `BV-X-…` licence patterns, and any
  `key`/`uid`/`hwid`/`authorization`/`token`/`fingerprint` field. Failure
  reporting is deliberately non-leaky.
- The crypto include has a pure-Lua fallback for every `buffer` primitive, so
  the loader still runs on executors without native `buffer`.

## The sealed payload container

```
format          1
releaseId       4264b175447dc2361b9419bb51c47181
nonce           cd3c9e611dcfcdbd09bec469              (12 bytes hex)
tag             1610fe2e8351bc5f7add8d4c8c509311dd88f80984753a392c0a1d3c9adcf5d5
sourceSize      2,208,527 bytes
compressedSize  1,258,323 bytes
ciphertext      1,572,904 chars of base85
```

Opening it (`bvOpenSealedPayload`, `loader.lua` part 4):

```
ciphertext   base85 decode                    -> 1,258,323 bytes
encKey       HMAC-SHA256(releaseKey, 'badvape-payload-enc-v1\0' + releaseId)
macKey       HMAC-SHA256(releaseKey, 'badvape-payload-mac-v1\0' + releaseId)
aad          'badvape-payload-v1\0' + releaseId + '\0' + sourceSize
             + '\0' + compressedSize + '\0' + nonce
tag          HMAC-SHA256(macKey, aad + '\0' + ciphertext)     <- checked first
compressed   ChaCha20(ciphertext, encKey, nonce, counter = 1)
source       raw DEFLATE inflate              -> 2,208,527 bytes of Lua
```

The base85 is Ascii85 with `]` dropped from the usual `!`..`u` run and `v`
appended, so the blob can sit inside a Lua `[==[ ]==]` long string without
terminating it. Partial final groups pad with `v` (84).

## Why it cannot be opened offline

`releaseKey` is 32 bytes the **server** returns after checking licence key, HWID
and PlaceId. It is not in the file, and there is no local derivation path:

- `bvUnwrapReleaseKey` (line 614) *looks* like an offline unwrap from a master
  secret, but it is **dead code in this build** — never called, and the sealed
  table has none of the `wrappedKey` / `salt` / `guard` / `rng` fields it reads.
  It is a leftover from a different distribution mode.
- The tag is only a **verification oracle**: it confirms a candidate key in one
  HMAC. That reduces the problem to searching a 256-bit keyspace.
- The ciphertext measures **7.9999 bits/byte across all 256 byte values** — no
  structure to attack.

This is the honest boundary: what remains is key *acquisition*, not
cryptanalysis, and that is a licensing question rather than a technical one.

## Finishing the job

```sh
# 1. In your executor, in a BedWars place, with your own licence key:
#    edit LICENCE_KEY in fetch-release-key.lua, run it, copy the releaseKey.

# 2. Then, locally:
python3 deobfuscated/idk2/unseal.py --release-key <64 hex chars> \
    --output deobfuscated/idk2/payload.lua
```

Fetch the key yourself rather than handing your licence key to anyone else. The
endpoint sees `X-HWID`, and the loader's own failure list includes
`hwid_mismatch`, `ambiguous_hwid` and `uid_requires_bound_device` — so
authenticating from another machine risks binding, or locking, your key.

Expect **another layer underneath**. 2,208,527 bytes compressing to 1,258,323 is
a 57% ratio; ordinary Lua source deflates to roughly 20–25%. That much residual
entropy says the plaintext is itself obfuscated — most likely Luraph-style, with
randomized identifiers and encrypted string tables. Unsealing gets you to the
start of the real deobfuscation, not the end of it.

## Verification performed

`unseal.py` was checked before being trusted with anything:

- **ChaCha20** reproduces the RFC 8439 §2.4.2 test vector exactly.
- **base85** round-trips at sizes 1, 2, 3, 4, 5, 63, 64, 257 and 4096 against an
  encoder derived independently from the Lua decoder's rules.
- **The real ciphertext** decodes to exactly 1,258,323 bytes — matching
  `compressedSize` — confirming the alphabet and the partial-group padding.
- **End-to-end**, a synthetic payload sealed the way the Lua opener expects
  unseals back to the original bytes, and a key with one bit flipped is
  rejected by the tag check rather than producing garbage.

`loader.lua` was diffed line-by-line against `idk2`: identical on all 951 lines
except the elided blob. No Lua interpreter is available in this environment, so
that structural diff — not a compile — is the fidelity check.
