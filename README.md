# boz-lab-node

Hos Linux percuma atas permintaan + tunnel SSH awam.

Repo ini dua benda sekali:

1. **Runner untuk `node.sh`** — workflow `ephemeral-node` hidupkan Ubuntu 24.04 dan jalankan
   `node.sh` di atasnya, kemudian laporkan alamat SSH ke issue `node-status`.
2. **Salinan `node.sh`** — fail yang sama boleh dipakai pada VPS sebenar (Oracle, Hetzner,
   sandbox) tanpa perubahan.

## Hidupkan nod

Dari PC (kit penuh ada di `~/Downloads/tunnel-kit`):

```bash
bash spin-up.sh 120 --test
```

Atau terus di GitHub: Actions → `ephemeral-node` → Run workflow.

## Pakai pada VPS sebenar

```bash
sudo bash node.sh install --key "ssh-ed25519 AAAA... kamu@pc"
sudo bash node.sh status
```

## Nota keselamatan

- Hanya kunci **awam** disimpan di sini (`authorized_keys.pub`). Kunci peribadi tidak pernah
  masuk repo.
- sshd dikunci ke kunci sahaja — `PasswordAuthentication no`, diuji dengan
  `Permission denied (publickey).`
- Nod ini **sementara**. Jangan letak data atau kredensial yang tak boleh hilang.
- Bukan hos 24/7. Kerja berterusan/proxy/mining langgar ToS GitHub Actions — guna VPS untuk itu.
