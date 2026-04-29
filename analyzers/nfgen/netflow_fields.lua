local NetflowFields = {}
NetflowFields.__index = NetflowFields

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function parse_port(val)
  if val == nil then
    return 0
  end
  local n = tonumber(val)
  if n then
    return n
  end

  local phex = tostring(val):match("p%-([0-9A-Fa-f]+)")
  if phex then
    return tonumber(phex, 16) or 0
  end

  local hex = tostring(val):match("([0-9A-Fa-f]+)")
  if hex then
    return tonumber(hex, 16) or 0
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

  local src_port = parse_port(f:porta_readable() or f:porta())
  local dst_port = parse_port(f:portz_readable() or f:portz())
  local proto = parse_protocol(f:protocol())

  local bytes = (flow:az_bytes() or 0) + (flow:za_bytes() or 0)
  local packets = (flow:az_packets() or 0) + (flow:za_packets() or 0)

  return {
    is_ipv6 = src_ip:find(":", 1, true) ~= nil or dst_ip:find(":", 1, true) ~= nil,
    src_ip = src_ip,
    dst_ip = dst_ip,
    src_port = src_port,
    dst_port = dst_port,
    proto = proto,
    bytes = bytes,
    packets = packets,
    az_bytes = flow:az_bytes(),
    za_bytes = flow:za_bytes(),
    az_packets = flow:az_packets(),
    za_packets = flow:za_packets(),
    start_sec = start_sec or 0,
    end_sec = end_sec or start_sec,
    tags = parse_tag_map(flow:tags() or "", allowed_tags),
  }
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
    { id = 1, len = 8, kind = "u64", value = function(ctx) return ctx.az_bytes end }, -- IN_BYTES (A->Z)
    { id = 2, len = 8, kind = "u64", value = function(ctx) return ctx.az_packets end }, -- IN_PKTS (A->Z)
    { id = 23, len = 8, kind = "u64", value = function(ctx) return ctx.za_bytes end }, -- OUT_BYTES (Z->A)
    { id = 24, len = 8, kind = "u64", value = function(ctx) return ctx.za_packets end }, -- OUT_PKTS (Z->A)
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
    { id = 1, len = 8, kind = "u64", value = function(ctx) return ctx.az_bytes end }, -- IN_BYTES (A->Z)
    { id = 2, len = 8, kind = "u64", value = function(ctx) return ctx.az_packets end }, -- IN_PKTS (A->Z)
    { id = 23, len = 8, kind = "u64", value = function(ctx) return ctx.za_bytes end }, -- OUT_BYTES (Z->A)
    { id = 24, len = 8, kind = "u64", value = function(ctx) return ctx.za_packets end }, -- OUT_PKTS (Z->A)
    { id = 150, len = 4, kind = "u32", value = function(ctx) return ctx.start_sec end }, -- flowStartSeconds
    { id = 151, len = 4, kind = "u32", value = function(ctx) return ctx.end_sec end }, -- flowEndSeconds
  }

  local next_tag_field_id = 50000
  for _, tag_id in ipairs(obj.tag_ids) do
    local tf = {
      id = next_tag_field_id,
      len = obj.tag_field_max_len,
      kind = "string_fixed",
      tag_id = tag_id,
      value = function(ctx)
        return ctx.tags[tag_id] or ""
      end,
    }
    v4[#v4 + 1] = tf
    v6[#v6 + 1] = tf
    next_tag_field_id = next_tag_field_id + 1
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
