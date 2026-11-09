--
-- ja4hash.lua
--
-- TYPE: FRONTEND SCRIPT
-- PURPOSE: JA4 TLS fingerprint (client hello only)
-- DESCRIPTION: Implements https://github.com/FoxIO-LLC/ja4 (see ja4common.lua)
--              Output matches the FoxIO reference tools, so keys can be looked
--              up in public JA4 databases.
--

local JA4 = require'ja4common'
require 'mkconfig'

local GUID     = "{D7C3F2B1-9D4E-4A8F-B6E5-123456789ABD}"
local SNI_GUID = "{B91A8AD4-C6B6-4FBC-E862-FF94BC204A35}"

TrisulPlugin = {

  id = {
    name        = "ja4 hash",
    description = "JA4 TLS Client Hello fingerprint",
  },

  onload = function()
    local enabled = T.env.get_config("//Reassembly/TCPReassembly/Applications/EnableSSLRecordExtraction")
    if enabled:lower() ~= "true" then
      T.logerror("JA4: needs EnableSSLRecordExtraction=TRUE. Cant proceed.")
      return false
    end
    T.ja4_config = make_config(
      T.env.get_config("//App/DBRoot").."/config/trisulnsm_tls-fingerprint.lua",
      { LogHashes = false }
    )
  end,

  countergroup = {
    control = {
      guid        = GUID,
      name        = "JA4 FINGERPRINT",
      description = "JA4 TLS Client Hello Fingerprint",
      bucketsize  = 60,
    },
    meters = {
      {0, T.K.vartype.COUNTER, 20, 40, "Hits",        "hits",     "hits"},
      {1, T.K.vartype.COUNTER, 20, 40, "Client Hits", "clt-hits", "hits"},
    },
  },

  reassembly_handler = {

    onattribute = function(engine, timestamp, flowkey, attr_name, attr_value)
      if attr_name ~= "TLS:RECORD" then return end

      -- TLS over TCP only, so the protocol char is always "t"
      local ja4_str, snihostname = JA4.ja4_from_record(attr_value, "t")
      if not ja4_str then return end

      if T.ja4_config.LogHashes then
        print(" flow="..flowkey:to_s().." JA4="..ja4_str)
      end

      engine:update_counter(GUID, ja4_str, 0, 1)
      engine:update_counter(GUID, ja4_str, 1, 1)
      engine:add_flow_edges(flowkey:id(), GUID, ja4_str)

      if snihostname then
        engine:add_edge(GUID, ja4_str, SNI_GUID, snihostname)
      end
    end,

  },
}
