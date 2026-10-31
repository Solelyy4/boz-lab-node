# BUKTI — log ujian sebenar

Semua di bawah ialah keluaran sebenar tool, bukan jangkaan. Tarikh: 31 Okt / 1 Nov 2026
(UTC 21:30–21:45 · WIB 04:30–04:45).

---

## 1. `bore.pub` buka tunnel (log GitHub Actions, run 41243904590)

```
+ /tmp/bore --version
bore-cli 0.6.0
+ nohup /tmp/bore local 22 --to bore.pub --port 24876
INFO bore_cli::client: connected to server remote_port=24876
INFO bore_cli::client: listening at bore.pub:24876
```

## 2. SSH sebenar masuk ke mesin (bukan VPS, bukan kad)

```
$ ssh -p 1739 -i keys/boz_lab runner@bore.pub '...'
USER=runner
runnervm48cm3
OS=Ubuntu 24.04.5 LTS
2
Mem:            7932         848        6107          45        1278        7084
/dev/root        72G   59G   13G  83% /
 21:37:37 up 3 min,  1 user,  load average: 0.20, 0.23, 0.10
```

## 3. Password auth ditolak (hanya publickey ditawarkan)

```
$ ssh -p 62518 -o PreferredAuthentications=password -o PubkeyAuthentication=no runner@bore.pub
runner@bore.pub: Permission denied (publickey).
```

Sebelum fix, sshd tawarkan `(publickey,password)` — selepas drop-in dinamakan `00-`,
hanya `(publickey)`.

## 4. `node.sh` — pasang, keluar alamat, uji masuk

```
$ sudo bash node.sh install
 · boz-node: menyediakan runnervm48cm3 (x86_64)
  ✓ kunci awam didaftarkan untuk user 'runner'
  ✓ sshd aktif di port 22 — login kunci sahaja
  ✓ tunnel awam: ssh -p 62518 runner@bore.pub

$ ssh -p 62518 ... runner@bore.pub 'whoami; hostname'
OK user=runner host=runnervm48cm3
Ubuntu 24.04.5 LTS
```

## 5. Kebolehtularan — `install` dijalankan 2×, `status` semua hijau

```
=== install kali-1 ===   ssh -p 3136 runner@bore.pub
=== install kali-2 ===   ssh -p 12562 runner@bore.pub

=== status ===
  ✓ sshd: mendengar di port 22
  ✓ login password: dimatikan
  ✓ kunci awam: terdaftar (runner)
  ✓ tunnel: hidup (7s) — ssh -p 12562 runner@bore.pub
```

## 6. `spin-up.sh` — satu arahan dari Windows

```
$ bash spin-up.sh 120 --test
  · menghidupkan nod (120 minit) di Solelyy4/boz-lab-node
  · menunggu nod siap
  ✓ nod hidup
     ssh -p 63230 runner@bore.pub
  ✓ SSH BERJAYA
     runner@runnervm48cm3
     Ubuntu 24.04.5 LTS
     2
     Mem:  7932  877  6365
```

## 7. Bug yang ditemui & dibaiki (semasa ujian, bukan teori)

| # | Gejala | Punca | Fix |
|---|---|---|---|
| 1 | `Permission denied (publickey,password)` walau kunci betul | drop-in tulis `AllowUsers ubuntu`, runner sebenar `runner` | buang `AllowUsers` |
| 2 | Password auth kekal hidup walau drop-in `PasswordAuthentication no` | `sshd_config.d` ikut abjad, **nilai pertama menang**; `50-cloud-init.conf` mendahului `99-` | nama fail `00-boz-node.conf` |
| 3 | `bore mati: failed to run command '  · memuat turun bore...'` | `echo` status mencemari `$(bore_bin)` | status ke stderr |

## 8. Yang TIDAK diuji (jujur)

- **Oracle Cloud** — tidak didaftarkan. Langkah bertulis sahaja, belum dijalankan.
- **`muse_tunnel.sh` pada sandbox sebenar** — tiada sandbox muse.ai di sini. Yang disahkan:
  `bash -n` lulus, dan audit kandungan fail.
- **Jalur 1 (PC jadi hujung tunnel)** — PC ni tiada admin, tiada sshd, tiada Tailscale.
  Tidak dipasang.
- **Jangka hayat >350 minit** — had GitHub Actions, bukan had kod.

## 9. Pembetulan pada dakwaan awal

Aku mula-mula lapor dua "bug" dalam `muse_tunnel.sh` (baris `Proxy-Authorization` dan corak
`sk-...@openssh.com`). Selepas periksa bait fail mentah: **kedua-duanya tidak wujud**.
Rentetan `***` itu ialah lapisan redaksi pada output tool, bukan isi fail. Fail asal digunakan
semula tanpa perubahan — md5 `179574f865760ac2d93910d6b7780012`.
