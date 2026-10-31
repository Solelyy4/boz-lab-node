# TUNNEL KIT — SSH ke mesin yang kau tak boleh capai

Fail asal (`tailscale-reverse-tunnel-main.zip`) ialah satu script untuk masuk ke **sandbox VM**
yang blok inbound dan padam `/etc` setiap reboot. Masalahnya ia andaikan kau **sudah ada** hos
Linux. Kau belum ada. Jadi kit ni tambah bahagian yang hilang itu.

---

## Isi kit

| Fail | Fungsi |
|---|---|
| `node.sh` | **Utama.** Satu arahan: jadikan mana-mana Linux boleh di-SSH dari mana-mana |
| `spin-up.sh` | Hidupkan hos Linux percuma atas permintaan (GitHub Actions) — 0 kad, 0 VPS |
| `muse_tunnel.sh` | Script asal, tidak diubah. Untuk kes sandbox yang reset `/etc` |
| `authorized_keys.pub` | Kunci awam kau (selamat didedahkan) |
| `keys/boz_lab` | Kunci peribadi — **jangan kongsi, jangan commit** |
| `BUKTI.md` | Log ujian sebenar |
| `.github/workflows/ephemeral-node.yml` | Resipi hos percuma |

---

## 1. Guna sekarang — percuma, tanpa VPS, tanpa kad

```bash
cd ~/Downloads/tunnel-kit
bash spin-up.sh 120 --test
```

Keluaran sebenar:

```
  ✓ nod hidup

     ssh -p 63230 runner@bore.pub

  · ujian sambungan
  ✓ SSH BERJAYA
     runner@runnervm48cm3
     Ubuntu 24.04.5 LTS
     2
     Mem:  7932  877  6365
```

Masuk bila-bila masa dalam tempoh itu:

```bash
ssh -i keys/boz_lab -p 63230 -o StrictHostKeyChecking=no runner@bore.pub
```

**Had sebenar:** satu job = maksimum **350 minit**, kemudian mesin dimusnahkan sepenuhnya
(disk, proses, semuanya). Bukan hos 24/7. Jangan letak kerja yang perlu hidup berhari-hari.

---

## 2. Kalau nak VPS kekal 24/7

Oracle Cloud **Always Free** — percuma tanpa had masa. Kad diperlukan untuk sahkan identiti
(caj ~RM1, dipulangkan), bukan langganan.

1. Daftar di `cloud.oracle.com/free`, pilih home region terdekat (Singapore).
2. Create Instance → **Ubuntu 24.04** → shape `VM.Standard.E2.1.Micro` (x86, sentiasa ada
   stok) atau `VM.Standard.A1.Flex` (ARM, 2 core/12 GB, stok sering habis).
3. Muat naik kunci awam `authorized_keys.pub` semasa buat instance.
4. Masuk: `ssh -i keys/boz_lab ubuntu@<IP-publik>`
5. Dalam VPS tu:

```bash
curl -fsSL https://raw.githubusercontent.com/Solelyy4/boz-lab-node/master/node.sh -o node.sh
sudo bash node.sh install --key "ssh-ed25519 AAAA... boz-lab-node"
sudo bash node.sh status
```

Kalau IP publiknya terbuka, kau tak perlu tunnel langsung — `ssh ubuntu@<IP>` terus jadi.
`node.sh` masih berguna untuk kunci sshd yang betul dan tunnel sandaran.

---

## 3. Kalau kau ada sandbox (muse.ai dan seumpamanya)

Guna `muse_tunnel.sh` **asal**, jalankan di dalam sandbox:

```bash
bash muse_tunnel.sh add-key "ssh-ed25519 AAAA... boz-lab-node"
bash muse_tunnel.sh
bash muse_tunnel.sh url
```

Ia pulihkan sshd selepas `/etc` dipadam, kekalkan tunnel, dan pasang cron penjaga.
Aku sudah audit script ni — **kodnya betul**, tiada bug yang perlu dibaiki.

---

## 4. Bila PC kau perlu jadi hujung tunnel (Jalur 1)

Jalur 1 beri alamat **tetap** (`ssh -p 2222 root@localhost`) tetapi PC kena ada dua benda,
dan kedua-duanya perlu **admin**:

```powershell
# PowerShell sebagai Administrator
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Start-Service sshd; Set-Service sshd -StartupType Automatic
```

Pasang Tailscale dari `tailscale.com/download`, login. Kemudian di VPS:
`bash muse_tunnel.sh pc-info` (di PC) untuk dapat `PC_USER` + `PC_TAILSCALE_IP`,
isi dalam `~/workspace/tunnel/tunnel.env`, dan `PC_TUNNEL_ENABLE=1`.

Tak wajib. Kalau kau cuma nak masuk ke hos, langkah 1 dah cukup.

---

## 5. Perkara yang aku betulkan masa uji

Bukan dalam script asal — dalam cara hos Linux dikonfigurasi:

| Masalah | Punca | Fix dalam `node.sh` |
|---|---|---|
| Login password masih hidup | `sshd_config.d` baca ikut abjad, **nilai pertama menang**; `50-cloud-init.conf` mengalahkan `99-` | drop-in dinamakan `00-boz-node.conf` |
| `AllowUsers ubuntu` tolak semua | GitHub runner guna user `runner`, bukan `ubuntu` | tiada `AllowUsers` langsung |
| `$(bore_bin)` rosak | `echo` status mencemari stdout | status dipindah ke stderr |

Ketiga-tiganya ditemui dengan ujian pada mesin sebenar, bukan andaian.

---

## 6. Batasan jujur

- **GitHub Actions bukan VPS.** Untuk kerja berterusan 24/7, proxy, atau mining — langgar ToS.
  Guna untuk sesi kerja sekejap sahaja, atau ambil Oracle untuk kerja kekal.
- **Tiada data kekal** antara run. Setiap nod baru = mesin kosong.
- **`bore.pub` tanpa SLA dan tanpa akaun** — port bertukar setiap kali tunnel dimulakan semula.
  Untuk port tetap, jalankan `node.sh install --port 45xxx` (selagi port itu bebas).
- **Kunci peribadi** mesti kekal di PC. Sesiapa yang ada `keys/boz_lab` boleh masuk ke nod.
