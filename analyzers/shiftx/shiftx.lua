--
-- ShiftX — Per-Meter Top-K Key shift score (RBO / novelty / JSD + CUSUM)
-- TYPE: BACKEND SCRIPT
-- Uses cg_monitor topper streaming per
--   https://docs.trisul.org/docs/lua/cg_monitor
--

require 'mkconfig'

local ShiftX = require 'shiftx_core'
local Climb  = require 'shiftx_climb'

TrisulPlugin = {

  id = {
    name = 'ShiftX',
    description = 'ASN traffic shift score from counter-group flush toppers',
    author = 'trisul',
    version_major = 1,
    version_minor = 5,
  },

  onload = function()
    local base = {
      CounterGUID = '{120A3124-E2BB-47BD-6C64-71BBB861C428}',  -- flow-asn
    }
    for k, v in pairs(ShiftX.default_shiftx_cfg()) do
      base[k] = v
    end
    for k, v in pairs(Climb.default_cfg()) do
      base[k] = v
    end

    T.active_config = make_config(
      T.env.get_config('//App/DBRoot') .. '/config/trisulnsm_shiftx.lua',
      base
    )

    ShiftX.set_cfg(T.active_config)
    Climb.set_cfg(T.active_config)
    ShiftX.reset_state()
    Climb.reset_state()
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

    ontopperflush = function(engine, key, metric)
      local lim = ShiftX.CFG.top_n or 10
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
        local key = T.active_config.CounterGUID .. '-' .. meter
        local RboCounterGroupGUID = '{22B6E494-382B-47D5-D914-591CF8572343}'

        local climb = Climb.process(meter, ranked)
        if climb then
          engine:update_counter(RboCounterGroupGUID, key, 5, 100 * climb.wrate_max)
          engine:update_counter(RboCounterGroupGUID, key, 6, climb.note_metric)
        end

        local metrics = ShiftX.process_topper_ranked(engine, meter, ranked)

        if metrics then
          engine:update_counter(RboCounterGroupGUID, key, 0, 100 * metrics.rbo)
          engine:update_counter(RboCounterGroupGUID, key, 1, 100 * metrics.novelty)
          engine:update_counter(RboCounterGroupGUID, key, 2, 100 * metrics.jsd)
          engine:update_counter(RboCounterGroupGUID, key, 3, 100 * metrics.composite)
          engine:update_counter(RboCounterGroupGUID, key, 4, 100 * metrics.alert_metric)

          return true
        end

        if climb then
          return true
        end
      end
    end,
  },
}
