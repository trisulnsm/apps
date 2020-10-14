--
-- hsrp - HSRP counter  
--
-- TYPE:        FRONTEND SCRIPT
-- PURPOSE:     Protocol Handler, 
-- 
local SB=require'sweepbuf'

TrisulPlugin = { 


  -- the ID block,
  -- 
  id =  {
    name = "HSRPCG",
    description = "HSRP countergroup to track active standby ", -- optional
  },
  -- countergroup info block
  countergroup = {

    control = {
      guid = "{0A79F27A-4741-40E8-DAF1-32F8ADB2653E}",
      name = "HSRP Hits",
      description = "Count Active/standby hits",
      bucketsize = 30,
    },

    -- meters table
    -- id, type of meter, toppers to track, bottom-ers to track, Name, units, units-short
    --
    meters = {
        {  0, T.K.vartype.GAUGE, 10, 0, "Status", "hits",    "hits" },
    },

  },

  -- simple_counter  block
  -- 
  simplecounter = {

    --attach to HSRP protocol
    protocol_guid = "{169D45A5-F304-434A-820F-C44C3956BA0B}",

    count=0,
    -- WHEN CALLED: when the Trisul platform detects a packet at the protocol_guid layer
    --              above. In this case, every DNS packet
    -- 
    onpacket = function(engine,layer)
      -- your code here 
      -- typically access the raw bytes and use engine:methods(..) to add metrics 
	    -- print(layer:rawbytes():hexdump())

	    local ethernet=layer:packet():find_layer("{974FB098-DE46-45DB-94DA-8D64A3BBCDE5}")
      local iplayer = layer:packet():find_layer("{0A2C724B-5B9F-4BA6-9C97-B05080558574}");
      
	    local ethernet_sb = SB.new( ethernet:rawbytes():tostring() )
      local hsrp_sb = SB.new(layer:rawbytes():tostring())
      local ip_sb = SB.new(iplayer:rawbytes():tostring())
     
      --mac address(from ethernet layer)
	    local dmac, smac, ethertype   =  ethernet_sb:next_mac(),
		                                   ethernet_sb:next_mac(),
		                                   ethernet_sb:next_u16() 

      --virtual ip addres
	    local _,op_code,mode = hsrp_sb:next_u8(),
		             hsrp_sb:next_u8(),
		             hsrp_sb:next_u8()

      --router ip address(from ip layer)
      ip_sb:skip(12)
      local router_ip=ip_sb:next_ipv4()

      if op_code== 0 then
  	    hsrp_sb:skip(13) --skip priotity, group etc
  	    local ip=hsrp_sb:next_ipv4()
  	    local key=ip.."|"..smac
        TrisulPlugin.simplecounter.count = TrisulPlugin.simplecounter.count +1
        if mode==16 then --active
          mode = 1
        else  -- standby
          mode = 2
        end
        engine:update_counter("{47FB78D7-76F6-4AF0-D45A-7D9BA6E83762}",router_ip,0,1)
  	    engine:update_counter( TrisulPlugin.countergroup.control.guid, key, 0, tonumber(mode))
      end
    end,

  }
}
