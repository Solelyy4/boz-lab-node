"""Pemeriksaan isi fail mentah — cetak boolean sahaja, bukan rentetan sensitif."""
import sys

ORIG = r"C:/Users/zahin/Downloads/ts-tunnel-extract/tailscale-reverse-tunnel-main/muse_tunnel.sh"
PATCHED = r"C:/Users/zahin/Downloads/tunnel-kit/muse_tunnel.sh"

orig = open(ORIG, "rb").read()
patched = open(PATCHED, "rb").read()

checks = [
    ("auth pakai format %s", b"Proxy-Authorization: Basic %s"),
    ("ada literal tiga-bintang", b"***"),
    ("pola sk-ssh-ed25519 penuh", b"sk-ssh-ed25519@openssh.com"),
    ("pola sk-ecd bertitik", b"sk-ecd...p256"),
    ("pola sk-ecdsa penuh", b"sk-ecdsa-sha2-nistp256@openssh.com"),
]
for label, needle in checks:
    print(f"{label:32s} -> {needle in orig}")

print("orig CR bytes           ->", orig.count(b"\r"))
print("orig == patched         ->", orig == patched)
print("orig len / patched len  ->", len(orig), "/", len(patched))
