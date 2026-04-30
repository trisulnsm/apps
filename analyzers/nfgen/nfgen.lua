local bit = require("bit")
require("mkconfig")

local Fields = require("netflow_fields")
local Encoder = require("netflow_encoder")
local UdpSender = require("udp_sender")

TrisulPlugin = {
  id = {
    name = "NetFlow Generator",
    description = "Export Trisul flows as NetFlow v9 or IPFIX(v10)",
    author = "trisul",
    version_major = 1,
    version_minor = 0,
  },

  onload = function()
    T.config = make_config(
      T.env.get_config("//App/DBRoot") .. "/config/trisulnsm_nfgen.lua",
      {
        enabled = true,
        netflow_version = "v10",
        collector_ip = "127.0.0.1",
        collector_port = 2055,
        template_id_base = 256,
        template_refresh_seconds = 30,
        template_refresh_packets = 20,
        export_only_terminated = false,
        source_id_base = 5000,
        max_records_per_packet = 24,
        tag_template_ids = { "COUNTRY", "TLS-SNI", "HOSTNAME", "ASN", "ALERT" },
        tag_field_max_len = 64,
        ipfix_enterprise_number = 39499,
        tag_v9_field_type_base = 200,
      }
    )
    local version = tostring(T.config.netflow_version or "v10"):lower()
    if version == "9" then
      version = "v9"
    elseif version == "10" or version == "ipfix" then
      version = "v10"
    end
    if version ~= "v9" and version ~= "v10" then
      T.logerror("nfgen: invalid netflow_version, defaulting to v10")
      version = "v10"
    end
    T.config.netflow_version = version

    T.nfgen = {
      fields = Fields.new(T.config),
      sender = nil,
      state = nil,
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
      if not T.config.enabled then
        return
      end
      if T.nfgen.sender == nil then
        T.nfgen.sender = UdpSender.new(T.config.collector_ip, T.config.collector_port)
      end
      if T.nfgen.state == nil then
        T.nfgen.state = Encoder.new_engine_state(engine:instanceid(), T.config, ts)
      end
      Encoder.reset_batch(T.nfgen.state)
    end,

    onflush = function(engine, flow)
      if not T.config.enabled then
        return
      end
      local sender = T.nfgen.sender
      if sender == nil or not sender:is_open() then
        return
      end

      local state = T.nfgen.state
      if state == nil then
        state = Encoder.new_engine_state(engine:instanceid(), T.config, os.time())
        T.nfgen.state = state
        Encoder.reset_batch(state)
      end

      local template_key = Encoder.add_flow_record(state, T.nfgen.fields, flow)
      Encoder.send_batch_if_full(state, sender, T.nfgen.fields, os.time(), T.config, template_key)
    end,

    onendflush = function(engine, ts)
      if not T.config.enabled then
        return
      end

      local sender = T.nfgen.sender
      if sender == nil or not sender:is_open() then
        return
      end
      local state = T.nfgen.state
      if state == nil then
        return
      end
      Encoder.flush_all(state, sender, T.nfgen.fields, os.time(), T.config)
      local stats = Encoder.cycle_stats(state)
      T.logdebug(
        string.format(
          "nfgen flush engine=%s added=%d sent_records=%d sent_packets=%d queued_v4=%d queued_v6=%d seq=%d",
          tostring(engine:instanceid()),
          stats.added_records,
          stats.sent_records,
          stats.sent_packets,
          stats.queued_v4,
          stats.queued_v6,
          stats.sequence
        )
      )
    end,
  },
}
