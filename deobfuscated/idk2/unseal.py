#!/usr/bin/env python3
"""
Offline unsealer for the BadVape "sealed payload v1" container found in ./idk2.

The container is the encrypted second stage of a protected loader. `idk2` itself
is a plaintext bootstrap: it authenticates against a licence server, receives a
32-byte release key, and uses it to open the blob. This script reimplements the
opening half of that bootstrap so the blob can be unsealed outside of Roblox,
given a release key.

Format (mirrors bvOpenSealedPayload in idk2):

    ciphertext          custom base85, 5 chars -> 4 bytes, alphabet '!'..'v'
                        minus ']' -- decodes to `compressedSize` bytes
    encryptionKey       HMAC-SHA256(releaseKey, 'badvape-payload-enc-v1\0' + releaseId)
    authenticationKey   HMAC-SHA256(releaseKey, 'badvape-payload-mac-v1\0' + releaseId)
    aad                 'badvape-payload-v1\0' + releaseId + '\0' + sourceSize +
                        '\0' + compressedSize + '\0' + nonceHex
    tag                 HMAC-SHA256(authenticationKey, aad + '\0' + ciphertext)
    compressed          ChaCha20(ciphertext, key=encryptionKey, nonce=nonce,
                                 initial counter = 1)
    source              raw DEFLATE inflate of `compressed` -> `sourceSize` bytes

Usage:
    ./unseal.py --release-key <64 hex chars> [--input ../../idk2] [--output payload.lua]
    ./unseal.py --info                      # print container metadata only

The release key is issued per-licence by the vendor's auth endpoint; it is not
present in `idk2` and cannot be derived from it. Without it this script can
report and validate the container but not decrypt it -- see README.md.
"""

from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import os
import re
import struct
import sys
import zlib

# --- container extraction ----------------------------------------------------

_SEALED_RE = re.compile(r"local sealedPayload = \{(.*?)\n\}", re.S)
_CIPHERTEXT_RE = re.compile(r"ciphertext = \[==\[(.*?)\]==\]", re.S)


def parse_container(path: str) -> dict:
    """Pull the sealedPayload table out of the loader source."""
    with open(path, "r", encoding="utf-8", errors="surrogateescape") as handle:
        source = handle.read()

    match = _SEALED_RE.search(source)
    if not match:
        raise SystemExit(f"{path}: no `local sealedPayload = {{...}}` table found")
    body = match.group(1)

    def text(name: str) -> str:
        found = re.search(rf"\b{name} = '([^']*)'", body)
        if not found:
            raise SystemExit(f"{path}: sealed payload is missing field `{name}`")
        return found.group(1)

    def number(name: str) -> int:
        found = re.search(rf"\b{name} = (\d+)", body)
        if not found:
            raise SystemExit(f"{path}: sealed payload is missing field `{name}`")
        return int(found.group(1))

    ciphertext = _CIPHERTEXT_RE.search(body)
    if not ciphertext:
        raise SystemExit(f"{path}: sealed payload has no base85 ciphertext block")

    container = {
        "format": number("format"),
        "releaseId": text("releaseId"),
        "nonce": text("nonce"),
        "tag": text("tag"),
        "sourceSize": number("sourceSize"),
        "compressedSize": number("compressedSize"),
        "ciphertext": ciphertext.group(1),
    }

    # Same shape checks bvOpenSealedPayload applies before touching the bytes.
    if container["format"] != 1:
        raise SystemExit("unsupported sealed payload format")
    if len(container["releaseId"]) != 32 or not re.fullmatch(r"[0-9a-f]+", container["releaseId"]):
        raise SystemExit("releaseId must be 32 lowercase hex characters")
    if len(container["nonce"]) != 24 or not re.fullmatch(r"[0-9a-f]+", container["nonce"]):
        raise SystemExit("nonce must be 24 lowercase hex characters")
    if len(container["tag"]) != 64 or not re.fullmatch(r"[0-9a-f]+", container["tag"]):
        raise SystemExit("tag must be 64 lowercase hex characters")
    if container["sourceSize"] < 1 or container["compressedSize"] < 1:
        raise SystemExit("sealed payload sizes must be positive")
    return container


# --- base85 ------------------------------------------------------------------

# Ascii85 with ']' removed from the usual '!'..'u' run and 'v' appended, so the
# blob can live inside a Lua [==[ ]==] long string without terminating it.
BASE85_ALPHABET = (
    "!\"#$%&'()*+,-./0123456789:;<=>?@"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\^_`"
    "abcdefghijklmnopqrstuv"
)
_BASE85_MAP = {ord(char): index for index, char in enumerate(BASE85_ALPHABET)}


def base85_decode(source: str, expected_size: int) -> bytes:
    """Decode the loader's base85 variant. Partial final groups pad with 'v'(84)."""
    output = bytearray()
    index = 0
    length = len(source)
    while index < length:
        remaining = length - index
        count = 5 if remaining >= 5 else remaining
        if count == 1:
            raise SystemExit("base85: orphan digit in final group")
        value = 0
        for digit_index in range(5):
            digit = 84
            if digit_index < count:
                digit = _BASE85_MAP.get(ord(source[index + digit_index]))
                if digit is None:
                    raise SystemExit(
                        f"base85: character {source[index + digit_index]!r} is not in the alphabet"
                    )
            value = value * 85 + digit
        emitted = count - 1 if count < 5 else 4
        group = struct.pack(">I", value & 0xFFFFFFFF)
        for byte_index in range(emitted):
            if len(output) >= expected_size:
                raise SystemExit("base85: decoded more bytes than the container declares")
            output.append(group[byte_index])
        index += 5
    if len(output) != expected_size:
        raise SystemExit(
            f"base85: decoded {len(output)} bytes, container declares {expected_size}"
        )
    return bytes(output)


# --- ChaCha20 ----------------------------------------------------------------

_CHACHA_CONSTANTS = (0x61707865, 0x3320646E, 0x79622D32, 0x6B206574)


def _rotate_left(value: int, bits: int) -> int:
    return ((value << bits) | (value >> (32 - bits))) & 0xFFFFFFFF


def _quarter_round(state: list[int], a: int, b: int, c: int, d: int) -> None:
    mask = 0xFFFFFFFF
    state[a] = (state[a] + state[b]) & mask
    state[d] = _rotate_left(state[d] ^ state[a], 16)
    state[c] = (state[c] + state[d]) & mask
    state[b] = _rotate_left(state[b] ^ state[c], 12)
    state[a] = (state[a] + state[b]) & mask
    state[d] = _rotate_left(state[d] ^ state[a], 8)
    state[c] = (state[c] + state[d]) & mask
    state[b] = _rotate_left(state[b] ^ state[c], 7)


def chacha20(data: bytes, key: bytes, nonce: bytes, counter: int = 1) -> bytes:
    """RFC 8439 ChaCha20 keystream XOR. The loader starts its counter at 1."""
    if len(key) != 32:
        raise SystemExit("chacha20: key must be 32 bytes")
    if len(nonce) != 12:
        raise SystemExit("chacha20: nonce must be 12 bytes")
    key_words = struct.unpack("<8I", key)
    nonce_words = struct.unpack("<3I", nonce)
    output = bytearray()
    for offset in range(0, len(data), 64):
        base = list(_CHACHA_CONSTANTS) + list(key_words) + [counter & 0xFFFFFFFF] + list(nonce_words)
        state = list(base)
        for _ in range(10):
            _quarter_round(state, 0, 4, 8, 12)
            _quarter_round(state, 1, 5, 9, 13)
            _quarter_round(state, 2, 6, 10, 14)
            _quarter_round(state, 3, 7, 11, 15)
            _quarter_round(state, 0, 5, 10, 15)
            _quarter_round(state, 1, 6, 11, 12)
            _quarter_round(state, 2, 7, 8, 13)
            _quarter_round(state, 3, 4, 9, 14)
        block = struct.pack(
            "<16I", *[(state[i] + base[i]) & 0xFFFFFFFF for i in range(16)]
        )
        chunk = data[offset : offset + 64]
        output += bytes(a ^ b for a, b in zip(chunk, block))
        counter = (counter + 1) & 0xFFFFFFFF
    return bytes(output)


# --- sealed payload ----------------------------------------------------------

def derive_keys(release_key: bytes, release_id: str) -> tuple[bytes, bytes]:
    encryption_key = hmac.new(
        release_key, b"badvape-payload-enc-v1\x00" + release_id.encode(), hashlib.sha256
    ).digest()
    authentication_key = hmac.new(
        release_key, b"badvape-payload-mac-v1\x00" + release_id.encode(), hashlib.sha256
    ).digest()
    return encryption_key, authentication_key


def build_aad(container: dict) -> bytes:
    return (
        b"badvape-payload-v1\x00"
        + container["releaseId"].encode()
        + b"\x00"
        + str(container["sourceSize"]).encode()
        + b"\x00"
        + str(container["compressedSize"]).encode()
        + b"\x00"
        + container["nonce"].encode()
    )


def unseal(container: dict, release_key: bytes) -> bytes:
    if len(release_key) != 32:
        raise SystemExit("release key must be exactly 32 bytes (64 hex characters)")

    ciphertext = base85_decode(container["ciphertext"], container["compressedSize"])
    encryption_key, authentication_key = derive_keys(release_key, container["releaseId"])

    expected_tag = hmac.new(
        authentication_key, build_aad(container) + b"\x00" + ciphertext, hashlib.sha256
    ).hexdigest()
    if not hmac.compare_digest(expected_tag, container["tag"]):
        raise SystemExit(
            "authentication tag mismatch -- the release key is wrong for this release, "
            "or the container has been modified"
        )

    nonce = bytes.fromhex(container["nonce"])
    compressed = chacha20(ciphertext, encryption_key, nonce, counter=1)

    source = zlib.decompress(compressed, -15)
    if len(source) != container["sourceSize"]:
        raise SystemExit(
            f"inflated {len(source)} bytes, container declares {container['sourceSize']}"
        )
    return source


# --- cli ---------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    default_input = os.path.join(os.path.dirname(__file__), "..", "..", "idk2")
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--input", default=os.path.normpath(default_input),
                        help="protected loader containing the sealed payload (default: ./idk2)")
    parser.add_argument("--release-key", help="32-byte release key as 64 hex characters")
    parser.add_argument("--output", help="write the unsealed Lua source here")
    parser.add_argument("--info", action="store_true", help="print container metadata and exit")
    parser.add_argument("--dump-ciphertext", help="write the base85-decoded ciphertext here")
    args = parser.parse_args(argv)

    container = parse_container(args.input)

    if args.info or (not args.release_key and not args.dump_ciphertext):
        metadata = {k: v for k, v in container.items() if k != "ciphertext"}
        metadata["ciphertextChars"] = len(container["ciphertext"])
        metadata["compressionRatio"] = round(
            container["compressedSize"] / container["sourceSize"], 4
        )
        print(json.dumps(metadata, indent=2))
        if not args.release_key and not args.dump_ciphertext:
            print(
                "\nNo --release-key given: the payload stays sealed. The key is issued by the\n"
                "vendor's licence server at runtime and is not recoverable from this file.",
                file=sys.stderr,
            )
        if args.info:
            return 0

    if args.dump_ciphertext:
        raw = base85_decode(container["ciphertext"], container["compressedSize"])
        with open(args.dump_ciphertext, "wb") as handle:
            handle.write(raw)
        print(f"wrote {len(raw)} bytes of ciphertext to {args.dump_ciphertext}", file=sys.stderr)

    if not args.release_key:
        return 1

    try:
        release_key = bytes.fromhex(args.release_key.strip())
    except ValueError:
        raise SystemExit("release key must be hex")

    source = unseal(container, release_key)
    destination = args.output or os.path.join(os.path.dirname(__file__), "payload.lua")
    with open(destination, "wb") as handle:
        handle.write(source)
    print(f"unsealed {len(source)} bytes to {destination}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
