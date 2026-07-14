--
-- NAT syslog counter attached to SYSLOG protocol 
-- 
local Fk = require 'flowkey'
local SB = require 'sweepbuf'

MONTHNAMES = {
    ['Jan'] = 1,
    ['Feb'] = 2,
    ['Mar'] = 3,
    ['Apr'] = 4,
    ['May'] = 5,
    ['Jun'] = 6,
    ['Jul'] = 7,
    ['Aug'] = 8,
    ['Sep'] = 9,
    ['Oct'] = 10,
    ['Nov'] = 11,
    ['Dec'] = 12
}

PROTOCOl = {
    ['ICMP'] = 1,
    ['IGMP'] = 2,
    ['IPv4'] = 4,
    ['TCP'] = 6,
    ['UDP'] = 17,
    ['IPv6'] = 41
}

COUNTERID_FLOWGEN = "{2314BB8E-2BCC-4B86-8AA2-677E5554C0FE}"

-- in trisul: ipv4 keys look like XX.XX.XX.XX 
function toip_format(dotted_ip)
    local b1, b2, b3, b4 = dotted_ip:match("(%d+).(%d+).(%d+).(%d+)")
    return string.format("%02X.%02X.%02X.%02X", b1, b2, b3, b4)
end

function is_private_ip(ip)
    local private_ranges = {{"10.0.0.0", "10.255.255.255"}, {"172.16.0.0", "172.31.255.255"},
                            {"192.168.0.0", "192.168.255.255"}}

    local function ip_to_number(ip)
        local o1, o2, o3, o4 = ip:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")
        return 2 ^ 24 * o1 + 2 ^ 16 * o2 + 2 ^ 8 * o3 + o4
    end

    local ip_num = ip_to_number(ip)

    for _, range in ipairs(private_ranges) do
        local start_ip, end_ip = ip_to_number(range[1]), ip_to_number(range[2])
        if ip_num >= start_ip and ip_num <= end_ip then
            return true
        end
    end

    return false
end

TrisulPlugin = {

    -- the ID block, you can skip the fields marked 'optional '
    -- 
    id = {
        name = "SYGLOG  packet monitor",
        description = "Listen to SYSLOG packets"
    },

    -- COMMON FUNCTIONS:  onload, onunload, onmessage 
    -- 
    -- WHEN CALLED : your LUA script is loaded into Trisul 
    onload = function()
        -- Unused fields use non-capturing groups to keep BitState cheaper.
        T.re2_NetElasticBNGNATSyslog = T.re2(
            'NAT\\s+\\d+\\s+(SADD|SDEL)\\s\\[nsess\\sTRIG="\\w+"\\sPROTO="(\\d+)"\\sSSUBIX="\\d"\\sIATYP="\\w+"\\sUSERNAME="(\\w+)"\\sISADDR="(\\S+)"\\sIDADDR="(\\S+)"\\sISPORT="(\\d+)"\\sIDPORT="(\\d+)"\\sXATYP="\\w+"\\sXSADDR="(\\S+)"\\sXDADDR="\\S+"\\sXSPORT="(\\d+)"\\sXDPORT="\\d+"\\]\\stime=\'(\\d{4})-(\\d{2})-(\\d{2}) (\\d{2}):(\\d{2}):(\\d{2})\'')

        -- No leading .*; PartialMatch already searches from any offset.
        T.re2_HuaweiNATSyslog = T.re2(
            "<NAT444>:<(\\w+)>\\s(\\d+)\\|(\\d+|-)\\|(\\S+)\\|(\\S+)\\|(\\d+)\\|(\\S+)\\|(\\d+)\\|(\\d+)")

        T.re2_JioDeviceNATSyslog = T.re2(
            "<141>(\\w+)\\s+(\\d+)\\s+(\\d\\d):(\\d\\d):(\\d\\d)\\s+(\\S+)\\s+NAT_ACCT:(\\w+)\\s+(\\w+)\\s+SourceIp\\s+:(\\S+)\\s+Sourceport:(\\d+)\\s+TransIP\\s+:(\\S+)\\s+TransPort:(\\d+)\\s+DestIp\\s+:(\\S+)\\s+Destport:(\\d+)\\s*")

        T.re2_CiscoNATSyslog = T.re2(
            "(\\w+)\\s+(\\d+)\\s+(\\d\\d):(\\d\\d):(\\d\\d).\\d\\d\\d.*(Created|Deleted)\\s+Translation\\s+(\\w+)\\s+(\\S+):(\\S+)\\s+(\\S+):(\\S+)\\s+(\\S+):(\\S+)\\s+(\\S+):(\\S+)\\s*\\d+")

        T.re2_CiscoNATSyslog2 = T.re2(
            "(\\w+)\\s+(\\d+)\\s+(\\d\\d):(\\d\\d):(\\d\\d).\\d\\d\\d.*(Created|Deleted)\\s+(\\w+)\\s+(\\S+):(\\d+)\\s+(\\S+):(\\d+)\\s+(\\S+):(\\d+)\\s+(\\S+):(\\d+)")

        T.re2_CiscoNATSyslog3 = T.re2(
            "(\\d+):\\s+(\\w+)\\s+(\\d+)\\s+(\\d\\d):(\\d\\d):(\\d\\d):\\s+.*(CREATED|DELETED):\\s+(\\w+)\\s+(\\S+):(\\d+)\\s+(\\S+):(\\d+)\\s+(\\S+):(\\d+)\\s+(\\S+):(\\d+)")

        -- cisco ASA: start at the gated literal; drop unused timestamp captures
        T.re2_CiscoNATSyslog4=T.re2("Built\\soutbound\\s(\\w+).*outside:(\\S+)\\/(\\d+)\\s\\S+:(\\S+)\\/(\\d+)\\s\\((\\S+)\\/(\\d+)\\)")
        T.re2_CiscoNATSyslog5=T.re2("(?:inbound|Teardown)\\s(\\w+)\\sconnection\\s+.*faddr\\s(\\S+)\\/(\\d+)\\sgaddr\\s(\\S+)\\/(\\d+)\\sladdr\\s(\\S+)\\/(\\d+)")
        T.re2_CiscoNATSyslog6=T.re2("(?:Deny|Teardown)\\s?(?:inbound|outbound)?\\s(\\w+).*(?:outside|inside):(\\S+).*(?:outside|inside):(\\S+)")


        -- Start at gated literals (src-mac / proto); optional TCP flags group; no leading firewall,info.*
        T.re2_MikroTikNATSyslog=T.re2("src-mac\\s(\\S+),\\sproto\\s(\\w+)(?:\\s+\\([^)]*\\))?,\\s+(\\S+):(\\d+)->(\\S+):(\\d+)")
        T.re2_MikroTikNATSyslog2=T.re2("(?:src-mac\\s\\S+,\\s)?proto\\s+(\\w+)(?:\\s+\\([^)]*\\))?,\\s+(\\S+):(\\d+)->(\\S+):(\\d+),\\s+NAT\\s+\\((\\S+):(\\d+)->(\\S+):(\\d+)\\)->(\\S+):(\\d+)")

        T.re2_MikroTikNATSyslog3=T.re2("srcnat:.*\\ssrc-mac\\s(\\S+),\\sproto\\s(\\w+)(?:\\s+\\([^)]*\\))?,\\s+(\\S+):(\\d+)->(\\S+):(\\d+)")
        -- BSD-timestamped MikroTik (rare on rainbow); still avoid firewall,info.* / forward:.* sandwiches
        T.re2_MikroTikNATSyslog4=T.re2("(\\w+)\\s(\\d+)\\s(\\d+):(\\d+):(\\d+).*src-mac\\s(\\S+),\\sproto\\s(\\w+)(?:\\s+\\([^)]*\\))?,\\s+(\\S+):(\\d+)->(\\S+):(\\d+),\\s+NAT\\s+\\((\\S+):(\\d+)->(\\S+):(\\d+)\\)->(\\S+):(\\d+)")

        -- tacitine devices
        T.re2_TacitineNATSylog = T.re2(
            "<6>(\\w+)\\s\\s(\\d+)\\s(\\d\\d):(\\d+):(\\d+).*SRC=(\\S+)\\sDST=(\\S+)\\s.*PROTO=(\\S+)\\sSPT=(\\d+)\\sDPT=(\\d+)")
        -- Fortigate: drop leading .*
        T.re2_FortigateNATSylog = T.re2(
            "date=(\\S+)\\stime=(\\S+).*srcip=(\\S+)\\ssrcport=(\\w+).*dstip=(\\S+)\\sdstport=(\\w+).*proto=(\\w+).*tranip=(\\S+)\\stranport=(\\d+)\\stransip=(\\S+)\\stransport=(\\d+)")
        T.re2_FortigateNATSylogNoopPort = T.re2(
            "date=(\\S+)\\stime=(\\S+).*srcip=(\\S+)\\ssrcport=(\\w+).*dstip=(\\S+)\\sdstport=(\\w+).*proto=(\\w+)")
        T.re2_FortigateNATSylogNoop = T.re2("date=(\\S+)\\stime=(\\S+).*srcip=(\\S+).*dstip=(\\S+).*proto=(\\w+)")
        T.re2_FortigateNATSylogSNat = T.re2(
            "date=(\\S+)\\stime=(\\S+).*srcip=(\\S+).*srcport=(\\w+).*dstip=(\\S+)\\sdstport=(\\w+).*proto=(\\w+).*transip=(\\S+)\\stransport=(\\d+)")

        -- Checkpoint devices 
        T.re2_CheckPointAccept = T.re2(
            'action:"Accept".*\\stime:"(\\d+).*\\sdst:"(\\S+)".*\\sproto:"(\\d+)".*\\ss_port:"(\\d+)".*\\sservice:"(\\d+)".*\\ssrc:"(\\S+)"')
        T.re2_CheckPointNAT = T.re2(
            'xlatedport:"(\\d+)".*\\sxlatedst:"(\\S+)".*\\sxlatesport:"(\\d+)".*\\sxlatesrc:"(\\S+)"')
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

        onpacket = function(engine, layer)

            local syslogstr = layer:rawbytes():tostring()
            -- ip_layer protocol
            local iplayer = layer:packet():find_layer("{0A2C724B-5B9F-4BA6-9C97-B05080558574}");
            local ip_sb = SB.new(iplayer:rawbytes():tostring())
            -- skip to get ip
            ip_sb:skip(12)
            local iplayer_deviceip = ip_sb:next_ipv4()
            -- engine:add_resource( "{7B431613-9291-49BF-F8D3-73578A445310}", layer:packet():flowid():id(), "NAT SYSLOG", syslogstr) 

            -- sources 
            local ipkey = toip_format(iplayer_deviceip)
            engine:update_counter(COUNTERID_FLOWGEN, ipkey, 0, #syslogstr)
            engine:update_counter(COUNTERID_FLOWGEN, ipkey, 1, #syslogstr)
            engine:update_counter(COUNTERID_FLOWGEN, ipkey, 2, 1)

            if syslogstr:find("NAT_ACCT", 1, true) then
                -- JIO device 

                local bret, mon, day, h, m, s, deviceip, cmd, proto, sip, sport, tsip, tsport, dip, dport =
                    T.re2_JioDeviceNATSyslog:partial_match_n(syslogstr)

                if bret == false then
                    return;
                end

                local tvsec = os.time({
                    year = tonumber(os.date('%Y')),
                    month = MONTHNAMES[mon],
                    day = tonumber(day),
                    hour = h,
                    min = m,
                    sec = s
                })
                local fkey = Fk.toflow_format_v4(proto, sip, sport, dip, dport)

                if cmd == "START" then
                    engine:update_flow_raw(fkey, 0, 1)
                    engine:tag_flow(fkey, "[natip]" .. tsip)
                    engine:tag_flow(fkey, "[natport]" .. tsport)
                    engine:tag_flow(fkey, "[deviceip]" .. deviceip)
                elseif cmd == "STOP" then
                    engine:terminate_flow(fkey)
                end
            elseif syslogstr:find("kernel: [", 1, true) then
                -- tacitine devices
                local bret, mon, day, h, m, s, sip, dip, proto, sport, dport =
                    T.re2_TacitineNATSylog:partial_match_n(syslogstr)

                if bret == false then
                    return;
                end

                local tvsec = os.time({
                    year = tonumber(os.date('%Y')),
                    month = MONTHNAMES[mon],
                    day = tonumber(day),
                    hour = h,
                    min = m,
                    sec = s
                })
                proto = PROTOCOl[proto]
                local fkey = Fk.toflow_format_v4(proto, sip, sport, dip, dport)
                engine:update_flow_raw(fkey, 0, 1)
                engine:tag_flow(fkey, "[deviceip]" .. iplayer_deviceip)
                engine:update_flow_raw(fkey, 1, 1)
                engine:terminate_flow(fkey)

            elseif syslogstr:find("LOG_TRANSLATION", 1, true) then
                -- CISCO device 
                local bret, mon, day, h, m, s, cmd, proto, sip, sport, tsip, tsport, dip, dport =
                    T.re2_CiscoNATSyslog:partial_match_n(syslogstr)
                if bret == false then
                    return;
                end

                local tvsec = os.time({
                    year = tonumber(os.date('%Y')),
                    month = MONTHNAMES[mon],
                    day = tonumber(day),
                    hour = h,
                    min = m,
                    sec = s
                })
                local fkey = Fk.toflow_format_v4(proto, tsip, tsport, dip, dport)
                if cmd == "Created" then
                    engine:update_flow_raw(fkey, 0, 1)
                    engine:tag_flow(fkey, "[natip]" .. sip)
                    engine:tag_flow(fkey, "[natport]" .. sport)
                    engine:tag_flow(fkey, "[deviceip]" .. iplayer_deviceip)

                elseif cmd == "Deleted" then
                    engine:update_flow_raw(fkey, 1, 1)
                    engine:terminate_flow(fkey)
                end
            elseif syslogstr:find("%IPNAT-6-CREATED", 1, true) or syslogstr:find("%IPNAT-6-DELETED", 1, true) then
                -- CISCO device 3
                local bret, sessid, mon, day, hd, m, s, cmd, proto, sip, sport, tsip, tsport, dip, dport =
                    T.re2_CiscoNATSyslog3:partial_match_n(syslogstr)
                if bret == false then
                    return;
                end

                local tvsec = os.time({
                    year = tonumber(os.date('%Y')),
                    month = MONTHNAMES[mon],
                    day = tonumber(day),
                    hour = h,
                    min = m,
                    sec = s
                })

                -- lua double swapper 
                if is_private_ip(sip) then
                    sip, tsip, sport, tsport = tsip, sip, tsport, sport
                elseif is_private(dip) then
                    dip, tsip, dport, tsport = tsip, dip, tsport, dport
                end
                local fkey = Fk.toflow_format_v4(proto, sip, sport, dip, dport)

                engine:tag_flow(fkey, "[natip]" .. tsip)
                engine:tag_flow(fkey, "[natport]" .. tsport)
                engine:tag_flow(fkey, "[deviceip]" .. iplayer_deviceip)

                if cmd == "CREATED" then
                    engine:update_flow_raw(fkey, 0, 1)
                elseif cmd == "DELETED" then
                    engine:update_flow_raw(fkey, 1, 1)
                    engine:terminate_flow(fkey)
                end

            elseif syslogstr:find("%IPNAT-6-NAT", 1, true) then

                -- CISCO device 2 
                local bret, mon, day, h, m, s, cmd, proto, sip, sport, tsip, tsport, dip, dport =
                    T.re2_CiscoNATSyslog2:partial_match_n(syslogstr)

                if bret == false then
                    return;
                end

                local tvsec = os.time({
                    year = tonumber(os.date('%Y')),
                    month = MONTHNAMES[mon],
                    day = tonumber(day),
                    hour = h,
                    min = m,
                    sec = s
                })
                local fkey = Fk.toflow_format_v4(proto, sip, sport, dip, dport)

                if cmd == "Created" then
                    engine:update_flow_raw(fkey, 0, 1)
                    engine:tag_flow(fkey, "[natip]" .. tsip)
                    engine:tag_flow(fkey, "[natport]" .. tsport)
                    engine:tag_flow(fkey, "[deviceip]" .. sip)
                elseif cmd == "Deleted" then
                    engine:update_flow_raw(fkey, 1, 1)
                    engine:terminate_flow(fkey)
                end

            elseif syslogstr:find("[nsess ", 1, true) then

                -- NetElastic BNG session NAT (not nprng port-range TRIG= lines)
                local bret, adddel, proto, username, sip, dip, sport, dport, natip, natsport,
                    year, mon, day, h, m, s = T.re2_NetElasticBNGNATSyslog:partial_match_n(syslogstr)

                if bret == false then
                    return;
                end

                local tvsec = os.time({
                    year = tonumber(year),
                    month = tonumber(mon),
                    day = tonumber(day),
                    hour = h,
                    min = m,
                    sec = s
                })
                local fkey = Fk.toflow_format_v4(proto, natip, sport, dip, dport)

                if adddel == "SADD" then
                    engine:update_flow_raw(fkey, 0, 1)
                    engine:tag_flow(fkey, "[natip]" .. sip)
                    engine:tag_flow(fkey, "[natport]" .. natsport)
                    engine:tag_flow(fkey, "[username]" .. username)
                    engine:tag_flow(fkey, "[addts]" .. tvsec)
                    engine:tag_flow(fkey, "[deviceip]" .. iplayer_deviceip)
                elseif adddel == "SDEL" then
                    engine:update_flow_raw(fkey, 1, 1)
                    engine:tag_flow(fkey, "[delts]" .. tvsec)
                    engine:tag_flow(fkey, "[deviceip]" .. iplayer_deviceip)
                    engine:terminate_flow(fkey)
                end

            elseif syslogstr:find("<NAT444>:<Session", 1, true) then
                -- Huawei device 
                local bret, adddel, stvsec, etvsec, sip, natip, sport, dip, dport, proto =
                    T.re2_HuaweiNATSyslog:partial_match_n(syslogstr)
                if bret == false then
                    return;
                end
                local fkey = Fk.toflow_format_v4(proto, natip, sport, dip, dport)
                if adddel == "SessionA" then
                    engine:update_flow_raw(fkey, 0, 1)
                    engine:tag_flow(fkey, "[natip]" .. sip)
                    engine:tag_flow(fkey, "[addts]" .. stvsec)
                    engine:tag_flow(fkey, "[deviceip]" .. iplayer_deviceip)

                elseif adddel == "SessionW" then
                    engine:update_flow_raw(fkey, 1, 1)
                    engine:tag_flow(fkey, "[delts]" .. etvsec)
                    engine:tag_flow(fkey, "[deviceip]" .. iplayer_deviceip)
                    engine:terminate_flow(fkey)
                end

            elseif syslogstr:find("firewall,info", 1, true) then
                -- MikroTik: gate on NAT ( vs src-mac so we skip RE2 on unrelated firewall,info noise
                if syslogstr:find("NAT (", 1, true) then
                    local bret, proto, sip, sport, dip, dport, natsip, natsport, natsip1, natsport1, natdip, natdport =
                        T.re2_MikroTikNATSyslog2:partial_match_n(syslogstr)

                    if bret == false then
                        return;
                    end
                    proto = PROTOCOl[proto]
                    local fkey = Fk.toflow_format_v4(proto, sip, sport, dip, dport)
                    engine:update_flow_raw(fkey, 0, 1)
                    engine:tag_flow(fkey, "[deviceip]" .. iplayer_deviceip)
                    engine:tag_flow(fkey, "[natip]" .. natsip1)
                    engine:tag_flow(fkey, "[natport]" .. natsport1)
                    engine:update_flow_raw(fkey, 1, 1)
                    engine:terminate_flow(fkey)
                elseif syslogstr:find("src-mac", 1, true) then
                    local bret, srcmac, proto, sip, sport, dip, dport =
                        T.re2_MikroTikNATSyslog:partial_match_n(syslogstr)
                    if bret == false then
                        return;
                    end
                    proto = PROTOCOl[proto]
                    local fkey = Fk.toflow_format_v4(proto, sip, sport, dip, dport)
                    engine:update_flow_raw(fkey, 0, 1)
                    engine:tag_flow(fkey, "[deviceip]" .. iplayer_deviceip)
                    engine:tag_flow(fkey, "[mac]" .. srcmac)
                    engine:update_flow_raw(fkey, 1, 1)
                    engine:terminate_flow(fkey)
                end
            elseif syslogstr:find('trandisp="snat+dnat"', 1, true) then
                local bret, date, time, sip, sport, dip, dport, proto, tranip, tranport, transip, transport =
                    T.re2_FortigateNATSylog:partial_match_n(syslogstr)
                if bret == false then
                    return;
                end
                local fkey = Fk.toflow_format_v4(proto, sip, sport, dip, dport)
                engine:update_flow_raw(fkey, 0, 1)
                engine:tag_flow(fkey, "[deviceip]" .. iplayer_deviceip)
                engine:tag_flow(fkey, "[natip]" .. tranip)
                engine:tag_flow(fkey, "[natport]" .. tranport)
                engine:update_flow_raw(fkey, 1, 1)
                engine:terminate_flow(fkey)
            elseif syslogstr:find('trandisp="snat"', 1, true) then
                local bret, date, time, sip, sport, dip, dport, proto, transip, transport =
                    T.re2_FortigateNATSylogSNat:partial_match_n(syslogstr)
                if bret == false then
                    return;
                end

                local fkey = Fk.toflow_format_v4(proto, sip, sport, dip, dport)

                engine:update_flow_raw(fkey, 0, 1)
                engine:tag_flow(fkey, "[deviceip]" .. iplayer_deviceip)
                engine:tag_flow(fkey, "[natip]" .. transip)
                engine:tag_flow(fkey, "[natport]" .. transport)
                engine:update_flow_raw(fkey, 1, 1)
                engine:terminate_flow(fkey)
            elseif syslogstr:find('trandisp="noop"', 1, true) and syslogstr:find("srcport", 1, true) then
                local bret, date, time, sip, sport, dip, dport, proto =
                    T.re2_FortigateNATSylogNoopPort:partial_match_n(syslogstr)
                if bret == false then
                    return;
                end
                local fkey = Fk.toflow_format_v4(proto, sip, sport, dip, dport)
                engine:update_flow_raw(fkey, 0, 1)
                engine:tag_flow(fkey, "[deviceip]" .. iplayer_deviceip)
                engine:update_flow_raw(fkey, 1, 1)
                engine:terminate_flow(fkey)
            elseif syslogstr:find('trandisp="noop"', 1, true) then
                local bret, date, time, sip, dip, proto = T.re2_FortigateNATSylogNoop:partial_match_n(syslogstr)

                if bret == false then
                    return;
                end
                if sip:match(":") then
                    return;
                end
                local fkey = Fk.toflow_format_v4(proto, sip, '0', dip, '0')
                engine:update_flow_raw(fkey, 0, 1)
                engine:tag_flow(fkey, "[deviceip]" .. iplayer_deviceip)
                engine:update_flow_raw(fkey, 1, 1)
                engine:terminate_flow(fkey)

            elseif syslogstr:find("CheckPoint", 1, true) and syslogstr:find("Accept", 1, true) then
                -- CheckPoint device 
                local bret, tvsec, dip, proto, sport, dport, sip = T.re2_CheckPointAccept:partial_match_n(syslogstr)
                if bret == false then
                    return;
                end

                -- Check for NAT fields
                local nat_bret, xlatedport, xlatedst, xlatesport, xlatesrc =
                    T.re2_CheckPointNAT:partial_match_n(syslogstr)

                if nat_bret then

                    -- lua double swapper 
                    natiptag, natporttag = "", ""
                    if is_private_ip(sip) then
                        sip, xlatesrc, sport, xlatesport = xlatesrc, sip, xlatesport, sport
                        natiptag, natporttag = xlatesrc, xlatesport
                    elseif is_private_ip(dip) then
                        dip, xlatedst, dport, xlatedport = xlatedst, dip, xlatedport, dport
                        natiptag, natporttag = xlatedst, xlatedport
                    end

                    -- NAT is present - use translated addresses for flow key
                    local fkey = Fk.toflow_format_v4(proto, sip, sport, dip, dport)
                    engine:update_flow_raw(fkey, 0, 1)
                    engine:tag_flow(fkey, "[natip]" .. natiptag)
                    engine:tag_flow(fkey, "[natport]" .. natporttag)
                    engine:tag_flow(fkey, "[deviceip]" .. iplayer_deviceip)
                    engine:tag_flow(fkey, "[timestamp]" .. tvsec)
                    engine:update_flow_raw(fkey, 1, 1)
                    engine:terminate_flow(fkey)
                else
                    -- No NAT - regular firewall flow
                    local fkey = Fk.toflow_format_v4(proto, sip, sport, dip, dport)
                    engine:update_flow_raw(fkey, 0, 1)
                    engine:tag_flow(fkey, "[deviceip]" .. iplayer_deviceip)
                    engine:tag_flow(fkey, "[timestamp]" .. tvsec)
                    engine:update_flow_raw(fkey, 1, 1)
                    engine:terminate_flow(fkey)
                end
            elseif syslogstr:find("src-mac", 1, true) and syslogstr:find("NAT (", 1, true) then
                -- MikroTik BSD-timestamped NAT (no firewall,info prefix)
                local bret, mon, day, h, m, s, srcmac, proto, sip, sport, dip, dport, natsip, natsport, natsip1, natsport1, natdip, natdport =
                    T.re2_MikroTikNATSyslog4:partial_match_n(syslogstr)

                if bret == false then
                    return;
                end
                proto = PROTOCOl[proto]
                local fkey = Fk.toflow_format_v4(proto, sip, sport, dip, dport)
                engine:update_flow_raw(fkey, 0, 1)
                engine:tag_flow(fkey, "[deviceip]" .. iplayer_deviceip)
                engine:tag_flow(fkey, "[natip]" .. natsip1)
                engine:tag_flow(fkey, "[natport]" .. natsport1)
                engine:tag_flow(fkey, "[mac]" .. srcmac)
                engine:update_flow_raw(fkey, 1, 1)
                engine:terminate_flow(fkey)
            elseif syslogstr:find("ASA",1,true) and syslogstr:find("Built outbound",1,true) then
                -- cisco asa
                local bret, proto, dip, dport, natsip1, natsport1, sip, sport =
                    T.re2_CiscoNATSyslog4:partial_match_n(syslogstr)

                if bret == false then
                    return;
                end
                if is_private_ip(dip) then
                    dip, dport, natsip1, natsport1 = natsip1, natsport1, dip, dport
                end
                proto = PROTOCOl[proto]
                local fkey = Fk.toflow_format_v4(proto, sip, sport, dip, dport)
                engine:update_flow_raw(fkey, 0, 1)
                engine:tag_flow(fkey, "[deviceip]" .. iplayer_deviceip)
                engine:tag_flow(fkey, "[natip]" .. natsip1)
                engine:tag_flow(fkey, "[natport]" .. natsport1)
                engine:update_flow_raw(fkey, 1, 1)
                engine:terminate_flow(fkey)
            elseif (syslogstr:find("ASA",1,true) and syslogstr:find("Built inbound",1,true)) or (syslogstr:find("ASA",1,true) and syslogstr:find("Teardown",1,true) and syslogstr:find("gaddr",1,true) ) then
                -- cisco asa
               
                local bret, proto, dip, dport, sip, sport, natsip1, natsport1 =
                    T.re2_CiscoNATSyslog5:partial_match_n(syslogstr)

                if bret == false then
                    return;
                end

                proto = PROTOCOl[proto]
                local fkey = Fk.toflow_format_v4(proto, sip, sport, dip, dport)
                engine:update_flow_raw(fkey, 0, 1)
                engine:tag_flow(fkey, "[deviceip]" .. iplayer_deviceip)
                engine:tag_flow(fkey, "[natip]" .. natsip1)
                engine:tag_flow(fkey, "[natport]" .. natsport1)
                engine:update_flow_raw(fkey, 1, 1)
                engine:terminate_flow(fkey)

                 engine:terminate_flow(fkey)
            elseif syslogstr:find("ASA",1,true) and ( syslogstr:find("Deny",1,true) or  syslogstr:find("Teardown",1,true)) then
                -- cisco asa
                local sport =0
                local dport = 0
                local bret, proto, sip, dip =
                    T.re2_CiscoNATSyslog6:partial_match_n(syslogstr)

                if bret == false then
                    return;
                end
                if sip:match("/") then
                    sip,sport = sip:match("([^/]+)/(%d+)")
                end
                if dip:match("/") then
                    dip,dport = dip:match("([^/]+)/(%d+)")
                end
                
                proto = PROTOCOl[string.upper(proto)]
                local fkey = Fk.toflow_format_v4(proto, sip, sport, dip, dport)
                engine:update_flow_raw(fkey, 0, 1)
                engine:tag_flow(fkey, "[deviceip]" .. iplayer_deviceip)
                engine:update_flow_raw(fkey, 1, 1)
                engine:terminate_flow(fkey)



            else
                --print(syslogstr)
                -- unrecognized syslog 
                -- engine:add_resource( "{7B431613-9291-49BF-F8D3-73578A445310}", layer:packet():flowid():id(), "NAT SYSLOG UNRECOGNIZED", syslogstr)

            end
        end
    }
}

