--
-- ja4shash.lua
--
-- TYPE: FRONTEND SCRIPT
-- PURPOSE: JA4S TLS fingerprint (server hello only)
-- DESCRIPTION: Implements https://github.com/FoxIO-LLC/ja4 (see ja4common.lua)
--              JA4S = {t}{version}{ext count}{alpn}_{cipher}_{sha256[:12] of extensions in order}
--

local JA4 = require'ja4common'
require 'mkconfig'

local GUID = "{D8D4E3C2-AE5F-4B90-C7F6-234567890BCD}"

TrisulPlugin = {

  id = {
    name        = "ja4s hash",
    description = "JA4S TLS Server Hello fingerprint",
  },

  onload = function()
    local enabled = T.env.get_config("//Reassembly/TCPReassembly/Applications/EnableSSLRecordExtraction")
    if enabled:lower() ~= "true" then
      T.logerror("JA4S: needs EnableSSLRecordExtraction=TRUE. Cant proceed.")
      return false
    end
    T.ja4s_config = make_config(
      T.env.get_config("//App/DBRoot").."/config/trisulnsm_tls-fingerprint.lua",
      { LogHashes = false }
    )
  end,

  countergroup = {
    control = {
      guid        = GUID,
      name        = "JA4S FINGERPRINT",
      description = "JA4S TLS Server Hello Fingerprint",
      bucketsize  = 60,
    },
    meters = {
      {0, T.K.vartype.COUNTER, 20, 40, "Hits",        "hits",     "hits"},
      {1, T.K.vartype.COUNTER, 20, 40, "Server Hits", "svr-hits", "hits"},
    },
  },

  reassembly_handler = {

    onattribute = function(engine, timestamp, flowkey, attr_name, attr_value)
      if attr_name ~= "TLS:RECORD" then return end

      local ja4s_str = JA4.ja4s_from_record(attr_value, "t")
      if not ja4s_str then return end

      if T.ja4s_config.LogHashes then
        print(" flow="..flowkey:to_s().." JA4S="..ja4s_str)
      end

      engine:update_counter(GUID, ja4s_str, 0, 1)
      engine:update_counter(GUID, ja4s_str, 1, 1)
      engine:add_flow_edges(flowkey:id(), GUID, ja4s_str)
    end,

  },
}
