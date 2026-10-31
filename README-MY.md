# NOD KAU — SSH ke mesin yang tak pernah mati

Kau tak perlu buat apa-apa. Satu arahan, dan ia berfungsi hari ini, esok, minggu depan.

```bash
bash ~/Downloads/tunnel-kit/boz-ssh.sh
```

Atau jalankan satu arahan terus:

```bash
bash ~/Downloads/tunnel-kit/boz-ssh.sh 'ls ~/persist'
```

**Alamatnya tak berubah.** Mesin di belakangnya berganti sendiri setiap ~5 jam 50 minit.
Kau takkan nampak apa-apa kecuali satu jeda ~40 saat.

---

## Apa yang berjalan sendiri

| Benda | Siapa uruskan | Kekerapan |
|---|---|---|
| Nod tamat → pengganti dihantar | `keeper.sh` (cron Hermes) | setiap 10 minit |
| Alamat kekal `bore.pub:45001` | `node.sh install --port` | setiap nod baru |
| Fail kau disimpan & dipulih | `state.sh` | simpan tiap 2 min, pulih masa boot |
| Laporan alamat | issue `node-status` di GitHub | setiap pertukaran |

Nod sekarang: Ubuntu 24.04 · **4 core · 16 GB RAM · 72 GB disk**.

---

## Fail kau — letak dalam `~/persist`

Hanya `~/persist` yang kekal. Di luar itu hilang bila mesin berganti.

```bash
bash boz-ssh.sh 'mkdir -p ~/persist/projek && echo hello > ~/persist/projek/a.txt'
```

Simpanan disulitkan (AES-256) sebelum keluar, disimpan di branch `state` repo
`Solelyy4/boz-lab-node`. Nod baru tarik balik dan nyahsulit masa mula. Tanpa passphrase
(`~/.boz-node/pass`), blob itu tidak berguna.

---

## Bila sesuatu rosak

```bash
bash ~/Downloads/tunnel-kit/keeper.sh        # paksa semak + hantar pengganti kalau perlu
bash ~/Downloads/tunnel-kit/keeper.sh --force # paksa nod baru sekarang
tail -20 ~/.boz-node/keeper.log              # apa penjaga dah buat
```

Kalau SSH tersangkut: tunggu 2 minit dan cuba lagi. Penjaga akan pulihkan sendiri.

---

## Isi kit

| Fail | Fungsi |
|---|---|
| `boz-ssh.sh` | Masuk ke nod (pembungkus, alamat tetap) |
| `keeper.sh` | Penjaga — hantar pengganti sebelum nod tamat |
| `node.sh` | Sediakan sshd + tunnel pada mana-mana Linux |
| `state.sh` | Simpan/pulih `~/persist` (tersulit) |
| `spin-up.sh` | Hidupkan nod manual (jarang perlu) |
| `muse_tunnel.sh` | Script asal kau — untuk kes sandbox yang reset `/etc` |

---

## Batas jujur

- **Bukan VPS kekal.** GitHub Actions hadkan satu job 350 minit. Sistem ini menyelesaikannya
  dengan berganti nod tanpa menukar alamat — bukan dengan mengekalkan satu mesin.
- **Jeda ~40 saat** setiap pertukaran (diukur, bukan dianggarkan).
- **Proses panjang mati** bila nod berganti. Kalau kau jalankan bot berterusan, ia perlu
  auto-mula semula — letak dalam `~/persist/start.sh` dan panggil dari situ.
- **Repo awam.** Hanya kunci *awam* dan blob tersulit ada di sana. Kunci peribadi kekal di PC.
- **GitHub Actions bukan untuk mining/proxy berterusan.** Untuk kerja 24/7 sebenar yang serius,
  VPS berbayar murah (Hetzner €3.79) atau Oracle Always Free masih jawapan yang betul —
  dan `node.sh` yang sama boleh dipakai di sana tanpa ubah satu baris.
