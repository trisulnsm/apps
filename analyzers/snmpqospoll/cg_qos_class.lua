--
-- QoS Class names from Cisco CBQOS MIB
--
TrisulPlugin = {

  id = {
    name = "QoS Class",
    description = "QoS policy class names from SNMP CBQOS",
    author = "Unleash",
    version_major = 1,
    version_minor = 0,
  },

  countergroup = {
    control = {
      guid = "{116888A7-23B4-4873-5691-E6E0806CCB11}",
      name = "QoS-Class",
      description = "QoS class map names from SNMP",
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
