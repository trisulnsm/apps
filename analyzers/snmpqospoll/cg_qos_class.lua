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
      {  0, T.K.vartype.DELTA_RATE_COUNTER, 100, "bytes", "Pre Policy BW", "Bps" },
      {  1, T.K.vartype.DELTA_RATE_COUNTER, 100, "bytes", "Post Policy",   "Bps" },
    },
  },
}
