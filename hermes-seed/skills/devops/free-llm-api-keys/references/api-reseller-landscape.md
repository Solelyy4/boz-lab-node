# Cheap / bulk API-key market — layers, evidence, risks

Answer "cari tempat jual token murah" with layers, not a list. Prices move weekly; these are the
2026-10 tiers to orient against, and the technique below re-derives current numbers.

## Layer table (cheapest first)

| Layer | Example | Effective rate vs list | Reality |
|---|---|---|---|
| Free tiers | Token Harbor `:free`, Z.ai `GLM-4.7-Flash` (free in/out), Groq, Gemini free, OpenRouter `:free` | 0 | Stack several before paying anything |
| Regional marketplaces | Shopee/Tokopedia/Taobao listings of "80M tokens", "200M credits" | ~2% | Account resale in marketplace clothing |
| Reseller gateways | credit-plan shops on Telegram (e.g. pay $40 → $500 credits) | 8–10% | Relay; prompts visible to the operator |
| Official gateways | DeepInfra DeepSeek-V4-Flash $0.06/$0.18; Novita GLM-5.3-Flash $0.075/$0.25; Z.ai GLM-4.7-FlashX $0.07/$0.40; Together Qwen3.8-Flash $0.09/$0.28; DeepSeek off-peak $0.15/$0.60 | 100% | Safe, OpenAI-compatible, `custom_providers` ready |
| Subscription plans | GLM Coding Lite ~$12–18/mo (10k credits/week); Kimi Plus $19 → Ultra $199 | flat | Good when using agent CLIs all day |
| Social resale | Telegram "harvested" key shops, DM sellers on TikTok/Threads | 5–10% | Farmed accounts; the shop may even post a bounty for an auth-bypass PoC |

## Enumerating sellers (works, in this order)

1. `web_search` with `site:t.me/s <keywords>` — Telegram channel previews are indexed, private
groups are not. Sweep several keyword sets (English, Malay/Indonesian, Chinese) because price
posts are usually in the seller's own language.
2. Scrape the public preview `https://t.me/s/<handle>` and grep the post text for prices and
keywords (`api key`, `ключ`, `аккаунт`, `kredit`, `relay`, `$`/`RM`/`Rp`). This yields the seller's
own price list without joining anything.
3. DIRECTORY SEARCH IS MOSTLY NOISE: `lyzem.com` renders results client-side and returns generic
"API" channels, `tgstat.ru` and `telemetr.io` sit behind a Cloudflare challenge. Do not burn time
on them; a curated directory (a gateway-comparison site listing vendors with prices) is worth more
than any of them.
4. Verify each candidate gateway with the unauthenticated `/v1/models` probe — **401 = real gateway**,
404/timeout/HTML = not a product. Then run the five-part functional test before recommending it.

## Risk rules (state once, then work)

- 2–10% of list = resale. Assume the key dies without notice, the operator can read every prompt,
and the model behind the label may be cheaper than advertised.
- Never wire resale keys as a primary provider, and never near wallet/crypto or client data.
- Prefer the official gateway at $0.06–0.15/1M over any 2% offer for anything that must keep
running (cron, bots, agents).
- Free tiers may train on prompts — the same caution applies to the `:free` route of a paid key.
