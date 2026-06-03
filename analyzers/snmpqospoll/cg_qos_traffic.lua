--
-- QOS-Traffic : aggregate QoS stats across all interfaces on a router
--
TrisulPlugin = {

  id = {
    name = "QOS Traffic",
    description = "QoS traffic aggregated across interfaces",
    author = "Unleash",
    version_major = 1,
    version_minor = 0,
  },

  countergroup = {
    control = {
      guid = "{1AB9F248-1E49-4245-571A-55BCDA658843}",
      name = "QOS-Traffic",
      description = "QOS Traffic using SNMP",
      bucketsize = 60,
      resolver_guid = "{116888A7-23B4-4873-5691-E6E0806CCB11}",
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
