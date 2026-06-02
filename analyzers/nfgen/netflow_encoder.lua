local NetflowEncoder = {}
local bit = require("bit")

local function be_u16(n)
  local v = tonumber(n) or 0
  v = math.floor(v) % 65536
  return string.char(math.floor(v / 256), v % 256)
end

local function be_u32(n)
  local v = tonumber(n) or 0
  v = math.floor(v) % 4294967296
  local b1 = math.floor(v / 16777216) % 256
  local b2 = math.floor(v / 65536)    % 256
  local b3 = math.floor(v / 256)      % 256
  local b4 = v % 256
  return string.char(b1, b2, b3, b4)
end

local function be_u64(n)
  local v = tonumber(n) or 0
  if v < 0 then v = 0 end
  local hi = math.floor(v / 4294967296)
  local lo = v % 4294967296
  return be_u32(hi) .. be_u32(lo)
end

local function pad_fixed_string(s, max_len)
  local raw = tostring(s or "")
  if #raw > max_len then return raw:sub(1, max_len) end
  if #raw < max_len then return raw .. string.rep("\0", max_len - #raw) end
  return raw
end

-- pad4: used for v9 flowsets only.
local function pad4(s)
  local rem = #s % 4
  if rem == 0 then return s end
  return s .. string.rep("\0", 4 - rem)
end

-- RFC 7011 §3.3.2: Set Length includes header + body + padding.
local function v10_padded_set(set_id, body_bytes)
  local base_len  = 4 + #body_bytes
  local pad_bytes = (4 - (base_len % 4)) % 4
  local total_len = base_len + pad_bytes
  return be_u16(set_id) .. be_u16(total_len) .. body_bytes .. string.rep("\0", pad_bytes)
end

-- ── NetFlow v5 helpers ────────────────────────────────────────────────────
-- RFC 3954: fixed 24-byte header + up to 30 fixed 48-byte flow records.
-- v5 has NO templates. IPv6 flows are mapped to 0.0.0.0 (not supported in v5).

local V5_MAX_RECORDS = 30

local function parse_ipv4_to_bytes_v5(ip)
  local a, b, c, d = tostring(ip or ""):match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
  if not a then return string.char(0, 0, 0, 0) end
  return string.char(tonumber(a), tonumber(b), tonumber(c), tonumber(d))
end

local function build_v5_header(state, now_sec, flow_count)
  local uptime_ms = (tonumber(now_sec) or os.time()) * 1000 - state.boot_time_ms
  if uptime_ms < 0 then uptime_ms = 0 end
  return be_u16(5)                                   -- version
    .. be_u16(flow_count)                            -- count
    .. be_u32(uptime_ms)                             -- SysUptime (ms)
    .. be_u32(now_sec)                               -- unix_secs
    .. be_u32(0)                                     -- unix_nsecs (sub-second, 0)
    .. be_u32(state.seq)                             -- flow_sequence
    .. string.char(0)                                -- engine_type (0 = RP)
    .. string.char(state.engine_id_byte or 0)        -- engine_id
    .. be_u16(0)                                     -- sampling_interval (0 = none)
end

local function build_v5_record(ctx)
  -- IPv6 src/dst mapped to 0.0.0.0 (v5 does not support IPv6)
  local src_bytes = ctx.is_ipv6 and string.char(0, 0, 0, 0)
                    or parse_ipv4_to_bytes_v5(ctx.src_ip)
  local dst_bytes = ctx.is_ipv6 and string.char(0, 0, 0, 0)
                    or parse_ipv4_to_bytes_v5(ctx.dst_ip)

  local packets = math.min(
    (tonumber(ctx.az_packets) or 0) + (tonumber(ctx.za_packets) or 0),
    0xFFFFFFFF)
  local bytes = math.min(
    (tonumber(ctx.az_bytes) or 0) + (tonumber(ctx.za_bytes) or 0),
    0xFFFFFFFF)

  -- v5 First/Last are uptime-relative ms; we only have epoch seconds,
  -- so we encode 0 for both (acceptable for most collectors).
  return src_bytes                       -- srcaddr   (4)
    .. dst_bytes                         -- dstaddr   (4)
    .. string.char(0, 0, 0, 0)          -- nexthop   (4)
    .. be_u16(0)                         -- input     (2)
    .. be_u16(0)                         -- output    (2)
    .. be_u32(packets)                   -- dPkts     (4)
    .. be_u32(bytes)                     -- dOctets   (4)
    .. be_u32(0)                         -- First     (4)
    .. be_u32(0)                         -- Last      (4)
    .. be_u16(ctx.src_port or 0)         -- srcport   (2)
    .. be_u16(ctx.dst_port or 0)         -- dstport   (2)
    .. string.char(0)                    -- pad1      (1)
    .. string.char(0)                    -- tcp_flags (1)
    .. string.char(ctx.proto or 0)       -- prot      (1)
    .. string.char(0)                    -- tos       (1)
    .. be_u16(0)                         -- src_as    (2)
    .. be_u16(0)                         -- dst_as    (2)
    .. string.char(0)                    -- src_mask  (1)
    .. string.char(0)                    -- dst_mask  (1)
    .. be_u16(0)                         -- pad2      (2)
    -- total: 48 bytes exactly per RFC 3954
end
-- ── end v5 helpers ────────────────────────────────────────────────────────

function NetflowEncoder.new_engine_state(engine_id, config, now_sec)
  local eid       = tonumber(engine_id) or 0
  local source_id = (tonumber(config.source_id_base) or 0) + eid
  return {
    engine_id                       = tostring(engine_id),
    engine_id_byte                  = eid % 256,          -- used by v5 header
    config_version                  = tostring(config.netflow_version or "v10"):lower(),
    source_id                       = source_id,
    seq                             = 0,
    packet_count                    = 0,
    boot_time_ms                    = (tonumber(now_sec) or os.time()) * 1000,
    last_template_send_sec          = 0,
    last_template_send_packet_count = 0,
    template_id_v4                  = tonumber(config.template_id_base) or 256,
    template_id_v6                  = (tonumber(config.template_id_base) or 256) + 1,
    batch = { v4 = {}, v6 = {} },
    cycle_added_records  = 0,
    cycle_sent_records   = 0,
    cycle_sent_packets   = 0,
  }
end

local function encode_field_value(field, ctx)
  local v = field.value(ctx)
  if field.kind == "u8" then
    return string.char((tonumber(v) or 0) % 256)
  elseif field.kind == "u16" then
    return be_u16(v)
  elseif field.kind == "u32" then
    return be_u32(v)
  elseif field.kind == "u64" then
    return be_u64(v)
  elseif field.kind == "ipv4" or field.kind == "ipv6" then
    local b = tostring(v or "")
    if #b ~= field.len then
      if #b > field.len then
        b = b:sub(1, field.len)
      else
        b = b .. string.rep("\0", field.len - #b)
      end
    end
    return b
  elseif field.kind == "string_fixed" then
    return pad_fixed_string(v, field.len)
  end
  return string.rep("\0", field.len)
end

local function encode_record(template_fields, ctx)
  local parts = {}
  for _, field in ipairs(template_fields) do
    parts[#parts + 1] = encode_field_value(field, ctx)
  end
  return table.concat(parts)
end

local function build_v9_template_flowset(template_id, template_fields)
  local field_specs = {}
  for _, field in ipairs(template_fields) do
    field_specs[#field_specs + 1] = be_u16(field.id) .. be_u16(field.len)
  end
  local template_record = be_u16(template_id) .. be_u16(#template_fields) .. table.concat(field_specs)
  local body = be_u16(0) .. be_u16(4 + #template_record) .. template_record
  return pad4(body)
end

local function build_v10_template_set(template_id, template_fields)
  local field_specs = {}
  for _, field in ipairs(template_fields) do
    if field.enterprise then
      local local_id = bit.band(tonumber(field.id) or 0, 0x7FFF)
      local pen      = tonumber(field.enterprise_id) or 0
      field_specs[#field_specs + 1] =
        be_u16(bit.bor(0x8000, local_id)) .. be_u16(field.len) .. be_u32(pen)
    else
      field_specs[#field_specs + 1] = be_u16(field.id) .. be_u16(field.len)
    end
  end
  local template_record = be_u16(template_id) .. be_u16(#template_fields) .. table.concat(field_specs)
  return v10_padded_set(2, template_record)
end

local function build_v9_data_flowset(template_id, records)
  local payload = table.concat(records)
  local body    = be_u16(template_id) .. be_u16(4 + #payload) .. payload
  return pad4(body)
end

local function build_v10_data_set(template_id, records)
  local payload = table.concat(records)
  return v10_padded_set(template_id, payload)
end

local function build_v9_header(state, now_sec, flow_count)
  local uptime_ms = (tonumber(now_sec) or os.time()) * 1000 - state.boot_time_ms
  if uptime_ms < 0 then uptime_ms = 0 end
  return be_u16(9)
    .. be_u16(flow_count)
    .. be_u32(uptime_ms)
    .. be_u32(now_sec)
    .. be_u32(state.seq)
    .. be_u32(state.source_id)
end

local function build_v10_header(state, now_sec, payload_len)
  return be_u16(10)
    .. be_u16(16 + payload_len)
    .. be_u32(now_sec)
    .. be_u32(state.seq)
    .. be_u32(state.source_id)
end

function NetflowEncoder.send_templates(state, sender, fields, now_sec, config)
  local v4_fields = fields.templates.v4
  local v6_fields = fields.templates.v6
  local t4        = state.template_id_v4
  local t6        = state.template_id_v6

  local payload
  if config.netflow_version == "v9" then
    local s1 = build_v9_template_flowset(t4, v4_fields)
    local s2 = build_v9_template_flowset(t6, v6_fields)
    payload   = build_v9_header(state, now_sec, 2) .. s1 .. s2
  else
    local s1  = build_v10_template_set(t4, v4_fields)
    local s2  = build_v10_template_set(t6, v6_fields)
    local sets = s1 .. s2
    payload   = build_v10_header(state, now_sec, #sets) .. sets
  end

  if sender:send(payload) then
    state.last_template_send_sec          = now_sec
    state.last_template_send_packet_count = state.packet_count
  end
end

function NetflowEncoder.maybe_send_templates(state, sender, fields, now_sec, config)
  -- v5 has no templates — skip entirely
  if config.netflow_version == "v5" then return end

  local refresh_seconds = tonumber(config.template_refresh_seconds) or 15
  local refresh_packets = tonumber(config.template_refresh_packets) or 10

  local by_time = (state.last_template_send_sec == 0)
    or (refresh_seconds > 0 and (now_sec - state.last_template_send_sec) >= refresh_seconds)

  local by_packets = (state.last_template_send_packet_count == 0)
    or (refresh_packets > 0
        and (state.packet_count - state.last_template_send_packet_count) >= refresh_packets)

  if by_time or by_packets then
    NetflowEncoder.send_templates(state, sender, fields, now_sec, config)
  end
end

function NetflowEncoder.reset_batch(state)
  state.batch.v4           = {}
  state.batch.v6           = {}
  state.cycle_added_records = 0
  state.cycle_sent_records  = 0
  state.cycle_sent_packets  = 0
end

function NetflowEncoder.is_full(state, config, template_key)
  local max_per_packet = tonumber(config.max_records_per_packet) or 24
  -- v5 is capped at 30 by RFC 3954 regardless of config
  if config.netflow_version == "v5" then
    max_per_packet = V5_MAX_RECORDS
  end
  if max_per_packet <= 0 then max_per_packet = 1 end
  if template_key then
    return #state.batch[template_key] >= max_per_packet
  end
  return #state.batch.v4 >= max_per_packet or #state.batch.v6 >= max_per_packet
end

local function send_batch(state, sender, template_key, now_sec, config)
  local records = state.batch[template_key]
  if records == nil or #records == 0 then return end

  if config.netflow_version == "v5" then
    -- v5: no templates, no sets — header directly followed by raw 48-byte records.
    -- Chunk into max V5_MAX_RECORDS per UDP packet (RFC 3954).
    local i = 1
    while i <= #records do
      local chunk = {}
      for j = i, math.min(i + V5_MAX_RECORDS - 1, #records) do
        chunk[#chunk + 1] = records[j]
      end
      local packet = build_v5_header(state, now_sec, #chunk) .. table.concat(chunk)
      if sender:send(packet) then
        state.seq            = state.seq + #chunk  -- v5 seq = cumulative flow count
        state.packet_count   = state.packet_count + 1
        state.cycle_sent_records = state.cycle_sent_records + #chunk
        state.cycle_sent_packets = state.cycle_sent_packets + 1
      end
      i = i + V5_MAX_RECORDS
    end
    state.batch[template_key] = {}
    return
  end

  -- v9 / v10 path
  local template_id = (template_key == "v6") and state.template_id_v6 or state.template_id_v4
  local data_set, packet

  if config.netflow_version == "v9" then
    data_set = build_v9_data_flowset(template_id, records)
    packet   = build_v9_header(state, now_sec, #records) .. data_set
  else
    data_set = build_v10_data_set(template_id, records)
    packet   = build_v10_header(state, now_sec, #data_set) .. data_set
  end

  if sender:send(packet) then
    if config.netflow_version == "v9" then
      state.seq = state.seq + 1
    else
      state.seq = state.seq + #records
    end
    state.packet_count        = state.packet_count + 1
    state.cycle_sent_records  = state.cycle_sent_records + #records
    state.cycle_sent_packets  = state.cycle_sent_packets + 1
  end
  state.batch[template_key] = {}
end

function NetflowEncoder.add_flow_record(state, fields, flow)
  local key, template_fields, ctx = fields:template_for_flow(flow)

  if state.config_version == "v5" then
    -- v5: skip IPv6 flows entirely (no IPv6 support in v5 spec)
    if ctx.is_ipv6 then return key end
    local record = build_v5_record(ctx)
    state.batch[key][#state.batch[key] + 1] = record
    state.cycle_added_records = state.cycle_added_records + 1
    return key
  end

  local record = encode_record(template_fields, ctx)
  state.batch[key][#state.batch[key] + 1] = record
  state.cycle_added_records = state.cycle_added_records + 1
  return key
end

function NetflowEncoder.send_batch_if_full(state, sender, fields, now_sec, config, template_key)
  if NetflowEncoder.is_full(state, config, template_key) then
    NetflowEncoder.maybe_send_templates(state, sender, fields, now_sec, config)
    send_batch(state, sender, template_key, now_sec, config)
  end
end

function NetflowEncoder.flush_all(state, sender, fields, now_sec, config)
  if #state.batch.v4 > 0 or #state.batch.v6 > 0 then
    NetflowEncoder.maybe_send_templates(state, sender, fields, now_sec, config)
    send_batch(state, sender, "v4", now_sec, config)
    send_batch(state, sender, "v6", now_sec, config)
  end
end

function NetflowEncoder.cycle_stats(state)
  return {
    added_records = state.cycle_added_records or 0,
    sent_records  = state.cycle_sent_records  or 0,
    sent_packets  = state.cycle_sent_packets  or 0,
    queued_v4     = #state.batch.v4,
    queued_v6     = #state.batch.v6,
    sequence      = state.seq or 0,
  }
end

return NetflowEncoder
