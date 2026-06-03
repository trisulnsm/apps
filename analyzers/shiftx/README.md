# ShiftX

Backend Trisul LUA counter-group [topper flush](https://docs.trisul.org/docs/lua/cg_monitor) (top‑K keys per interval), scores how much the ranking mix changed versus recent history, and publishes gauges to the **ShiftX Metrics** counter group defined in `rbocounter.lua`. Go to Retro Counters/ ShiftX to see results.


## Streaming algorithm

Trisul's engine streams top-K sketches continuously per meter (received, transmit etc). This algorithm builds a builds a distribution over the current top‑K keys, compares it to an EMA baseline and the previous interval’s ranking (rank‑biased overlap, novelty, Jensen–Shannon–style divergence), combines those into one score, and tracks it with a CUSUM-style detector. 

The first interval per meter is warmup only (no full score). Script logs a `KEYSHIFT|...` line when it emits scores; metrics are also written with `engine:update_counter` (values scaled ×100 for integer-friendly gauges).

## Install

Web Admin ->  **Manage → Apps**, install the Shift Trisul App. 

## Configuration

Overrides are merged from a probe config file (path from `//App/DBRoot`):

Typically

`/usr/local/var/lib/trisul-probe/domain0/probe0/context0/config/trisulnsm_shiftx.lua`


```lua
return {
  CounterGUID = "{120A3124-E2BB-47BD-6C64-71BBB861C428}",
  top_n = 10,
  novelty_window = 60,
  ema_alpha = 0.08,
  other_mass = 0.15,
  rbo_p = 0.90,
  cusum_k = 0.06,
  cusum_h = 0.45,
  w_rbo = 0.40,
  w_novelty = 0.40,
  w_jsd = 0.20,
  whitelist = {
    [15169] = true,  -- example: ASN to ignore for novelty
  },
}
```

### Parameters

| Parameter | Role |
|-----------|------|
| **CounterGUID** | Counter group to attach the **cg_monitor** script to (must match the group whose toppers you want). Default in code is the flow‑ASN group; set to your environment’s GUID. |
| **top_n** | How many topper callbacks to keep per meter (stream is largest‑first). |
| **novelty_window** | Minutes of history (ring) for “new key in top‑K” novelty. |
| **ema_alpha** | EMA blend for the baseline distribution (0–1). |
| **other_mass** | Probability reserved for keys outside the top‑K slice. |
| **rbo_p** | Rank‑biased overlap persistence (weights top ranks). |
| **cusum_k** / **cusum_h** | CUSUM slack and threshold on the composite score. |
| **w_rbo** / **w_novelty** / **w_jsd** | Weights for the composite score (should sum to 1.0 if you want a normalized blend). |
| **whitelist** | Table of key IDs (e.g. ASNs) excluded from novelty scoring. |

### Output metrics (ShiftX Metrics CG)

Defined in `rbocounter.lua` (GUID `{22B6E494-382B-47D5-D914-591CF8572343}`). Each **key** is `{CounterGUID}-{meter}` (meter = source topper meter index). Gauges: RBO, Novelty, JSD, Composite, Alert (meters 0–4). Values are written as **score × 100**.


## Track A — rank climb (`shiftx_climb.lua`)

**Log-decay rank velocity** plus filters for stable top-K churn: habitual toppers suppressed; intra-elite shuffles only when fresh (≤1 lookback hit) from rank ≥8; cross-elite only from deep tail (`climb_cross_elite_min_prev`, default 19). `XX` / ASN `0` skipped. Meters **ClimbRate** (5) and **ClimbNote** (6).

Override via `trisulnsm_shiftx.lua`: `climb_wrate_alert`, `climb_log_scale`, `climb_habitual_min_presence`, `climb_cross_elite_min_prev`, etc. (`Climb.default_cfg()`).

Default **`top_n = 30`** (was 10) for topper ingest; JSD/RBO track unchanged.

## Offline testing

See [`test/README.md`](test/README.md) — export `.topi` topper history to Lua fixtures with Ruby, replay through `shiftx_core.lua` + `shiftx_climb.lua` with the Lua harness.

UPDATES
=======

````
1.0.5   May 23 2026      shiftx_climb habitual/fresh/cross-elite filters; stable_m1 harness
1.0.4   May 23 2026      shiftx_climb log-decay rank weighting (replaces step bands)
1.0.3   May 23 2026      shiftx_climb.lua Track A rank climb; top_n=30; meters ClimbRate/ClimbNote
1.0.2   May 23 2026      shiftx_core.lua extract; offline test harness under test/
1.0.1   Apr 17 2026      First cut
```` 
