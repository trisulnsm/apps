local bit=require'bit'

local CG = "{E45623ED-744C-4053-1401-84C72EE49D3B}"

TrisulPlugin = {

  id =  {
    name = "TCP Analysis",
    description = "Measure and tag TCP parameters per host "
  },

  countergroup = {
    control = {
      guid = CG,
      name = "TCP Analyzer",
      description = "Measure setup time retrans timeouts",
      bucketsize = 60,
    },

    meters = {
      {  0, T.K.vartype.AVERAGE,  20, 20, "us",   "Avg Latency Internal",   "us"},
      {  1, T.K.vartype.AVERAGE,  20, 20, "us",   "Avg Latency External",   "us" },
      {  2, T.K.vartype.COUNTER,  20, 20, "pkts", "Retrans Internal",       "pkts"},
      {  3, T.K.vartype.COUNTER,  20, 20, "pkts", "Retrans External",       "pkts" },
      {  4, T.K.vartype.AVERAGE,  20, 20, "pkts", "Retrans Rate Internal",  "percent"},
      {  5, T.K.vartype.AVERAGE,  20, 20, "pkts", "Retrans Rate External",  "percent" },
      {  6, T.K.vartype.COUNTER,  20, 20, "flows","Poor Quality Flows",     "flws" },
      {  7, T.K.vartype.COUNTER,  20, 20, "flows","Timeouts",               "flws" },
      {  8, T.K.vartype.COUNTER,  20, 20, "flows","Unidirectional",         "flws" },
    },
  },

  sg_monitor  = {

    onflush = function(engine, newflow)

      local flowkey = newflow:flow()

      if flowkey:protocol() ~= "06" then return end

      -- addresses in Trisul key form - no formatting, no reparsing, and the
      -- same code path for IPv4 and IPv6
      local ipa = flowkey:ipa()
      local ipz = flowkey:ipz()

      local packets       = newflow:az_packets() + newflow:za_packets()
      local retrans       = newflow:retransmissions()
      local retrans_rate  = packets > 0 and 100*retrans/packets or 0
      local setup_rtt     = newflow:setup_rtt()

      -- high retrans
      if retrans_rate  > 5  then
        engine:update_counter(CG, ipa, 6, 1)
        engine:update_counter(CG, ipz, 6, 1)
        newflow:add_tag("BADQUALITY")
      end

      -- timout : did not terminate with RST/FIN
      if bit.band(newflow:state(),0x0100) ~= 0 then
        engine:update_counter(CG, ipa, 7, 1)
        engine:update_counter(CG, ipz, 7, 1)
        newflow:add_tag("BADQUALITY")
      end

      -- meters 0,2,4 are the Internal (homenet) set, 1,3,5 the External one
      local a = T.host:is_homenet_key(ipa) and 0 or 1
      engine:update_counter(CG, ipa, 0+a, setup_rtt)
      engine:update_counter(CG, ipa, 2+a, retrans)
      engine:update_counter(CG, ipa, 4+a, retrans_rate)

      local z = T.host:is_homenet_key(ipz) and 0 or 1
      engine:update_counter(CG, ipz, 0+z, setup_rtt)
      engine:update_counter(CG, ipz, 2+z, retrans)
      engine:update_counter(CG, ipz, 4+z, retrans_rate)

    end,
  },
}
