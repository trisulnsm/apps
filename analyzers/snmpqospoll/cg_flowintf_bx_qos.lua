--
-- FlowIntf_bx_QOS : per-interface QoS traffic crosskey
--
TrisulPlugin = {

  id = {
    name = "FlowIntf QoS",
    description = "Per interface QoS traffic from SNMP",
    author = "Unleash",
    version_major = 1,
    version_minor = 0,
  },

  countergroup = {
    control = {
      guid = "{D3F7A892-4E1B-4C6D-8A5F-2E1C9B7D4A63}",
      name = "FlowIntf_bx_QOS",
      description = "Flow interface cross QoS class traffic",
      bucketsize = 60,
    },
    meters = {
      {  0, T.K.vartype.DELTA_RATE_COUNTER, 100, "bytes", "Pre Policy BW", "Bps" },
      {  1, T.K.vartype.DELTA_RATE_COUNTER, 100, "bytes", "Post Policy",   "Bps" },
    },
  },
}
