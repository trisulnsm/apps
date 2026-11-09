--
-- Login syslog parser
--
-- Sample message:
--   LOCAL7.INFO: 2026-11-01T17:55:00+05:30 ftc-mum-kvm3-inhouse1 logins[2270828]: \
--       ClientId="FT045507" Ip="2405:201:680e:11d4:75c0:289d:935b:6297" source="FTC_OAUTH" ts=1793535679
--
-- The syslog only carries label mappings (IP -> ClientId, IP -> source).
-- Actual byte counts come from flow records and are metered in mmon.lua.
--
TrisulPlugin = {

    -- the ID block, you can skip the fields marked 'optional '
    --
    id = {
        name = "Login syslog packet monitor",
        description = "Listen to LOGIN_SYSLOG login packets",
    },

    -- COMMON FUNCTIONS:  onload, onunload, onmessage
    --
    onload = function() end,
    onunload = function() end,

    simplecounter = {

        -- attach to UDP>LOGIN_SYSLOG protocol
        protocol_guid = "{EDCD967A-CEF8-4A21-8D98-1A435A6CD55A}",

        -- also work in NETFLOW_TAP mode
        flow_counter = true,

        -- each LOGIN_SYSLOG packet
        onpacket = function(engine, layer)
            local syslogstr = layer:rawbytes():tostring()

            local t = {}
            t["ClientId"] = ""
            t["Ip"] = ""
            t["source"] = ""

            -- key="value"  (value may contain colons for IPv6, so match anything but a quote)
            for k, v in string.gmatch(syslogstr, '(%w+)="([^"]+)"') do
                t[k] = v
            end

            -- key=value  (unquoted, e.g. ts=1793535679)
            for k, v in string.gmatch(syslogstr, '(%w+)=([%w%.%-%:]+)') do
                if t[k] == nil or #t[k] == 0 then
                    t[k] = v
                end
            end

            -- no IP, nothing to map - bail out, don't post anything
            if #t["Ip"] == 0 then
                return
            end

            -- IP -> ClientId mapping
            if #t["ClientId"] > 0 then
                engine:post_message_frontend(
                    "{A563693D-A2EC-41BB-8481-C4EB0316AFF8}",
                    "CLIENTID|" .. t["Ip"] .. "|" .. t["ClientId"]
                )
            end

            -- IP -> source mapping
            if #t["source"] > 0 then
                engine:post_message_frontend(
                    "{A563693D-A2EC-41BB-8481-C4EB0316AFF8}",
                    "SOURCE|" .. t["Ip"] .. "|" .. t["source"]
                )
            end

            return
        end,
    },
}
