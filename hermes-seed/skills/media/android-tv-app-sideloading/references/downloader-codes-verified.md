# DOWNLOADER CODES — SNAPSHOT TERKINI (SEMAK SEMULA SEBELUM GUNA)

Kod Downloader rosak dalam beberapa minggu. Fail ini = titik mula, bukan kebenaran: jalankan
`scripts/verify_downloader_codes.sh` pada setiap kod sebelum menghantar kepada BOZ.

## TV MALAYSIA — PERCUMA & SAH (app dahulu)

| App | Package / cara | Percuma dapat apa |
|---|---|---|
| rtmklik (Android TV) | Play Store `my.gov.rtm.tv` | TV1, TV2, TV6, TV Okey, Berita RTM, Sukan RTM, Parlimen |
| rtmklik (mudah alih) | Play Store `my.gov.rtm.mobile` | sama + radio |
| Tonton | Play Store `my.com.tonton.mobile` (ada versi Android TV) | TV3, ntv7, 8TV, TV9 live + ratusan drama/filem dengan iklan; TontonUp RM9.90 hanya untuk premium |
| APKPure TV store (Fire Stick) | Downloader code `8378407` | cari `rtmklik` / `tonton` di dalamnya |

Fire Stick tiada Play Store: APKPure/Aptoide → cari package di atas. Halaman APK:
`apkpure.net/rtmklik/my.gov.rtm.mobile`, `apkpure.net/tonton/my.com.tonton.mobile`.

Sandaran playlist: `https://iptv-org.github.io/iptv/countries/my.m3u` — 21 entri disenarai tetapi
hanya ~6 strim hidup (Berita RTM, TV Okey, TV6, TVS, RTM Parlimen ×2). Main dalam TiviMate
(code `272483`). Jangan jadikan playlist jawapan utama untuk Malaysia.

## DRAMA & FILEM PELBAGAI NEGARA

| App | Code | Jenis destinasi |
|---|---|---|
| CloudStream 4.8.0 | `4132632` | APK rasmi GitHub — paling lengkap, repo-driven |
| Nuvio TV | `3839657` | APK rasmi GitHub, UI TV |
| Stremio (Android TV) | `2734024` | APK strem.io |
| Kisskh | `5643293` | pixeldrain (drama Asia) |
| FilmPlus | `3300326` | APK vendor |
| Flix Vision | `6101716` | APK GitHub |
| BeeTV | `7895071` | APK vendor |
| ClipBox | `7092743` | APK vendor |
| Kodi 21.3 | `7280084` | mirror Kodi |
| TROYPOINT Toolbox | `250931` | halaman menu satu-kod |
| TiviMate (player IPTV) | `272483` | APK rasmi TiviMate |
| APKPure | `8378407` | APK store |

Repo CloudStream yang disahkan hidup:
`https://raw.githubusercontent.com/phisher98/cloudstream-extensions-phisher/builds/repo.json`

## ANIME

| App | Cara | Nota |
|---|---|---|
| Aniyomi v0.18.2.1 | `https://github.com/aniyomiorg/aniyomi/releases/download/v0.18.2.1/aniyomi-v0.18.2.1.apk` | guna URL kanonik; kod blog lama menunjuk aset bertandatangan yang tamat tempoh |
| Aniyomi extensions | `https://raw.githubusercontent.com/aniyomiorg/aniyomi-extensions/repo/index.min.json` | Settings → Browse → Extensions |
| Anime TV | `9130161` | pixeldrain |
| Kuro TV | `867907` | APK GitHub |
| BeeAnime | `9580456` | pixeldrain |
| Anilab | `2449021` | APK vendor TV |

Aniyomi UI direka untuk skrin sentuh — pada TV perlu mouse toggle; untuk pengalaman TV tulen guna
varian `-TV` (Kuro, Anilab).

## KOD MATI (JANGAN HANTAR)

| Kod | Sebab |
|---|---|
| `4692335` Streamflix Reborn | destinasi HTTP 451, ditarik |
| `4495218` Anilili | HTTP 401, aset HuggingFace gated |
| `78522` IPTV Smarters | host rasmi tak jawab (000) |
| `7238400` Aniyomi | URL aset GitHub bertandatangan sudah luput |

## SALURAN BERBAYAR (Astro Ria dll) — JANGAN JANJI PERCUMA

Astro Ria (CH 104) bukan FTA. Senarai percuma NJOI (26 saluran) **tidak** termasuk Ria; yang
percuma: TV1/TV2/TV3/Alhijrah/Sarawak, Jom Ngaji, Filem Mantap, Drama Hebat, Drama Hotpot, Lawak
Sentral, Travel & Taste, Oh My Ceria, TV Okey, ntv7, 8TV, TV9, Astro Vaanavil, Astro Awani, Bernama,
Berita RTM, Astro Tutor TV, Sukan+, Astro Prima, Astro Oasis, Astro AEC, Astro Stadium.

Jalan sah termurah (sahkan harga di njoi.com.my, jangan petik forum): NJOI Family Pack RM28/30 hari
termasuk CH 104; ala carte prepaid dilaporkan ~RM5.90/3 hari (sumber forum, bukan laman rasmi).

Kenapa strim percuma sentiasa mati:
- Relay pihak ketiga membawa Astro Ria sebagai DASH ClearKey (`#KODIPROP:inputstream.adaptive.license_key`
  dengan `kid`/`k`) pada endpoint `https://mvts.live/zes-<ch>` — diuji 31 Okt 2026: `zes-ria` = 403,
  `zes-tv1`/`zes-tv3` = 200 halaman 404 (mati).
- Endpoint CDN Astro `https://linearjitp-playback.astro.com.my/dash-wv/linear/<id>/default_primary.mpd`
  = 403 untuk semua id diuji (104, 106, 809, 810) walaupun dengan UA Chrome + Referer astro.com.my.
- Astro aktif menghantar DMCA ke GitHub (lihat `github/dmca` 2026-04-22/23, beberapa fail khusus Astro),
  jadi playlist yang membawa saluran ini dipadam dalam beberapa minggu.

Protokol jawapan: nyatakan terus Ria bukan percuma, beri angka NJOI, dan tawarkan pemantauan
berkala — jangan hantar pautan mati sebagai penyelesaian.

## PEMBATAS PERANTI

- Fire OS: pemasangan app yang diklasifikasikan "kandungan tanpa lesen" disekat ("App installation blocked").
- Fire TV Stick 4K Select (Vega OS): tiada Developer Options / Unknown Sources — Downloader tak boleh dipasang.
- Android TV / Google TV (Mi TV Stick): tiada sekatan sedemikian → peranti pilihan untuk kerja ini.
