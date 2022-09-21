--
-- ipmac - count IP / MAC together 
--
-- TYPE:        FRONTEND SCRIPT
-- PURPOSE:     Protocol Handler, 
-- 
local SB=require'sweepbuf'

function ipstr_tokey(ipstr)
  local pmatch,_, b1,b2,b3,b4= ipstr:find("(%d+)%.(%d+)%.(%d+)%.(%d+)")
  return  string.format("%02X.%02X.%02X.%02X", b1,b2,b3,b4)
end



TrisulPlugin = { 


  -- the ID block,
  -- 
  id =  {
    name = "IPMAC",
    description = "Count IP MAC together", -- optional
  },

  -- countergroup info block
  countergroup = {

    control = {
      guid = "{4D6F1A1C-B8B5-4635-AFF8-20BE2A306020}",
      name = "IP-MAC-PAIR",
      description = "Count IP MAC Pairs",
      bucketsize = 30,
    },

    -- meters table
    -- id, type of meter, toppers to track, bottom-ers to track, Name, units, units-short
    --
    meters = {
        {  0, T.K.vartype.RATE_COUNTER, 20, 0, "Bps", "SourceBW", "Bps" },
        {  1, T.K.vartype.RATE_COUNTER, 20, 0, "Bps", "DestBW",   "Bps" },
    },

  },

  -- simple_counter  block
  -- 
  simplecounter = {

    --attach to IP protocol
    protocol_guid = "{0A2C724B-5B9F-4BA6-9C97-B05080558574}",

    -- WHEN CALLED: when the Trisul platform detects a packet at the protocol_guid layer
    --              above. In this case, every DNS packet
    -- 
    onpacket = function(engine,iplayer)

      -- your code here 

	  local ethernet=iplayer:packet():find_layer("{974FB098-DE46-45DB-94DA-8D64A3BBCDE5}")
      
	  local ethernet_sb = SB.new( ethernet:rawbytes():tostring() )
      local ip_sb = SB.new(iplayer:rawbytes():tostring())
     
      --mac address(from ethernet layer)
	  local dmac, smac =  ethernet_sb:next_mac(),
					      ethernet_sb:next_mac()

      --router ip address(from ip layer)
      ip_sb:skip(12)
      local sip,dip =ip_sb:next_ipv4(), ip_sb:next_ipv4() 


	  engine:update_counter_bytes("{4D6F1A1C-B8B5-4635-AFF8-20BE2A306020}" , sip.."_"..smac,0)
	  engine:update_counter_bytes("{4D6F1A1C-B8B5-4635-AFF8-20BE2A306020}" , dip.."_"..dmac,1)

	  engine:add_edge("{4CD742B1-C1CA-4708-BE78-0FCA2EB01A86}", ipstr_tokey(sip),"{4B09BD22-3B99-40FC-8215-94A430EA0A35}",    smac)
	  engine:add_edge("{4CD742B1-C1CA-4708-BE78-0FCA2EB01A86}", ipstr_tokey(dip),"{4B09BD22-3B99-40FC-8215-94A430EA0A35}",    dmac)

	  engine:add_edge("{4B09BD22-3B99-40FC-8215-94A430EA0A35}", smac, "{4CD742B1-C1CA-4708-BE78-0FCA2EB01A86}", ipstr_tokey(sip))
	  engine:add_edge("{4B09BD22-3B99-40FC-8215-94A430EA0A35}", dmac, "{4CD742B1-C1CA-4708-BE78-0FCA2EB01A86}", ipstr_tokey(dip))

    end,

  }
}
