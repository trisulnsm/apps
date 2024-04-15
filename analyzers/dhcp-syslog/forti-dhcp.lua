--
-- Fortigate DHCP syslog protocol 
-- 


-- in trisul: ipv4 keys look like XX.XX.XX.XX 
function  toip_format( dotted_ip )
  local b1, b2, b3, b4 =  dotted_ip:match("(%d+).(%d+).(%d+).(%d+)")
  return string.format("%02X.%02X.%02X.%02X", b1, b2, b3, b4 )
end



TrisulPlugin = { 


  -- the ID block, you can skip the fields marked 'optional '
  -- 
  id =  {
    name = "Fortigate DHCP logs packet monitor",
    description = "Listen to SYSLOG DHCP packets", 
  },

  -- COMMON FUNCTIONS:  onload, onunload, onmessage 
  -- 
  -- WHEN CALLED : your LUA script is loaded into Trisul 
  -- 5><190>logver=700140601 timestamp=1713200834 devname="Elan_HO_Sec-43" devid="FG200FT922933941" vd="root" date=2024-04-15 time=17:07:14 eventtime=1713181035082310613 tz="+0530" logid="0100026001" type="event" subtype="system" level="information" logdesc="DHCP Ack log" interface="Local_LAN" dhcp_msg="Ack" mac="20:79:18:93:22:C7" ip=192.168.6.20 lease=1440 hostname="Gauravthakur" msg="DHCP server sends a DHCPACK"

  onload = function()
    T.re2_Fortigate_DHCPAck=T.re2('msg="DHCP server sends a DHCPACK".*hostname="(.\\S+)".*ip=(\\S+).*mac="(\\S+)".*lease=(\\d+).*itime_t=(\\d+)')
    T.re2_Fortigate_DHCPAck_2=T.re2('timestamp=(\\d+).*mac="(\\S+)".*ip=(\\S+).*lease=(\\d+).*hostname="(\\S+)".*msg="DHCP server sends a DHCPACK"')

  end,

  -- WHEN CALLED : your LUA script is unloaded  / detached from Trisul 
  onunload = function()
    -- your code 
  end,

  simplecounter = {

    -- to UDP>SYSLOG protocol 
    protocol_guid = "{4323003E-D060-440B-CA26-E146C0C7DB4E}", 

	-- also work in NETFLOW_TAP mode
	flow_counter = true,

    onpacket = function(engine,layer)
      local syslogstr = layer:rawbytes():tostring()


print(syslogstr) 

	  local bret, starttm,mac,ip,lease,hostname = T.re2_Fortigate_DHCPAck_2:partial_match_n(syslogstr)

	  if bret ==false then return;  end

	  local serialstr = ip.."\n"..hostname.."\n"..mac.."\n"..starttm+lease;
	  engine:post_message_backend( '{DE53D193-9A98-4443-2289-84E537A5820A}', serialstr  )

    end,
  },
}

