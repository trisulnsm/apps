--
-- shiftx_climb.lua — Track A: log-decay rank climb (troublemakers into elite)
-- Detects ASNs moving up the top-K ladder quickly; weight falls with rank depth
-- (gain × scale / (rank × ln(rank+offset))). Elite cross bonus unchanged.
-- JSD/RBO track (shiftx_core) unchanged.
--

local Climb = {}

Climb.CFG = nil

function Climb.default_cfg()
  return {
    climb_enabled           = true,
    climb_history_n         = 20,
    climb_absent_intervals  = 10,
    climb_wrate_alert       = 15.0,
    climb_min_gain          = 3,
    climb_ignore_delta_le   = 2,
    climb_crash_in_max_rank = 8,
    climb_crash_in_score    = 10.0,
    climb_log_scale         = 30.0,
    climb_log_offset        = 2.0,
    climb_band_elite_max    = 10,
    climb_cross_elite_bonus = 4.0,
    climb_established_lookback   = 15,
    climb_fresh_max_presence     = 1,
    climb_intra_elite_min_prev   = 8,
    -- Keys seen in most of lookback (stable top-20 churn) → no climb alert
    climb_habitual_lookback      = 15,
    climb_habitual_min_presence  = 8,
    -- Cross into elite only from deep tail of top-K (e.g. 19→4, not 11→4)
    climb_cross_elite_min_prev   = 19,
    climb_skip_asns         = {
      XX    = true,
      ['0'] = true,
    },
  }
end

function Climb.set_cfg(cfg)
  Climb.CFG = cfg
end

function Climb.reset_state()
  if T then
    T.climb_state_by_meter = {}
  end
end

local function cfg()
  return Climb.CFG
end

local function is_skipped_asn(asn)
  local CFG = cfg()
  if CFG.climb_skip_asns[asn] or CFG.climb_skip_asns[tostring(asn)] then
    return true
  end
  return false
end

-- Importance at rank r: scale / (r × ln(r+offset)). Deep tail → ~0.
local function rank_weight(rank)
  local CFG = cfg()
  local r = rank + CFG.climb_log_offset
  if r < 1 then
    r = 1
  end
  return CFG.climb_log_scale / (rank * math.log(r))
end

-- Positive gain = moved up (lower rank number). Returns weighted |delta rank|.
local function weighted_rank_delta(prev_r, curr_r)
  local CFG = cfg()
  local gain = prev_r - curr_r
  if gain <= CFG.climb_ignore_delta_le then
    return 0.0, gain
  end
  local mid = 0.5 * (prev_r + curr_r)
  local wrate = gain * rank_weight(mid)
  if prev_r > CFG.climb_band_elite_max and curr_r <= CFG.climb_band_elite_max then
    if prev_r >= CFG.climb_cross_elite_min_prev then
      wrate = wrate + CFG.climb_cross_elite_bonus
    else
      wrate = 0.0
    end
  end
  return wrate, gain
end

local function new_meter_state()
  return {
    tick        = 0,
    prev_ranks  = {},
    topk_ring   = {},
    ring_head   = 0,
    ring_filled = 0,
  }
end

local function get_meter_state(meter)
  if not T.climb_state_by_meter then
    T.climb_state_by_meter = {}
  end
  if not T.climb_state_by_meter[meter] then
    T.climb_state_by_meter[meter] = new_meter_state()
  end
  return T.climb_state_by_meter[meter]
end

local function ranked_to_map(ranked)
  local m = {}
  for i, entry in ipairs(ranked) do
    m[entry.asn] = i
  end
  return m
end

local function topk_presence_count(st, asn, lookback)
  local CFG = cfg()
  local n = CFG.climb_history_n
  local span = lookback
  if st.ring_filled < span then
    span = st.ring_filled
  end
  if span <= 0 then
    return 0
  end
  local count = 0
  for i = 1, span do
    local idx = st.ring_head - i + 1
    if idx <= 0 then
      idx = idx + n
    end
    local slot = st.topk_ring[idx]
    if slot and slot[asn] then
      count = count + 1
    end
  end
  return count
end

local function is_habitual_topper(st, asn)
  local CFG = cfg()
  local lb = CFG.climb_habitual_lookback
  if st.ring_filled < lb then
    return false
  end
  return topk_presence_count(st, asn, lb) >= CFG.climb_habitual_min_presence
end

-- Seen in top-K at most N times in lookback → fresh re-entry (not MSFT 4↔1 roulette).
local function is_fresh_in_topk(st, asn)
  local CFG = cfg()
  local lb = CFG.climb_established_lookback
  if st.ring_filled < 1 then
    return true
  end
  return topk_presence_count(st, asn, lb) <= CFG.climb_fresh_max_presence
end

local function is_elite_shuffle(prev_r, curr_r)
  local CFG = cfg()
  return prev_r <= CFG.climb_band_elite_max and curr_r <= CFG.climb_band_elite_max
end

local function was_absent(st, asn, absent_n)
  if st.ring_filled < absent_n then
    return false
  end
  local CFG = cfg()
  local n = CFG.climb_history_n
  for i = 1, absent_n do
    local idx = st.ring_head - i + 1
    if idx <= 0 then
      idx = idx + n
    end
    local slot = st.topk_ring[idx]
    if slot and slot[asn] then
      return false
    end
  end
  return true
end

local function push_topk_ring(st, curr_map)
  local CFG = cfg()
  local n = CFG.climb_history_n
  st.ring_head = (st.ring_head % n) + 1
  st.topk_ring[st.ring_head] = curr_map
  if st.ring_filled < n then
    st.ring_filled = st.ring_filled + 1
  end
end

-- Process one interval; ranked = { { asn, bytes }, ... } order = rank 1..n
function Climb.process(meter, ranked)
  local CFG = cfg()
  if not CFG.climb_enabled then
    return nil
  end

  local st = get_meter_state(meter)
  st.tick = st.tick + 1
  local tick = st.tick

  if not ranked or #ranked == 0 then
    return nil
  end

  local curr = ranked_to_map(ranked)
  local max_wrate = 0.0
  local top_asn = ''
  local top_reason = ''
  local top_gain = 0
  local top_rank = 0
  local note = false

  for asn, rank in pairs(curr) do
    if not is_skipped_asn(asn) then
      local prev_r = st.prev_ranks[asn]
      if prev_r then
        local wrate, gain = weighted_rank_delta(prev_r, rank)
        if is_habitual_topper(st, asn) then
          wrate = 0.0
        elseif is_elite_shuffle(prev_r, rank) then
          if not is_fresh_in_topk(st, asn)
              or prev_r < CFG.climb_intra_elite_min_prev then
            wrate = 0.0
          end
        end
        if gain >= CFG.climb_min_gain and wrate > max_wrate then
          max_wrate = wrate
          top_asn = asn
          top_gain = gain
          top_rank = rank
          top_reason = string.format(
            'climb|wrate=%.2f|from=%d|to=%d|gain=%d',
            wrate, prev_r, rank, gain
          )
        end
      else
        local absent_n = CFG.climb_absent_intervals
        if tick > 1 and was_absent(st, asn, absent_n)
            and rank <= CFG.climb_crash_in_max_rank then
          local wrate = CFG.climb_crash_in_score
          if wrate > max_wrate then
            max_wrate = wrate
            top_asn = asn
            top_gain = 0
            top_rank = rank
            top_reason = string.format(
              'crash_in|wrate=%.2f|rank=%d|absent=%d',
              wrate, rank, absent_n
            )
          end
        end
      end
    end
  end

  if max_wrate >= CFG.climb_wrate_alert
      and st.tick >= CFG.climb_established_lookback then
    note = true
  end

  st.prev_ranks = curr
  push_topk_ring(st, curr)

  local line = string.format(
    'KEYSHIFT|meter=%d|tick=%d|climb_wrate=%.4f|climb_note=%s|climb_asn=%s|climb_rank=%d|climb_gain=%d|%s',
    meter,
    tick,
    max_wrate,
    note and '1' or '0',
    top_asn,
    top_rank,
    top_gain,
    top_reason
  )

  if T and T.logdebug then
    T.logdebug(line)
  else
    print(line)
  end

  return {
    wrate_max    = max_wrate,
    note         = note,
    note_metric  = note and 1.0 or 0.0,
    top_asn      = top_asn,
    top_rank     = top_rank,
    top_reason   = top_reason,
  }
end

return Climb
