--
-- ShiftX — Per-Meter Top-K Key shift score (RBO / novelty / JSD + CUSUM)
-- TYPE: BACKEND SCRIPT
-- Uses cg_monitor topper streaming per
--   https://docs.trisul.org/docs/lua/cg_monitor
-- onbegintopperflush(m) → ontopperflush → onendtopperflush(m) for each meter in
-- sequence. The shift algorithm runs once per meter in onendtopperflush; STATE
-- is stored per meter in shift_state_by_meter.
--

require 'mkconfig'

-- =============================================================================
-- CONFIG  — defaults; override via trisulnsm_shiftx.lua (see onload)
-- =============================================================================
local function default_shiftx_cfg()
  return {
    -- Top-K kept from each meter's topper stream (first K callbacks are highest)
    top_n            = 10,
    novelty_window   = 60,
    ema_alpha        = 0.08,
    other_mass       = 0.15,
    rbo_p            = 0.90,
    cusum_k          = 0.06,
    cusum_h          = 0.45,
    w_rbo            = 0.40,
    w_novelty        = 0.40,
    w_jsd            = 0.20,
    whitelist        = {
      [15169]=true,
      [16509]=true,
      [32934]=true,
      [13335]=true,
    },

  }
end

-- Active CFG table (mutated in onload)
local CFG

local CUSUM_BASELINE_ALPHA = 0.05

-- Fresh algorithm state for one meter (persists across 60s intervals).
local function new_shift_state()
  return {
    tick               = 0,
    prev_ranked        = nil,
    ema_dist           = nil,
    novelty_ring       = {},
    novelty_head       = 0,
    seen_ever          = {},
    cusum_pos          = 0.0,
    cusum_neg          = 0.0,
    cusum_baseline_ema = nil,
  }
end

-- per meter state 
local function get_shift_state(meter)
  if not T.shift_state_by_meter then
    T.shift_state_by_meter = {}
  end
  local t = T.shift_state_by_meter
  if not t[meter] then
    t[meter] = new_shift_state()
  end
  return t[meter]
end

-- ---------------------------------------------------------------------------
-- MATH HELPERS
-- ---------------------------------------------------------------------------
local function ln(x)
  return math.log(x)
end

local function harmonic(n)
  local h = 0.0
  for i = 1, n do h = h + 1.0 / i end
  return h
end

local function make_distribution(ranked)
  local total = 0.0
  for _, entry in ipairs(ranked) do
    total = total + entry.bytes
  end
  if total == 0 then return nil end

  local visible = 1.0 - CFG.other_mass
  local n       = #ranked
  local H_n     = harmonic(n)
  local dist    = {}

  for i, entry in ipairs(ranked) do
    local vol_share  = entry.bytes / total
    local rank_w     = (1.0 / i) / H_n
    local blended    = 0.4 * vol_share + 0.6 * (vol_share * rank_w * n)
    dist[entry.asn]  = blended
  end

  local s = 0.0
  for _, v in pairs(dist) do s = s + v end
  for asn, v in pairs(dist) do dist[asn] = (v / s) * visible end

  dist['OTHER'] = CFG.other_mass
  return dist
end

local function update_ema(ema, new_dist)
  if ema == nil then
    local copy = {}
    for k, v in pairs(new_dist) do copy[k] = v end
    return copy
  end

  local alpha  = CFG.ema_alpha
  local result = {}
  local all_keys = {}
  for k in pairs(ema)      do all_keys[k] = true end
  for k in pairs(new_dist) do all_keys[k] = true end

  for k in pairs(all_keys) do
    local e = ema[k]      or 0.0
    local n = new_dist[k] or 0.0
    result[k] = alpha * n + (1.0 - alpha) * e
  end
  return result
end

local function rank_weighted_jsd(p, q)
  local EPSILON = 1e-10
  local all_keys = {}
  for k in pairs(p) do all_keys[k] = true end
  for k in pairs(q) do all_keys[k] = true end

  local m = {}
  for k in pairs(all_keys) do
    m[k] = 0.5 * ((p[k] or 0.0) + (q[k] or 0.0))
  end

  local function kl(a, b)
    local sum = 0.0
    for k in pairs(all_keys) do
      local ak = (a[k] or 0.0) + EPSILON
      local bk = (b[k] or 0.0) + EPSILON
      sum = sum + ak * ln(ak / bk)
    end
    return sum
  end

  local jsd_sq = 0.5 * kl(p, m) + 0.5 * kl(q, m)
  jsd_sq = math.max(0.0, math.min(1.0, jsd_sq))
  return math.sqrt(jsd_sq)
end

local function novelty_score(st, ranked)
  local historical = {}
  for _, asn_set in ipairs(st.novelty_ring) do
    for asn in pairs(asn_set) do
      historical[asn] = true
    end
  end

  local n   = #ranked
  local H_n = harmonic(n)
  local score = 0.0

  for i, entry in ipairs(ranked) do
    local asn = entry.asn
    if not (CFG.whitelist[asn] or CFG.whitelist[tostring(asn)]) then
      local nov = 0.0
      if not historical[asn] then
        nov = 1.0
      elseif not st.seen_ever[asn] then
        nov = 0.5
      end
      local rank_w = (1.0 / i) / H_n
      score = score + nov * rank_w
    end
  end

  return math.min(score, 1.0)
end

local function update_novelty_ring(st, ranked)
  local asn_set = {}
  for _, entry in ipairs(ranked) do
    asn_set[entry.asn] = true
    st.seen_ever[entry.asn] = true
  end

  st.novelty_head = (st.novelty_head % CFG.novelty_window) + 1
  st.novelty_ring[st.novelty_head] = asn_set
end

local function rbo_distance(prev_ranked, curr_ranked)
  local p = CFG.rbo_p
  local n = math.min(#prev_ranked, #curr_ranked)

  local prev_list = {}
  local curr_list = {}
  for i, e in ipairs(prev_ranked) do prev_list[i] = e.asn end
  for i, e in ipairs(curr_ranked) do curr_list[i] = e.asn end

  local overlap_sum = 0.0
  local weight_sum  = 0.0

  local prev_set = {}
  local curr_set = {}
  local intersect_count = 0

  for d = 1, n do
    local pa = prev_list[d]
    local ca = curr_list[d]

    prev_set[pa] = true
    curr_set[ca] = true

    if curr_set[pa] then intersect_count = intersect_count + 1 end
    if prev_set[ca] and ca ~= pa then intersect_count = intersect_count + 1 end
    if pa == ca then intersect_count = intersect_count - 1 end

    local agreement_at_d = intersect_count / d
    local weight = (1.0 - p) * (p ^ (d - 1))

    overlap_sum = overlap_sum + weight * agreement_at_d
    weight_sum  = weight_sum  + weight
  end

  local rbo_sim = overlap_sum / weight_sum
  return 1.0 - rbo_sim
end

local function cusum_update(st, composite_score, baseline_mean)
  local deviation = composite_score - baseline_mean
  st.cusum_pos = math.max(0.0, st.cusum_pos + deviation - CFG.cusum_k)
  st.cusum_neg = math.max(0.0, st.cusum_neg - deviation - CFG.cusum_k)

  local alert = (st.cusum_pos > CFG.cusum_h) or
                (st.cusum_neg > CFG.cusum_h)
  if alert then
    st.cusum_pos = 0.0
    st.cusum_neg = 0.0
  end
  return alert
end

local function format_output(meter, tick, scores, alert, curr_dist, baseline_dist)
  local all_keys = {}
  for k in pairs(curr_dist)     do all_keys[k] = true end
  for k in pairs(baseline_dist) do all_keys[k] = true end

  local deltas = {}
  for k in pairs(all_keys) do
    if k ~= 'OTHER' then
      local delta = (curr_dist[k] or 0.0) - (baseline_dist[k] or 0.0)
      table.insert(deltas, { asn = k, delta = delta })
    end
  end
  table.sort(deltas, function(a, b) return math.abs(a.delta) > math.abs(b.delta) end)

  local movers = {}
  for i = 1, math.min(5, #deltas) do
    local d = deltas[i]
    local sign = d.delta >= 0 and '+' or ''
    table.insert(movers, string.format('%s(%s%.3f)', d.asn, sign, d.delta))
  end

  return string.format(
    'KEYSHIFT|meter=%d|tick=%d|rbo=%.4f|novelty=%.4f|jsd=%.4f|composite=%.4f|alert=%s|movers=%s',
    meter,
    tick,
    scores.rbo,
    scores.novelty,
    scores.jsd,
    scores.composite,
    alert and '1' or '0',
    table.concat(movers, ',')
  )
end

local function update_cusum_baseline(st, composite)
  if st.cusum_baseline_ema == nil then
    st.cusum_baseline_ema = composite
  else
    st.cusum_baseline_ema = CUSUM_BASELINE_ALPHA * composite
                       + (1.0 - CUSUM_BASELINE_ALPHA) * st.cusum_baseline_ema
  end
  return st.cusum_baseline_ema
end


-- =============================================================================
-- Process one interval for one meter: ranked = { { asn, bytes }, ... }
-- Returns a metrics table on success { rbo, novelty, jsd, composite, alert, ... };
-- nil on error or warmup (no counter push on warmup).
-- =============================================================================
local function process_topper_ranked(engine, meter, a)
  local st = get_shift_state(meter)
  st.tick = st.tick + 1
  local tick = st.tick

  if not a or #a == 0 then
    print(string.format('KEYSHIFT|meter=%d|tick=%d|error=empty_input', meter, tick))
    return nil
  end

  local ranked = {}
  for i = 1, math.min(CFG.top_n, #a) do
    ranked[i] = a[i]
  end

  local curr_dist = make_distribution(ranked)
  if not curr_dist then
    print(string.format('KEYSHIFT|meter=%d|tick=%d|error=zero_bytes', meter, tick))
    return nil
  end

  st.ema_dist = update_ema(st.ema_dist, curr_dist)

  local nov_score = novelty_score(st, ranked)
  update_novelty_ring(st, ranked)

  if st.prev_ranked == nil then
    st.prev_ranked = ranked
    print(string.format('KEYSHIFT|meter=%d|tick=%d|status=warmup|novelty=%.4f',
          meter, tick, nov_score))
    return nil
  end

  local jsd_score = rank_weighted_jsd(curr_dist, st.ema_dist)
  local rbo_score = rbo_distance(st.prev_ranked, ranked)

  local composite = CFG.w_rbo     * rbo_score
                  + CFG.w_novelty * nov_score
                  + CFG.w_jsd     * jsd_score

  local cusum_mean = update_cusum_baseline(st, composite)
  local alert      = cusum_update(st, composite, cusum_mean)

  local scores = {
    rbo       = rbo_score,
    novelty   = nov_score,
    jsd       = jsd_score,
    composite = composite,
  }
  local line = format_output(meter, tick, scores, alert, curr_dist, st.ema_dist)
  T.logdebug(line)

  st.prev_ranked = ranked

  local out = {
    meter         = meter,
    key           = tostring(meter),
    tick          = tick,
    rbo           = rbo_score,
    novelty       = nov_score,
    jsd           = jsd_score,
    composite     = composite,
    alert         = alert,
    alert_metric  = alert and 1.0 or 0.0,
    cusum_mean    = cusum_mean,
  }
  return out
end

-- ---------------------------------------------------------------------------
-- Trisul plugin
-- ---------------------------------------------------------------------------
TrisulPlugin = {

  id = {
    name = 'ShiftX',
    description = 'ASN traffic shift score from counter-group flush toppers',
    author = 'trisul',
    version_major = 1,
    version_minor = 2,
  },

  onload = function()
    local base = {
      CounterGUID = '{120A3124-E2BB-47BD-6C64-71BBB861C428}',  -- flow-asn 
    }
    for k, v in pairs(default_shiftx_cfg()) do
      base[k] = v
    end

    T.active_config = make_config(
      T.env.get_config('//App/DBRoot') .. '/config/trisulnsm_shiftx.lua',
      base
    )

    CFG = T.active_config
    T.shift_state_by_meter = {}
    T._topper_cur = nil
    T._topper_meter = nil
  end,

  cg_monitor = {

    counter_guid = function()
      if not T.active_config then
        TrisulPlugin.onload()
      end
      return T.active_config.CounterGUID
    end,


    onbegintopperflush = function(engine, timestamp, meter)
      T._topper_meter = meter
      T._topper_cur = {}

      return true
    end,

    -- Per docs: each topper item for this meter; stream is ordered by Trisul (largest first).
    ontopperflush = function(engine, key, metric)
      local lim = CFG.top_n or 10
      if not T._topper_cur or #T._topper_cur >= lim then return end
      if key == 'SYS:GROUP_TOTALS' then return end

      local m = tonumber(metric) or 0.0
      table.insert(T._topper_cur, { asn = key, bytes = m })

    end,

    onendtopperflush = function(engine, meter)
      local ranked = T._topper_cur


      T._topper_cur = nil
      T._topper_meter = nil
      if ranked and meter ~= nil and #ranked > 0 then
        local metrics = process_topper_ranked(engine, meter, ranked)

        if metrics then
          local key=T.active_config.CounterGUID.."-"..meter
          -- Output counter group (ShiftX Metrics in rbocounter.lua); key = tostring(source meter index)
          -- multiply by 100 to get integer numbers for metrics
          local RboCounterGroupGUID = '{22B6E494-382B-47D5-D914-591CF8572343}'

          engine:update_counter(RboCounterGroupGUID,key, 0, 100*metrics.rbo)
          engine:update_counter(RboCounterGroupGUID,key, 1, 100*metrics.novelty)
          engine:update_counter(RboCounterGroupGUID,key, 2, 100*metrics.jsd)
          engine:update_counter(RboCounterGroupGUID,key, 3, 100*metrics.composite)
          engine:update_counter(RboCounterGroupGUID,key, 4, 100*metrics.alert_metric)


          return true

        end
      end
    end,
  },
}
