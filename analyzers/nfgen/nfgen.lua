local bit = require("bit")
require("mkconfig")

local Fields  = require("netflow_fields")
local Encoder = require("netflow_encoder")
local UdpSender = require("udp_sender")

-- flow:state() bits for a finished flow, as used by trisul-scripts/backend_scripts/netflow_generator
local FLOW_DONE_MASK = 0x0900

-- T.nfgen.exported[flow_id] entries are arrays, indexed by:
local E_AZB, E_AZP, E_ZAB, E_ZAP = 1, 2, 3, 4  -- running totals already exported
local E_START, E_END             = 5, 6        -- flow start (tells a reused 5-tuple apart), last export end
local E_SEEN, E_DONE             = 7, 8        -- last flushed (os.time), finished flow

-- Drop entries not flushed for longer than their TTL. Remembers the latest start among dropped
-- unfinished flows: if one of them is flushed again it must not be exported from zero.
local function forget_flows(now, ttl, done_ttl)
  local tracked = T.nfgen.exported
  for id, e in pairs(tracked) do
    if now - e[E_SEEN] > (e[E_DONE] and done_ttl or ttl) then
      if not e[E_DONE] and e[E_START] > T.nfgen.forgot_upto then
        T.nfgen.forgot_upto = e[E_START]
      end
      tracked[id] = nil
      T.nfgen.tracked_count = T.nfgen.tracked_count - 1
    end
  end
end

TrisulPlugin = {
  id = {
    name        = "NetFlow Generator",
    description = "Export Trisul flows as NetFlow v5, v9 or IPFIX(v10)",
    author      = "trisul",
    version_major = 1,
    version_minor = 0,
  },

  onload = function()
    T.config = make_config(
      T.env.get_config("//App/DBRoot") .. "/config/trisulnsm_nfgen.lua",
      {
        enabled                  = true,
        netflow_version          = "v10",
        collector_ip             = "127.0.0.1",
        collector_port           = 2055,
        template_id_base         = 256,
        template_refresh_seconds = 15,
        template_refresh_packets = 10,
        export_only_terminated   = false,
        source_id_base           = 5000,
        max_records_per_packet   = 24,
        tag_template_ids         = { "COUNTRY", "TLS-SNI", "HOSTNAME", "ASN", "ALERT" },
        tag_field_max_len        = 64,
        ipfix_enterprise_number  = 39499,
        tag_v9_field_type_base   = 200,
        exported_ttl_seconds     = 3600,    -- remember an unfinished flow's exported totals this long
        done_ttl_seconds         = 300,     -- ... and a finished flow's (in case it is flushed again)
        max_tracked_flows        = 1000000, -- per engine; 0 = no limit
      }
    )

    -- Normalise netflow_version → "v5" | "v9" | "v10"
    local version = tostring(T.config.netflow_version or "v10"):lower()
    if version == "5" then
      version = "v5"
    elseif version == "9" then
      version = "v9"
    elseif version == "10" or version == "ipfix" then
      version = "v10"
    end
    if version ~= "v5" and version ~= "v9" and version ~= "v10" then
      T.logerror("nfgen: invalid netflow_version, defaulting to v10")
      version = "v10"
    end
    T.config.netflow_version = version
    T.loginfo("nfgen: starting with netflow_version=" .. version)

    T.nfgen = {
      fields     = Fields.new(T.config),
      sender     = nil,
      state      = nil,
      current_ts = nil,
      -- per flow id: running totals already exported, so the next export of a long flow
      -- carries only what is new (IE 1/2 are delta counts; Trisul flushes long flows more than once)
      exported      = {},
      tracked_count = 0,
      -- latest start time among unfinished flows dropped from `exported` (see forget_flows)
      forgot_upto   = 0,
      skipped       = 0,
    }
  end,

  onunload = function()
    if T.nfgen and T.nfgen.sender then
      T.nfgen.sender:close()
      T.nfgen.sender = nil
    end
    T.nfgen = nil
  end,

  sg_monitor = {
    session_guid = "{99A78737-4B41-4387-8F31-8077DB917336}",

    onbeginflush = function(engine, ts)
      if not T.config.enabled then return end
      -- Trisul calls onbeginflush(engine) / onendflush(engine) without a timestamp
      ts = ts or os.time()

      if T.nfgen.sender == nil then
        T.nfgen.sender = UdpSender.new(T.config.collector_ip, T.config.collector_port)
      end

      if T.nfgen.state == nil then
        T.nfgen.state = Encoder.new_engine_state(engine:instanceid(), T.config, ts)
      end

      T.nfgen.current_ts = ts
      T.nfgen.state.last_template_send_sec = 0
      Encoder.reset_batch(T.nfgen.state)
    end,

    onflush = function(engine, flow)
      if not T.config.enabled then return end

      local sender = T.nfgen.sender
      if sender == nil or not sender:is_open() then return end

      local state = T.nfgen.state
      if state == nil then
        local now = T.nfgen.current_ts or os.time()
        state = Encoder.new_engine_state(engine:instanceid(), T.config, now)
        T.nfgen.state = state
        Encoder.reset_batch(state)
      end

      local now = T.nfgen.current_ts or os.time()
      local key, template_fields, ctx = T.nfgen.fields:template_for_flow(flow)

      -- terminated / closed flows (same state bits the original trisul-scripts nfgen used)
      local done = bit.band(ctx.state, FLOW_DONE_MASK) ~= 0
      if T.config.export_only_terminated and not done then return end

      local tracked = T.nfgen.exported
      local prev = tracked[ctx.flow_id]

      -- same 5-tuple but a different start: a new flow reusing the key, nothing to subtract
      if prev and prev[E_START] ~= ctx.start_sec then
        prev = nil
      end

      local skip = false
      if prev == nil and T.nfgen.forgot_upto > 0 and ctx.start_sec <= T.nfgen.forgot_upto then
        -- No entry, but the flow started no later than a flow whose entry was dropped while
        -- still unfinished (TTL or max_tracked_flows). It may be one of them, already exported:
        -- record its totals and send only later increments, rather than all of it twice.
        skip = true
        T.nfgen.skipped = T.nfgen.skipped + 1
      end

      -- report only what is new since this flow was last exported
      local function delta(now_total, idx)
        local d = now_total - (prev and prev[idx] or 0)
        if d < 0 then d = now_total end -- counters went back: treat as a new flow
        return d
      end
      local d = {
        az_bytes = delta(ctx.az_bytes, E_AZB), az_packets = delta(ctx.az_packets, E_AZP),
        za_bytes = delta(ctx.za_bytes, E_ZAB), za_packets = delta(ctx.za_packets, E_ZAP),
      }
      local start_sec = prev and prev[E_END] or ctx.start_sec

      -- finished flows are kept a little while too, so a repeat flush of the same flow
      -- reports nothing new instead of its whole totals again.
      -- Array entry (see E_* indexes): about a third of the memory of a keyed table.
      if tracked[ctx.flow_id] == nil then T.nfgen.tracked_count = T.nfgen.tracked_count + 1 end
      tracked[ctx.flow_id] = {
        ctx.az_bytes, ctx.az_packets, ctx.za_bytes, ctx.za_packets,
        ctx.start_sec, ctx.end_sec, now, done,
      }

      if skip then return end
      for _, rec in ipairs(Fields.directional_records(ctx, d, start_sec)) do
        Encoder.add_flow_record(state, key, template_fields, rec)
        Encoder.send_batch_if_full(state, sender, T.nfgen.fields, now, T.config, key)
      end
    end,

    onendflush = function(engine, ts)
      if not T.config.enabled then return end
      -- Trisul calls onbeginflush(engine) / onendflush(engine) without a timestamp
      ts = ts or os.time()

      -- forget finished flows after done_ttl_seconds, and flows Trisul stopped flushing without
      -- marking them finished (idle UDP etc.) after exported_ttl_seconds
      forget_flows(ts, tonumber(T.config.exported_ttl_seconds) or 3600, tonumber(T.config.done_ttl_seconds) or 300)
      -- over max_tracked_flows: drop the least recently seen first, halving the age limit each pass
      local cap = tonumber(T.config.max_tracked_flows) or 0
      local age = (tonumber(T.config.exported_ttl_seconds) or 3600) / 2
      while cap > 0 and T.nfgen.tracked_count > cap and age >= 1 do
        forget_flows(ts, age, age)
        age = age / 2
      end

      local sender = T.nfgen.sender
      if sender == nil or not sender:is_open() then return end

      local state = T.nfgen.state
      if state == nil then return end

      Encoder.flush_all(state, sender, T.nfgen.fields, ts, T.config)

      local stats = Encoder.cycle_stats(state)
      T.logdebug(string.format(
        "nfgen flush engine=%s added=%d sent_records=%d sent_packets=%d queued_v4=%d queued_v6=%d seq=%d tracked=%d skipped=%d",
        tostring(engine:instanceid()),
        stats.added_records,
        stats.sent_records,
        stats.sent_packets,
        stats.queued_v4,
        stats.queued_v6,
        stats.sequence,
        T.nfgen.tracked_count,
        T.nfgen.skipped
      ))
      T.nfgen.skipped = 0
    end,
  },
}
