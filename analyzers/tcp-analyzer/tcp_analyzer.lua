local bit=require'bit' 

TrisulPlugin = {

  id =  {
    name = "TCP Analysis",
    description = "Measure and tag TCP parameters per host "
  },

  countergroup = {
    control = {
      guid = "{E45623ED-744C-4053-1401-84C72EE49D3B}",
      name = "TCP Analyzer",
      description = "Measure setup time retrans timeouts",
      bucketsize = 60,
    },

    meters = {
      {  0, T.K.vartype.AVERAGE,  20, 20, "us",   "Latency Internal",       "us"},
      {  1, T.K.vartype.AVERAGE,  20, 20, "us",   "Latency External",       "us" },
      {  2, T.K.vartype.COUNTER,  20, 20, "pkts", "Retrans Internal",       "pkts"},
      {  3, T.K.vartype.COUNTER,  20, 20, "pkts", "Retrans External",       "pkts" },
      {  4, T.K.vartype.AVERAGE,  20, 20, "pkts", "Retrans Rate Internal",  "percent"},
      {  5, T.K.vartype.AVERAGE,  20, 20, "pkts", "Retrans Rate External",  "percent" },
      {  6, T.K.vartype.COUNTER,  20, 20, "flows","Poor Quality Flows",     "flws" },
      {  7, T.K.vartype.COUNTER,  20, 20, "flows","Timeouts",               "flws" },
    },  
  },

  sg_monitor  = {

    onflush = function(engine, newflow)

      local flowkey = newflow:flow() 

      if flowkey:protocol() ~= "06" then return end 

      local retrans_rate = 100*newflow:retransmissions()/(newflow:az_packets()+newflow:az_packets());
      -- high retrans
      if retrans_rate  > 5  then 
          engine:update_counter("{E45623ED-744C-4053-1401-84C72EE49D3B}", flowkey:ipa() , 6, 1)
          engine:update_counter("{E45623ED-744C-4053-1401-84C72EE49D3B}", flowkey:ipz() , 6, 1)
          newflow:add_tag("BADQUALITY")
      end 

      -- timout : did not terminate with RST/FIN 
      if bit.band(newflow:state(),0x0100) ~= 0 then
         engine:update_counter("{E45623ED-744C-4053-1401-84C72EE49D3B}", flowkey:ipa() , 7, 1)
         engine:update_counter("{E45623ED-744C-4053-1401-84C72EE49D3B}", flowkey:ipz() , 7, 1)
         newflow:add_tag("BADQUALITY")
      end

      if T.host:is_homenet(flowkey:ipa_readable() ) then
        engine:update_counter("{E45623ED-744C-4053-1401-84C72EE49D3B}", flowkey:ipa() , 0, newflow:setup_rtt())
        engine:update_counter("{E45623ED-744C-4053-1401-84C72EE49D3B}", flowkey:ipa() , 2, newflow:retransmissions())
        engine:update_counter("{E45623ED-744C-4053-1401-84C72EE49D3B}", flowkey:ipa() , 4, retrans_rate)
      else
        engine:update_counter("{E45623ED-744C-4053-1401-84C72EE49D3B}", flowkey:ipa() , 1, newflow:setup_rtt())
        engine:update_counter("{E45623ED-744C-4053-1401-84C72EE49D3B}", flowkey:ipa() , 3, newflow:retransmissions())
        engine:update_counter("{E45623ED-744C-4053-1401-84C72EE49D3B}", flowkey:ipa() , 5, retrans_rate)
      end

      if T.host:is_homenet(flowkey:ipz_readable()) then
        engine:update_counter("{E45623ED-744C-4053-1401-84C72EE49D3B}", flowkey:ipz(), 0, newflow:setup_rtt())
        engine:update_counter("{E45623ED-744C-4053-1401-84C72EE49D3B}", flowkey:ipz(), 2, newflow:retransmissions())
        engine:update_counter("{E45623ED-744C-4053-1401-84C72EE49D3B}", flowkey:ipz() ,4, retrans_rate)
      else
        engine:update_counter("{E45623ED-744C-4053-1401-84C72EE49D3B}", flowkey:ipz(), 1, newflow:setup_rtt())
        engine:update_counter("{E45623ED-744C-4053-1401-84C72EE49D3B}", flowkey:ipz(), 3, newflow:retransmissions())
        engine:update_counter("{E45623ED-744C-4053-1401-84C72EE49D3B}", flowkey:ipz() ,5, retrans_rate)
      end

    end,
  },
}

