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
  -- 5><190>logver=700140601 timestamp=1713200834 devname="JJJJ_HO_Sec-43" devid="FG200FT922" vd="root" date=2024-04-15 time=17:07:14 eventtime=1713181035082310613 tz="+0530" logid="0100026001" type="event" subtype="system" level="information" logdesc="DHCP Ack log" interface="Local_LAN" dhcp_msg="Ack" mac="20:79:18:93:22:C7" ip=192.168.6.20 lease=1440 hostname="BLAKBHAHBAH" msg="DHCP server sends a DHCPACK"
  -- <189>logver=700140601 timestamp=1713201487 devname="JJJJ_HO_Sec-43" devid="FG200FT92" vd="root" itime=1713181687 logver=0700140601 date=2024-04-15 time=17:18:07 eventtime="1713181687126725945" tz="+0530" logid="0102043014" type="event" subtype="user" level="notice" logdesc="FSSO logon authentication status" srcip=192.168.10.77 user="NAVEENK" server="FSSO-AD" action="FSSO-logon" msg="FSSO-logon event from FSSO-AD: user BLAKBHAHBAH logged on 192.168.10.77"
  --<189>logver=700140601 timestamp=1713201598 devname="JJJJ_HO_Sec-43" devid="FG200FT9" vd="root" itime=1713181798 logver=0700140601 date=2024-04-15 time=17:19:58 eventtime="1713181797488372203" tz="+0530" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip="192.168.6.180" srcname="NPJSHJR" srcport=59769 srcintf="Local_LAN" srcintfrole="lan" dstip=35.73.100.104 dstport=443 dstintf="port2" dstintfrole="wan" srcuuid=3d2f6108-d6a2-51eb-40f5-6e530fffb6e0 dstuuid=3d2f6108-d6a2-51eb-40f5-6e530fffb6e0 srccountry="Reserved" dstcountry="Japan" sessionid=120326092 proto=6 action="close" policyid=26 policytype="policy" poluuid="f970e3a6-e1ca-51ee-9948-247841d38f07" policyname=PolicyforHeads user="LKJDFAR" authserver="FSSO-AD" service="HTTPS" trandisp=snat transip=180.151.85.10 transport=59769 appid=30061 app="Adobe.Web" appcat="General.Interest" apprisk="elevated" applist="default" duration=2 sentbyte=2466 rcvdbyte=882 sentpkt=11 rcvdpkt=12 utmaction=allow countapp=1 srchwvendor=HP devtype=Home & Office srcfamily=Computer osname=Windows srcswversion=10 mastersrcmac=84:69:93:80:be:71 srcmac=84:69:93:80:be:71 srcserver=0
  --<189>logver=700140601 timestamp=1713362661 devname="Elan_HO_Sec-43" devid="FG200FT922933941" vd="root" date=2024-04-17 time=14:04:21 eventtime=1713342861422656743 tz="+0530" logid="0000000020" type="traffic" subtype="forward" level="notice" srcip=192.168.6.93 srcname="448RMK3" srcport=54359 srcintf="Local_LAN" srcintfrole="lan" dstip=52.98.123.178 dstport=443 dstintf="port16" dstintfrole="wan" srcuuid="3d2f6108-d6a2-51eb-40f5-6e530fffb6e0" dstuuid="3d2f6108-d6a2-51eb-40f5-6e530fffb6e0" srccountry="Reserved" dstcountry="India" sessionid=133137080 proto=6 action="accept" policyid=26 policytype="policy" poluuid="f970e3a6-e1ca-51ee-9948-247841d38f07" policyname="PolicyforHeads" user="APURI" authserver="FSSO-AD" service="HTTPS" trandisp="snat" transip=49.249.145.218 transport=54359 appid=15816 app="Microsoft.Outlook" appcat="Email" apprisk="medium" applist="default" duration=1759 sentbyte=925674 rcvdbyte=1368238 sentpkt=1641 rcvdpkt=1942 vwlid=0 sentdelta=13791 rcvddelta=123980 srchwvendor="Dell" devtype="Home & Office" srcfamily="Computer" osname="Windows" srcswversion="10" mastersrcmac="c0:25:a5:a4:e5:92" srcmac="c0:25:a5:a4:e5:92" srcserver=0




  onload = function()
    T.re2_Fortigate_DHCPAck=T.re2('msg="DHCP server sends a DHCPACK".*hostname="(.\\S+)".*ip=(\\S+).*mac="(\\S+)".*lease=(\\d+).*itime_t=(\\d+)')
    T.re2_Fortigate_DHCPAck_2=T.re2('timestamp=(\\d+).*mac="(\\S+)".*ip=(\\S+).*lease=(\\d+).*hostname="(\\S+)".*msg="DHCP server sends a DHCPACK"')
	T.re2_Fortigate_FSSO_Logon=T.re2('timestamp=(\\d+).*FSSO-logon event from FSSO-AD: user (\\S+) logged on ([\\d\\.]+)')
	T.re2_Fortigate_Forward_Delta=T.re2('timestamp=(\\d+).*srcip="(\\S+)".*srcname="(\\S+).*dstip=(\\S+).*dstintfrole="wan".*user="(\\S+)".*app="(\\S+)".*sentdelta=(\\d+).*rcvddelta=(\\d+)')
	T.re2_Fortigate_Forward=T.re2('timestamp=(\\d+).*srcip="(\\S+)".*srcname="(\\S+)".*dstip=(\\S+).*dstintfrole="wan".*user="(\\S+)".*app="(\\S+)".*sentbyte=(\\d+).*rcvdbyte=(\\d+)')
	T.re2_Fortigate_Forward_Delta_Eventtime=T.re2('eventtime=(\\d{10}).*srcip=(\\S+).*srcname="(\\S+|[\\w -_])".*dstip=(\\S+).*dstintfrole="wan".*user="(\\S+)".*(?:service|app)="(\\S+|[\\w -_])".*(?:sentdelta|sentbyte)=(\\d+).*(?:rcvddelta|rcvdbyte)=(\\d+)')
	T.re2_Fortigate_Forward_Delta_Eventtime_Withoutsrcname=T.re2('eventtime=(\\d{10}).*srcip=(\\S+).*dstip=(\\S+).*dstintfrole="wan".*user="([\\w ]+)".*(?:sentdelta|sentbyte)=(\\d+).*(?:rcvddelta|rcvdbyte)=(\\d+).*srchwvendor="(\\S+|[\\w -_])"')
	T.re2_Fortigate_Forward_Delta_Eventtime_Withoutuser=T.re2('eventtime=(\\d{10}).*srcip=(\\S+).*srcname="(\\S+|[\\w -_])".*dstip=(\\S+).*dstintfrole="wan".*(?:service|app)="(\\S+|[\\w -_])".*(?:sentdelta|sentbyte)=(\\d+).*(?:rcvddelta|rcvdbyte)=(\\d+)')
	T.re2_Fortigate_Forward_Delta_Eventtime_Srcfamily=T.re2('eventtime=(\\d{10}).*srcip=(\\S+).*dstip=(\\S+).*dstintfrole="wan".*(?:service|app)="(\\S+|[\\w -_])".*(?:sentdelta|sentbyte)=(\\d+).*(?:rcvddelta|rcvdbyte)=(\\d+).*srcfamily="([\\w -_]+)"')

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

	  local bret, starttm,mac,ip,lease,hostname = T.re2_Fortigate_DHCPAck_2:partial_match_n(syslogstr)
	  if bret  then 
		  local serialstr = ip.."\n"..hostname:upper() .."\n"..mac.."\n"..starttm+lease;
		  engine:post_message_backend( '{DE53D193-9A98-4443-2289-84E537A5820A}', serialstr  )

		  engine:add_edge( '{A8D34B1F-E0E5-458D-012A-0A31B0746D41}', hostname, 	
		  				   '{889900CC-0063-11A5-8380-FEBDBABBDBEA}', ip)
		  return 
	  end 

	  -- FSSO login
	  bret, starttm,userid,ip = T.re2_Fortigate_FSSO_Logon:partial_match_n(syslogstr)
	  if bret  then 
		  local serialstr = ip.."\n"..userid:upper() .."\n".."00:00:00:00:00:00".."\n"..starttm+86400;
		  engine:post_message_backend( '{DE53D193-9A98-4443-2289-84E537A5820A}', serialstr  )

		  engine:add_edge( '{A8D34B1F-E0E5-458D-012A-0A31B0746D41}', userid, 	
		  				   '{889900CC-0063-11A5-8380-FEBDBABBDBEA}', ip)
		  return 
	  end 

	  -- successful forwarding (try the delta version first ) 
	  bret, starttm,srcip,srcname,dstip,userid,app,sentbyte,recvbyte= T.re2_Fortigate_Forward_Delta:partial_match_n(syslogstr)
	  if not bret then 
		  bret, starttm,srcip,srcname,dstip,userid,app,sentbyte,recvbyte= T.re2_Fortigate_Forward:partial_match_n(syslogstr)
		  if not bret then 
			  bret, starttm,srcip,srcname,dstip,userid,app,sentbyte,recvbyte= T.re2_Fortigate_Forward_Delta_Eventtime:partial_match_n(syslogstr)
		  end 
	  end 
	  --syslog with out username , srcname as username
	  if not bret then
	     bret, starttm,srcip,srcname,dstip,app,sentbyte,recvbyte= T.re2_Fortigate_Forward_Delta_Eventtime_Withoutuser:partial_match_n(syslogstr)
	     userid=srcname
	  end 
	  --syslog without srcname , usename as srcname
	  if not bret then
	     bret, starttm,srcip,dstip,userid,sentbyte,recvbyte,app= T.re2_Fortigate_Forward_Delta_Eventtime_Withoutsrcname:partial_match_n(syslogstr)
	  end 
	  --srcfamily
	  if not bret then
	     bret, starttm,srcip,dstip,app,sentbyte,recvbyte,srcname= T.re2_Fortigate_Forward_Delta_Eventtime_Srcfamily:partial_match_n(syslogstr)
	     userid=srcname
	  end 
	  if bret  then 
		  local serialstr = srcip.."\n"..srcname:upper() .."\n".."00:00:00:00:00:00".."\n"..starttm+120;
		  engine:post_message_backend( '{DE53D193-9A98-4443-2289-84E537A5820A}', serialstr  )

		  engine:add_edge( '{A8D34B1F-E0E5-458D-012A-0A31B0746D41}', userid, 	
		  				   '{889900CC-0063-11A5-8380-FEBDBABBDBEA}', srcip)

		  local t,r,x = tonumber(recvbyte)+tonumber(sentbyte),  tonumber(recvbyte), tonumber(sentbyte)

		  -- update user 
		  engine:update_counter("{86A8880D-F4B2-4E49-A4FA-718880CAA976}", userid, 0, t)
		  engine:update_counter("{86A8880D-F4B2-4E49-A4FA-718880CAA976}", userid, 1, r)
		  engine:update_counter("{86A8880D-F4B2-4E49-A4FA-718880CAA976}", userid, 2, x)

		  -- update app 
		  engine:update_counter("{9021F5D3-FEFB-401B-99EC-EF2ACD088578}", app, 0, t)
		  engine:update_counter("{9021F5D3-FEFB-401B-99EC-EF2ACD088578}", app, 1, r)
		  engine:update_counter("{9021F5D3-FEFB-401B-99EC-EF2ACD088578}", app, 2, x)


		  -- update dstip from syslog -- dst IP reverses sent and recv 
		  local dstip_key=toip_format(dstip)
		  engine:update_counter("{459BACD7-8F16-428F-2882-9DED4801C46D}", dstip_key, 0, t)
		  engine:update_counter("{459BACD7-8F16-428F-2882-9DED4801C46D}", dstip_key, 1, x)
		  engine:update_counter("{459BACD7-8F16-428F-2882-9DED4801C46D}", dstip_key, 2, r)


		  return 
	   else
		 print(syslogstr)
	  end 



    end,
  },
}

