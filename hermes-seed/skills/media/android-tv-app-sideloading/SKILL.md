---
name: android-tv-app-sideloading
description: "Use when sideloading apps or codes on TV sticks."
version: 1.0.0
author: BOZ + BOZ-AGENT
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [android-tv, fire-tv, downloader, sideload, iptv, streaming, malaysia]
---

# ANDROID TV / FIRE TV SIDELOADING

Kelas kerja: BOZ minta "downloader code", cara pasang app luar store pada Mi TV Stick /
Fire TV Stick / Google TV, sumber streaming percuma, playlist IPTV, atau app yang tiada
dalam store rasmi.

## WHEN TO USE

- BOZ sebut "downloader code", Downloader app, sideload, atau APK untuk TV.
- BOZ sebut peranti: Mi TV Stick, Mi Box, Fire TV Stick, Fire TV, Google TV, Chromecast dengan
  Google TV, Android TV box.
- BOZ minta siaran TV percuma (termasuk saluran Malaysia), drama/filem pelbagai negara percuma,
  anime percuma, atau playlist IPTV/M3U untuk dimainkan di TV.
- BOZ minta app yang tiada dalam Play Store / Amazon Appstore dan perlu dipasang pada peranti TV.

## HARD RULES

- **Tiada kod dihantar tanpa disemak sesi itu juga.** Setiap kod melalui `scripts/verify_downloader_codes.sh`
  (destinasi sebenar) DAN semakan status HTTP destinasi. Kod dari blog/listicle = calon, bukan jawapan.
- **Bahasa & bentuk:** BM, satu jadual per kategori (`App | Code | Status`), langkah pasang pendek,
  fail `.md` penuh ke `C:\Users\zahin\Downloads`, balasan chat + `MEDIA:` path. BOZ mahu ringkas;
  butiran masuk fail.
- **Senaraikan kod mati secara eksplisit** ("kod mati — jangan buang masa"). Ia jimat BOZ menaip
  lima kod gagal di remote TV.
- **Bezakankan peranti setiap kali:** Android TV / Google TV → pasang terus dari Play Store;
  Fire OS → Downloader + kod; Vega OS (Fire TV Stick 4K Select) → langsung tiada sideload.
- **Percuma bermakna percuma**: jangan cadang apa-apa yang perlu langganan sebagai jawapan utama.
  Kalau app ada free tier (Tonton), sebut free tier itu dan saluran apa yang terbuka.

## PROSEDUR

1. **Kenal pasti OS peranti** — Android TV/Google TV, Fire OS, atau Vega OS. Ini menentukan sama ada
   kod diperlukan langsung.
2. **Kumpul kod calon** dari 2-3 senarai (troypoint, firestickhacks, husham, toptvtips, firestick.io),
   kemudian buang semua yang gagal disemak.
3. **Semak destinasi:** `curl -s "https://go.aftvnews.com/<kod>+"` → destinasi berada dalam
   `<span id="copy_url">`. Skrip `scripts/verify_downloader_codes.sh` buat ini untuk senarai kod.
4. **Semak destinasi hidup:** `curl -sL -m 40 -r 0-2048 -o /dev/null -w "%{http_code}"`
   → `200`/`206` lulus, `302` ikut dengan `-L` dulu, `401`/`403`/`451`/`000` = mati.
5. **App GitHub: langkau kod blog.** Resolve tag + aset terbaru melalui `api.github.com/repos/<owner>/<repo>/releases/latest`
   dan beri URL kanonik `releases/download/<tag>/<aset>`. Downloader terima URL penuh; URL ini kekal,
   kod blog selalunya menunjuk ke URL aset bertandatangan yang tamat tempoh.
6. **TV Malaysia percuma: app dahulu, playlist kemudian.** App rasmi percuma (RTM Klik, Tonton)
   lebih stabil daripada playlist iptv-org. Playlist = sandaran, dan kena uji strim satu per satu.
7. **Tulis fail cheat-sheet + balas chat** dengan jadual kategori: TV Malaysia / drama-film /
anime, setiap baris ada status semakan.

## PITFALLS

- Senarai kod blog cepat rosak: dalam satu snapshot, beberapa kod resolve ke `451` (ditarik),
  `401` (aset gated), atau host mati. Semak semua, jangan warisi.
- Halaman `go.aftvnews.com/<kod>+` ialah halaman info (kod + short URL + destinasi), bukan redirect.
  Parse `id="copy_url"`; jangan ambil href pertama — itu favicon/recaptcha/logo.
- Probe dengan curl, satu demi satu atau 3-4 worker + `sleep 0.4`. Burst 8+ worker menyebabkan host
  menggugurkan sambungan (`HTTP 000`) yang menyamar sebagai "kod tidak sah".
- Python `urllib` ke host shortener itu dapat `RemoteDisconnected`; curl berjaya. Guna curl.
- `302` dari `github.com` adalah normal (redirect ke `objects.githubusercontent.com`); ikut `-L`
  sebelum menghukum kod sebagai mati.
- Pautan MediaFire dalam kod sering ke `/file_premium/` yang perlukan akaun premium — tanda tidak
  boleh diharap; utamakan APK rasmi/GitHub.
- Playlist negara iptv-org menyenaraikan lebih banyak saluran daripada yang benar-benar strim.
  Uji setiap URL (`curl -r 0-2048`) dan laporkan kiraan hidup yang sebenar, bukan jumlah `#EXTINF`.
- Fire OS menyekat pemasangan app yang diklasifikasikan "kandungan tanpa lesen" — BOZ akan nampak
  "App installation blocked". Mi TV Stick / Google TV tiada sekatan ini. Sebut di awal, jangan biar
  dia terjumpa sendiri.
- App anime/film pihak ketiga selalunya UI telefon: pada TV perlu mouse toggle atau pilih app yang
  memang ada varian `-TV` (Kuro, Anilab, Streamflix only-tv).

## SUPPORT FILES

- `references/downloader-codes-verified.md` — snapshot jadual kod mengikut kategori, kod mati,
  repo CloudStream/Aniyomi yang hidup, fakta app TV Malaysia (package ID, free tier).
- `scripts/verify_downloader_codes.sh` — probe kod → destinasi → status HTTP, output TSV.
