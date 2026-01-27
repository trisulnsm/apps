--
-- Flow Tracker Alert 
-- Hard Alert if upload bytes > MB
-- Ratio Alert
--
require 'mkconfig'
--local dbg = require("debugger")


PROTOCOl = {
    ['01'] = 'ICMP',
    ['02'] = 'IGMP',
    ['04'] = 'IPv4',
    ['06'] = 'TCP',
    ['11'] = 'UDP',
    ['29'] =  'IPv6'
}


function format_bytes(bytes)
  local units = {"B", "KB", "MB", "GB", "TB"}
  local unit = 1

  while bytes >= 1000 and unit < #units do
    bytes = bytes / 1000
    unit = unit + 1
  end

  return string.format("%.2f %s", bytes, units[unit])
end


TrisulPlugin = {

  id = {
    name = "Flow Tracker Alert",
    description = "Alert only for internal-external high upload flows",
    author = "Unleash",                       -- optional
    version_major = 1,                        -- optional
    version_minor = 0,   
  },

  onload = function()
    T.config = make_config(
      T.env.get_config("//App/DBRoot").."/config/trisulnsm_flow-traker-alert.lua",
      {
        --ignore proocols , UDP flow like webex
        ignore_protocols={
          ["UDP"]=true,
        },

        --ignore flows less than  2 MB
        ignore_flows_bytes= 2*1000*1000,

        --generate alert those upload is graater then this value

        upload_bytes = 3*1000*1000,


        hard_upload_bytes=5*1000*1000,

        -- geneate alert if upload is greater then 2% of the download 

        upload_download_bytes_ratio =70 ,

        ---  need to add alert to this id , so we can see in the UI
        fta_alert_id = 1,

        white_list_ips = {
          
        },
        white_list_ports={
          
        },

        fired_alert_id_lists={
          --["06C:C0.A8.0A.13:p-F6BE_6C.9E.FB.32:p-01BB_C0.A8.0A.01_0000000F_0000000A"]=os.time() 
        },
        
        --dont generate alerts , if already fired in some duration, Active flows timeout will get flows repeatly
        alert_suppression_seconds =  3600
      }
    )
  end,



  sg_monitor = {

    onbeginflush = function(engine,ts)
      T.config.fired_alert_count  = 0
    end,

    onflush = function(engine, flow)
      local session = flow:flow()
      local proto = PROTOCOl[session:protocol()]
      --ignore protocls
      if T.config.ignore_protocols[proto] then
        return
      end
      
     
      local az_bytes = flow:az_bytes() or 0
      local za_bytes = flow:za_bytes() or 0

     
      local upload_bytes  = az_bytes
      local download_bytes = za_bytes 
      local total_bytes = upload_bytes + download_bytes

     
      local flowid = session:id() --flowid
      local keyA = session:ipa()  -- source key
      local keyZ = session:ipz()  -- destination key

      local A_internal = T.host:is_homenet_key(keyA)
      local Z_internal = T.host:is_homenet_key(keyZ)

      local keya_readable  = session:ipa_readable()
      local keyz_readable  = session:ipz_readable()
      local porta_readable = session:porta_readable()
      local portz_readable =  session:portz_readable()


     

      if T.config.fired_alert_id_lists[flowid]  and  (T.config.fired_alert_id_lists[flowid] + T.config.alert_suppression_seconds) >= os.time() then
        --print("Return key = "..k.."added at ="..os.date("%c", T.config.fired_alert_id_lists[flowid]+T.config.alert_suppression_seconds).."current time ="..os.date("%c"))
        return
      end


      --ignore flow < then a valye
      if (total_bytes < T.config.ignore_flows_bytes) then 
        --print("Return  key ="..flowid.." total bytes="..total_bytes.." less then ignore flow bytes"..T.config.ignore_flows_bytes)
        return
      end

      -- Ignore if both internal or both external
      if (A_internal and Z_internal) or (not A_internal and not Z_internal) then
       return
      end  


      --if you want to disable alert
      if not T.config.fta_alert_id then
        return
      end

      if T.config.white_list_ips[keya_readable] or T.config.white_list_ips[keyz_readable]  or T.config.white_list_ports[porta_readable]  or T.config.white_list_ports[portz_readable] then
        --whitlisted ips or port  
        return
      end

      if not A_internal then
        upload_bytes,download_bytes =za_bytes,az_bytes

        local proto, ip1, port1, ip2, port2, router, intf1, intf2 =
          flowid:match("^([^:]+):([^:]+):([^_]+)_([^:]+):([^_]+)_([^_]+)_([^_]+)_([^_]+)$")

        if proto then
          flowid = string.format("%s:%s:%s_%s:%s_%s_%s_%s",
              proto, ip2, port2,
              ip1, port1,
              router, intf1, intf2
          )
        end
      end

      local upload_ratio = 0
      if download_bytes > 0 then
        upload_ratio = (upload_bytes / download_bytes) * 100
      end

      if upload_bytes > T.config.hard_upload_bytes then
        --print("Adding hard alert "..flowid)
        local readable_bytes_format = format_bytes(T.config.hard_upload_bytes)
        local msg = "Flow ID ("..flowid..") flow metric is now "..upload_bytes..", crossed ".. T.config.hard_upload_bytes.."[Hard Upload Alert|Above "..readable_bytes_format.."]"
        T.loginfo("Lua flow tracker hard alert generated msg="..msg)
        engine:add_alert_tca("{BE7F367F-8533-45F7-9AE8-A33E5E1AA783}",T.config.fta_alert_id,"ALARM",msg)
        T.config.fired_alert_id_lists[flowid]=os.time()
        T.config.fired_alert_count = T.config.fired_alert_count + 1
        return
      end

      --if between ratio
      if upload_ratio  > T.config.upload_download_bytes_ratio and upload_bytes > T.config.upload_bytes then
        --print("Adding ratio alert "..flowid)
        local msg = "Flow ID ("..flowid..") flow metric is now "..upload_bytes..", crossed ".. T.config.upload_bytes.."[Upload Alert Ratio|Above "..T.config.upload_download_bytes_ratio.."%]"
        T.loginfo("Lua flow tracker ratio alert  generated msg="..msg)
        engine:add_alert_tca("{BE7F367F-8533-45F7-9AE8-A33E5E1AA783}",T.config.fta_alert_id,"ALARM",msg)
        T.config.fired_alert_id_lists[flowid]=os.time()
        T.config.fired_alert_count = T.config.fired_alert_count + 1
      end

    end,

    onendflush  = function(engine)
      for k, v in pairs(T.config.fired_alert_id_lists) do
        if (v+T.config.alert_suppression_seconds) <= os.time() then
          --print("Deleteing key = "..k.."added at ="..os.date("%c", v+T.config.alert_suppression_seconds).."current time ="..os.date("%c"))
          T.config.fired_alert_id_lists[k]=nil
        end
      end
      --print("Lua flow tracker added count="..T.config.fired_alert_count)
      T.loginfo("Lua flow tracker added count="..T.config.fired_alert_count)
      T.config.fired_alert_count = 0;
    end,

  },
}

