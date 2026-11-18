local bit = require("bit")
require("mkconfig")

local Fields  = require("netflow_fields")
local Encoder = require("netflow_encoder")
local UdpSender = require("udp_sender")

-- flow:state() bits for a finished flow, as used by trisul-scripts/backend_scripts/netflow_generator
local FLOW_DONE_MASK = 0x0900
-- how long to remember the exported totals of a flow that is no longer flushed
local EXPORTED_TTL_SECS = 3600
-- ... and of a finished flow, in case Trisul flushes it once more
local DONE_TTL_SECS = 300

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
      exported   = {},
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

      -- report only what is new since this flow was last exported
      local prev = T.nfgen.exported[ctx.flow_id]
      local function delta(name)
        local d = ctx[name] - (prev and prev[name] or 0)
        if d < 0 then d = ctx[name] end -- counters went back: treat as a new flow
        return d
      end
      local d = {
        az_bytes = delta("az_bytes"), az_packets = delta("az_packets"),
        za_bytes = delta("za_bytes"), za_packets = delta("za_packets"),
      }
      local start_sec = prev and prev.end_sec or ctx.start_sec

      -- finished flows are kept a little while too, so a repeat flush of the same flow
      -- reports nothing new instead of its whole totals again
      T.nfgen.exported[ctx.flow_id] = {
        az_bytes = ctx.az_bytes, az_packets = ctx.az_packets,
        za_bytes = ctx.za_bytes, za_packets = ctx.za_packets,
        end_sec = ctx.end_sec, seen = now, done = done,
      }

      for _, rec in ipairs(Fields.directional_records(ctx, d, start_sec)) do
        Encoder.add_flow_record(state, key, template_fields, rec)
        Encoder.send_batch_if_full(state, sender, T.nfgen.fields, now, T.config, key)
      end
    end,

    onendflush = function(engine, ts)
      if not T.config.enabled then return end
      -- Trisul calls onbeginflush(engine) / onendflush(engine) without a timestamp
      ts = ts or os.time()

      -- forget finished flows after a few minutes, and flows Trisul stopped flushing without
      -- marking them finished (idle UDP etc.) after an hour
      for id, e in pairs(T.nfgen.exported) do
        local ttl = e.done and DONE_TTL_SECS or EXPORTED_TTL_SECS
        if ts - e.seen > ttl then T.nfgen.exported[id] = nil end
      end

      local sender = T.nfgen.sender
      if sender == nil or not sender:is_open() then return end

      local state = T.nfgen.state
      if state == nil then return end

      Encoder.flush_all(state, sender, T.nfgen.fields, ts, T.config)

      local stats = Encoder.cycle_stats(state)
      T.logdebug(string.format(
        "nfgen flush engine=%s added=%d sent_records=%d sent_packets=%d queued_v4=%d queued_v6=%d seq=%d",
        tostring(engine:instanceid()),
        stats.added_records,
        stats.sent_records,
        stats.sent_packets,
        stats.queued_v4,
        stats.queued_v6,
        stats.sequence
      ))
    end,
  },
}
