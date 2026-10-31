# BUKTI — log ujian sebenar

Semua keluaran di bawah dari tool, bukan jangkaan. 31 Okt – 1 Nov 2026 (UTC 21:30–22:25).

---

## 1. `bore.pub` beri port tepat yang diminta

```
+ nohup /tmp/bore local 22 --to bore.pub --port 45001
INFO bore_cli::client: connected to server remote_port=45001
INFO bore_cli::client: listening at bore.pub:45001
```

Issue yang dilaporkan workflow:

```
EXPIRES_UTC=1793484218
PORT=45001
```

## 2. SSH sebenar masuk (mesin 2 core / 8 GB)

```
$ ssh -p 1739 -i keys/boz_lab runner@bore.pub
USER=runner
runnervm48cm3
OS=Ubuntu 24.04.5 LTS
2
Mem:            7932         848        6107
```

## 3. Password auth ditolak — hanya publickey

```
$ ssh -p 62518 -o PreferredAuthentications=password -o PubkeyAuthentication=no runner@bore.pub
runner@bore.pub: Permission denied (publickey).
```

## 4. PERTUKARAN NOD — alamat sama, mesin lain, jeda 40 saat

Nod lama tamat 22:03:38 UTC. Log pantauan berturut-turut:

```
22:03:22 6: runnervm48cm3 up=579            <- mesin lama
22:03:51 7: Connection timed out ...        <- nod lama mati (jeda)
22:04:18 8: WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
          fingerprint: SHA256:WKwORsrWxxuVS8a9iJDCVXctD3gBAz2f04jaVZxRbGk
          runnervm48cm3 up=444              <- sshd LAIN di port 45001 yang SAMA
```

Host key berubah = proses sshd yang berbeza = mesin berbeza. Port kekal `45001`.

Perkakasan juga berubah selepas repo dijadikan awam:

```
sebelum: 2 core / 7932 MB
selepas: 4 core / 15983 MB
```

## 5. Fail kerja pulih automatik merentas pertukaran

Ditulis pada mesin lama (22:08:55 UTC), kemudian nod 5-minit mengambil alih port 45001:

```
$ ssh -p 45001 ... 'ls ~/persist/projek; cat ~/persist/projek/nota.txt'
nombor.txt
nota.txt
ditulis pada Sat Oct 31 22:08:55 UTC 2026
```

Fail itu ditulis pada mesin SEBELUM `state.sh` berjalan. Ia kembali pada mesin baru
tanpa arahan manual — langkah "Pulihkan fail kerja" dalam workflow.

## 6. Simpanan tersulit di branch `state`

```
disimpan: 2 fail, 272 bait

$ gh api repos/Solelyy4/boz-lab-node/contents/state.tar.enc?ref=state
saiz: 272 bait
```

Kesegaran (interval 120s):

```
state branch commit terakhir : 2026-10-31T22:17:47Z
semakan pada                 : 2026-10-31T22:19:30Z
proses: 2483 bash state.sh watch
```

## 7. Pembungkus `boz-ssh.sh`

```
$ bash boz-ssh.sh 'whoami; nproc; ls ~/persist/projek'
MASUK: runner@runnervm48cm3
core=4
nombor.txt
nota.txt

$ printf 'whoami\n' | bash boz-ssh.sh
runner
```

## 8. Bug yang ditemui semasa ujian

| # | Gejala | Punca | Fix |
|---|---|---|---|
| 1 | `Permission denied (publickey,password)` | drop-in `AllowUsers ubuntu`, runner sebenar `runner` | buang `AllowUsers` |
| 2 | Password auth kekal hidup | `sshd_config.d` ikut abjad, **nilai pertama menang**; `50-cloud-init.conf` mendahului `99-` | nama fail `00-boz-node.conf` |
| 3 | `$(bore_bin)` rosak | `echo` status mencemari stdout | mesej ke stderr |
| 4 | `No environment variable PASS` | `openssl -pass env:PASS` baca persekitaran proses, `PERSIST_PASS` tak di-export | `export PASS` |
| 5 | `hostname contains invalid characters` | arahan jauh dihantar sebelum hos | susun semula argumen `boz-ssh.sh` |
| 6 | Penjaga tersalah tolak | anggap nod semasa = pengganti | penanda `last_dispatch` setempat |

## 9. Yang TIDAK diuji (jujur)

- **Pertukaran automatik 5j50m penuh** — diuji dengan nod 5-minit, bukan kitaran penuh.
  Mekanismenya sama; yang belum terbukti ialah ketahanan berhari-hari.
- **Oracle / Azure** — tidak didaftarkan. Langkah bertulis sahaja.
- **`muse_tunnel.sh` pada sandbox muse.ai sebenar** — tiada sandbox di sini.
- **Jalur 1 (PC jadi hujung tunnel)** — PC tiada admin, tiada sshd, tiada Tailscale.

## 10. Pembetulan pada dakwaan awal

Aku mula-mula lapor dua "bug" dalam `muse_tunnel.sh`. Selepas periksa bait fail mentah:
**kedua-duanya tidak wujud**. `***` itu lapisan redaksi pada output tool, bukan isi fail.
Fail asal digunakan semula tanpa perubahan — md5 `179574f865760ac2d93910d6b7780012`.
