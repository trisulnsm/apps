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
      {  0, T.K.vartype.DELTA_RATE_COUNTER, 1000, "bytes",   "Pre Policy",     "Bps" },
      {  1, T.K.vartype.DELTA_RATE_COUNTER, 1000, "bytes",   "Post Policy",       "Bps" },
      {  2, T.K.vartype.DELTA_RATE_COUNTER, 1000, "bytes",   "Drops",           "Bps" },
      {  3, T.K.vartype.GAUGE,              1000, "pkts", "Queue Buffer",      "packets" },
      {  4, T.K.vartype.DELTA_RATE_COUNTER, 1000, "pkts", "Queue Drops",       "packets" },
      {  5, T.K.vartype.DELTA_RATE_COUNTER, 1000, "bytes",   "Queue Drop Bytes",  "Bps" },
    },
  },
}
