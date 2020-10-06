-- apps 
TrisulPlugin = {

  id =  {
    name = "TCP Ana. App CG ",
    description = "App counter group", 
  },

  countergroup = {
    control = {
      guid = "{24DBD78F-CBB6-4383-7A78-B2C734FC480F}",
      name = "TCP Analyzer Apps",
      description = "Measure setup time retrans timeouts for apps",
      bucketsize = 60,
    },

    meters = {
      {  0, T.K.vartype.AVERAGE,  20, 20, "us",   "Avg Latency",   			"us"},
      {  1, T.K.vartype.COUNTER,  20, 20, "pkts", "Retrans",       			"pkts" },
      {  2, T.K.vartype.AVERAGE,  20, 20, "pkts", "Retrans Rate			",  "percent" },
      {  3, T.K.vartype.COUNTER,  20, 20, "flows","Poor Quality Flows",     "flws" },
      {  4, T.K.vartype.COUNTER,  20, 20, "flows","Timeouts",               "flws" },
      {  5, T.K.vartype.COUNTER,  20, 20, "flows","Unidirectional",         "flws" },
    },  
  },

  sg_monitor  = {

    onflush = function(engine, newflow)

      local flowkey = newflow:flow() 

      if flowkey:protocol() ~= "06" then return end 

	  local lower_port  = flowkey:portz();
	  if flowkey:porta() < lower_port then
	  	lower_port = flowkey:porta()
	  end 

      local retrans_rate = 100*newflow:retransmissions()/(newflow:az_packets()+newflow:az_packets());
      -- high retrans
      if retrans_rate  > 10  then 
        engine:update_counter("{24DBD78F-CBB6-4383-7A78-B2C734FC480F}", lower_port, 3, 1)
        newflow:add_tag("BADQUALITY")
      end 

      -- timeout : did not terminate with RST/FIN 
      if bit.band(newflow:state(),0x0100) ~= 0 then
        engine:update_counter("{24DBD78F-CBB6-4383-7A78-B2C734FC480F}", lower_port , 4, 1)
        newflow:add_tag("BADQUALITY")
      end

      engine:update_counter("{24DBD78F-CBB6-4383-7A78-B2C734FC480F}", lower_port, 0, newflow:setup_rtt())
      engine:update_counter("{24DBD78F-CBB6-4383-7A78-B2C734FC480F}", lower_port, 1, newflow:retransmissions())
      engine:update_counter("{24DBD78F-CBB6-4383-7A78-B2C734FC480F}", lower_port, 2, retrans_rate)

	  -- tag unidirectional also (maybe packet capture issue
	  if  (newflow:az_bytes() > 0 and newflow:za_bytes() == 0) or 
	      (newflow:za_bytes() > 0 and newflow:az_bytes() == 0) then 
		  engine:update_counter("{24DBD78F-CBB6-4383-7A78-B2C734FC480F}", lower_port, 5, 1)
	  end 
    end,
  },
}
