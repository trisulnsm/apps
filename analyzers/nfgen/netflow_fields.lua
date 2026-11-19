local NetflowFields = {}
NetflowFields.__index = NetflowFields

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Port of a flow end. Trisul port keys look like "p-01BB" (readable "443"); ICMP flows have
-- "icmp00" / "icmp01" with no type or code in them. The old catch-all hex match turned "icmp01"
-- into 12 (the "c"), so only a raw p-XXXX key or a plain number is trusted; anything else,
-- ICMP included, is exported as port 0.
local unknown_port_keys_logged = 0
local function parse_port(raw, readable)
  local phex = tostring(raw or ""):match("^p%-(%x+)$")
  if phex then
    return tonumber(phex, 16) or 0
  end
  local n = tonumber(readable)
  if n and n >= 0 and n <= 65535 then
    return n
  end
  if tostring(raw or ""):match("^icmp%x%x$") then
    return 0
  end
  if unknown_port_keys_logged < 10 and T and T.logdebug then
    unknown_port_keys_logged = unknown_port_keys_logged + 1
    T.logdebug(string.format("nfgen: non-port key raw=%s readable=%s, exported as 0", tostring(raw), tostring(readable)))
  end
  return 0
end

local function parse_protocol(val)
  if val == nil then
    return 0
  end
  local v = tostring(val)
  local n = tonumber(v, 16)
  if n ~= nil then
    return n
  end
  return tonumber(v) or 0
end

local function parse_ipv4_to_bytes(ip)
  local a, b, c, d = tostring(ip):match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
  if not a then
    return string.char(0, 0, 0, 0)
  end
  return string.char(tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0, tonumber(d) or 0)
end

local function parse_hextet(h)
  if h == nil or h == "" then
    return 0
  end
  return tonumber(h, 16) or 0
end

local function ipv4_tail_to_hextets(ipv4)
  local a, b, c, d = ipv4:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
  if not a then
    return nil
  end
  local x = (tonumber(a) or 0) * 256 + (tonumber(b) or 0)
  local y = (tonumber(c) or 0) * 256 + (tonumber(d) or 0)
  return string.format("%x", x), string.format("%x", y)
end

local function parse_ipv6_to_bytes(ip)
  local raw = tostring(ip):lower()
  if raw == "" then
    return string.rep("\0", 16)
  end

  local left, right = raw:match("^(.-)::(.-)$")
  local left_parts = {}
  local right_parts = {}

  local function collect_parts(part, out)
    if part == nil or part == "" then
      return
    end
    for h in part:gmatch("[^:]+") do
      out[#out + 1] = h
    end
  end

  if left ~= nil then
    collect_parts(left, left_parts)
    collect_parts(right, right_parts)
  else
    collect_parts(raw, left_parts)
  end

  -- Expand embedded IPv4 tail if present.
  local function expand_ipv4_tail(parts)
    if #parts == 0 then
      return parts
    end
    local last = parts[#parts]
    if last and last:find("%.") then
      local h1, h2 = ipv4_tail_to_hextets(last)
      if h1 and h2 then
        parts[#parts] = h1
        parts[#parts + 1] = h2
      end
    end
    return parts
  end

  left_parts = expand_ipv4_tail(left_parts)
  right_parts = expand_ipv4_tail(right_parts)

  local total = #left_parts + #right_parts
  local fill = 8 - total
  if fill < 0 then
    fill = 0
  end

  local all = {}
  for _, h in ipairs(left_parts) do
    all[#all + 1] = parse_hextet(h)
  end
  for _ = 1, fill do
    all[#all + 1] = 0
  end
  for _, h in ipairs(right_parts) do
    all[#all + 1] = parse_hextet(h)
  end

  while #all < 8 do
    all[#all + 1] = 0
  end

  if #all > 8 then
    local trimmed = {}
    for i = 1, 8 do
      trimmed[i] = all[i]
    end
    all = trimmed
  end

  local out = {}
  for _, h in ipairs(all) do
    out[#out + 1] = string.char(math.floor(h / 256) % 256, h % 256)
  end
  return table.concat(out)
end

local function parse_tag_map(tag_string, allowed_tags)
  local out = {}
  for token in tostring(tag_string or ""):gmatch("[^|]+") do
    local t = trim(token)

    local k1, v1 = t:match("^([^:]+):(.+)$")
    if k1 and v1 then
      local key = trim(k1):upper()
      if (allowed_tags == nil or allowed_tags[key]) and out[key] == nil then
        out[key] = trim(v1)
      end
    else
      -- Also support tags in [id]value form.
      local k2, v2 = t:match("^%[([^%]]+)%](.+)$")
      if k2 and v2 then
        local key = trim(k2):upper()
        if (allowed_tags == nil or allowed_tags[key]) and out[key] == nil then
          out[key] = trim(v2)
        end
      end
    end
  end
  return out
end

local function build_context(flow, allowed_tags)
  local f = flow:flow()
  local start_sec, end_sec = flow:time_window()
  local src_ip = f:ipa_readable() or ""
  local dst_ip = f:ipz_readable() or ""

  local src_port = parse_port(f:porta(), f:porta_readable())
  local dst_port = parse_port(f:portz(), f:portz_readable())
  local proto = parse_protocol(f:protocol())

  return {
    flow_id = f:id(),
    state = flow:state() or 0,
    is_ipv6 = src_ip:find(":", 1, true) ~= nil or dst_ip:find(":", 1, true) ~= nil,
    src_ip = src_ip,
    dst_ip = dst_ip,
    src_port = src_port,
    dst_port = dst_port,
    proto = proto,
    -- running totals since the flow started (Trisul counters)
    az_bytes = tonumber(flow:az_bytes()) or 0,
    za_bytes = tonumber(flow:za_bytes()) or 0,
    az_packets = tonumber(flow:az_packets()) or 0,
    za_packets = tonumber(flow:za_packets()) or 0,
    start_sec = start_sec or 0,
    end_sec = end_sec or start_sec or 0,
    tags = parse_tag_map(flow:tags() or "", allowed_tags),
  }
end

-- NetFlow/IPFIX records are unidirectional: a Trisul flow becomes an A->Z record and a Z->A
-- record (endpoints swapped), each carrying its own bytes/packets in IE 1/2. Collectors such as
-- Trisul (MatchBiDirectionalFlows) merge the pair back. `delta` holds the counts to report for
-- this export (not running totals), `start_sec` the start of the period they cover.
-- A direction with no new packets is left out.
function NetflowFields.directional_records(ctx, delta, start_sec)
  local out = {}
  local function add(src_ip, dst_ip, src_port, dst_port, bytes, packets)
    if packets <= 0 and bytes <= 0 then return end
    out[#out + 1] = {
      is_ipv6 = ctx.is_ipv6,
      src_ip = src_ip, dst_ip = dst_ip,
      src_port = src_port, dst_port = dst_port,
      proto = ctx.proto,
      bytes = bytes, packets = packets,
      start_sec = start_sec, end_sec = ctx.end_sec,
      tags = ctx.tags,
    }
  end
  add(ctx.src_ip, ctx.dst_ip, ctx.src_port, ctx.dst_port, delta.az_bytes, delta.az_packets)
  add(ctx.dst_ip, ctx.src_ip, ctx.dst_port, ctx.src_port, delta.za_bytes, delta.za_packets)
  return out
end

function NetflowFields.new(config)
  local obj = setmetatable({}, NetflowFields)
  obj.tag_ids = {}
  obj.tag_set = {}
  obj.tag_field_max_len = tonumber(config.tag_field_max_len) or 64
  for _, tagid in ipairs(config.tag_template_ids or {}) do
    local t = tostring(tagid):upper()
    obj.tag_ids[#obj.tag_ids + 1] = t
    obj.tag_set[t] = true
  end

  local v4 = {
    { id = 8, len = 4, kind = "ipv4", value = function(ctx) return parse_ipv4_to_bytes(ctx.src_ip) end }, -- sourceIPv4
    { id = 7, len = 2, kind = "u16", value = function(ctx) return ctx.src_port end }, -- source port
    { id = 4, len = 1, kind = "u8", value = function(ctx) return ctx.proto end }, -- protocol
    { id = 12, len = 4, kind = "ipv4", value = function(ctx) return parse_ipv4_to_bytes(ctx.dst_ip) end }, -- destinationIPv4
    { id = 11, len = 2, kind = "u16", value = function(ctx) return ctx.dst_port end }, -- dest port
    { id = 10, len = 4, kind = "u32", value = function() return 0 end }, -- ifindex in
    { id = 14, len = 4, kind = "u32", value = function() return 0 end }, -- ifindex out
    { id = 1, len = 8, kind = "u64", value = function(ctx) return ctx.bytes end }, -- octetDeltaCount (this direction)
    { id = 2, len = 8, kind = "u64", value = function(ctx) return ctx.packets end }, -- packetDeltaCount (this direction)
    { id = 150, len = 4, kind = "u32", value = function(ctx) return ctx.start_sec end }, -- flowStartSeconds
    { id = 151, len = 4, kind = "u32", value = function(ctx) return ctx.end_sec end }, -- flowEndSeconds
  }

  local v6 = {
    { id = 27, len = 16, kind = "ipv6", value = function(ctx) return parse_ipv6_to_bytes(ctx.src_ip) end }, -- sourceIPv6
    { id = 7, len = 2, kind = "u16", value = function(ctx) return ctx.src_port end }, -- source port
    { id = 4, len = 1, kind = "u8", value = function(ctx) return ctx.proto end }, -- protocol
    { id = 28, len = 16, kind = "ipv6", value = function(ctx) return parse_ipv6_to_bytes(ctx.dst_ip) end }, -- destinationIPv6
    { id = 11, len = 2, kind = "u16", value = function(ctx) return ctx.dst_port end }, -- dest port
    { id = 10, len = 4, kind = "u32", value = function() return 0 end }, -- ifindex in
    { id = 14, len = 4, kind = "u32", value = function() return 0 end }, -- ifindex out
    { id = 1, len = 8, kind = "u64", value = function(ctx) return ctx.bytes end }, -- octetDeltaCount (this direction)
    { id = 2, len = 8, kind = "u64", value = function(ctx) return ctx.packets end }, -- packetDeltaCount (this direction)
    { id = 150, len = 4, kind = "u32", value = function(ctx) return ctx.start_sec end }, -- flowStartSeconds
    { id = 151, len = 4, kind = "u32", value = function(ctx) return ctx.end_sec end }, -- flowEndSeconds
  }

  -- IPFIX (v10): IE ids with bit 15 set are enterprise-specific and MUST be
  -- followed by a 4-byte PEN in the template (RFC 7011). Plain ids >= 0x8000
  -- without PEN corrupt the template and mis-align all following fields.
  -- We use explicit enterprise encoding via netflow_encoder.build_v10_template_set.
  local pen = tonumber(config.ipfix_enterprise_number) or 39499
  local v9_base = tonumber(config.tag_v9_field_type_base) or 200
  local nfver = tostring(config.netflow_version or "v10"):lower()
  if nfver == "10" or nfver == "ipfix" then
    nfver = "v10"
  elseif nfver == "9" then
    nfver = "v9"
  end

  if nfver == "v9" and (#obj.tag_ids > 0) and (v9_base + #obj.tag_ids - 1) >= 0x8000 then
    if T and T.logerror then
      T.logerror(
        "nfgen: tag_v9_field_type_base is too high for tag_template_ids count; "
          .. "reduce tag_v9_field_type_base or use fewer tag_template_ids"
      )
    end
  end

  for i, tag_id in ipairs(obj.tag_ids) do
    local tf = {
      len = obj.tag_field_max_len,
      kind = "string_fixed",
      tag_id = tag_id,
      value = function(ctx)
        return ctx.tags[tag_id] or ""
      end,
    }
    if nfver == "v10" then
      tf.enterprise = true
      tf.id = i -- local IE number 1..N under ipfix_enterprise_number
      tf.enterprise_id = pen
    else
      tf.enterprise = false
      tf.id = v9_base + (i - 1)
    end
    v4[#v4 + 1] = tf
    v6[#v6 + 1] = tf
  end

  obj.templates = {
    v4 = v4,
    v6 = v6,
  }
  return obj
end

function NetflowFields:template_for_flow(flow)
  local ctx = build_context(flow, self.tag_set)
  if ctx.is_ipv6 then
    return "v6", self.templates.v6, ctx
  end
  return "v4", self.templates.v4, ctx
end

return NetflowFields
