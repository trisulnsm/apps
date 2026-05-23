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
  local b2 = math.floor(v / 65536) % 256
  local b3 = math.floor(v / 256) % 256
  local b4 = v % 256
  return string.char(b1, b2, b3, b4)
end

local function be_u64(n)
  local v = tonumber(n) or 0
  if v < 0 then
    v = 0
  end
  local hi = math.floor(v / 4294967296)
  local lo = v % 4294967296
  return be_u32(hi) .. be_u32(lo)
end

local function pad_fixed_string(s, max_len)
  local raw = tostring(s or "")
  if #raw > max_len then
    return raw:sub(1, max_len)
  end
  if #raw < max_len then
    return raw .. string.rep("\0", max_len - #raw)
  end
  return raw
end

-- pad4 is still used for v9 flowsets (v9 length fields do not need to
-- account for padding, so the old behaviour is correct for v9).
local function pad4(s)
  local rem = #s % 4
  if rem == 0 then
    return s
  end
  return s .. string.rep("\0", 4 - rem)
end

-- RFC 7011 §3.3.2: the Set Length field MUST include the Set Header,
-- all records, AND any trailing padding bytes.  Compute padding first so
-- the length field written into the wire bytes is already the full padded
-- size.  This replaces the previous pattern of writing an unpadded length
-- then calling pad4() on the assembled body.
local function v10_padded_set(set_id, body_bytes)
  local base_len  = 4 + #body_bytes          -- 4-byte set header + body
  local pad_bytes = (4 - (base_len % 4)) % 4 -- 0-3 bytes to reach 32-bit boundary
  local total_len = base_len + pad_bytes
  return be_u16(set_id) .. be_u16(total_len) .. body_bytes .. string.rep("\0", pad_bytes)
end

function NetflowEncoder.new_engine_state(engine_id, config, now_sec)
  local eid = tonumber(engine_id) or 0
  local source_id = (tonumber(config.source_id_base) or 0) + eid
  return {
    engine_id = tostring(engine_id),
    source_id = source_id,
    seq = 0,
    packet_count = 0,
    boot_time_ms = (tonumber(now_sec) or os.time()) * 1000,
    last_template_send_sec = 0,
    last_template_send_packet_count = 0,
    template_id_v4 = tonumber(config.template_id_base) or 256,
    template_id_v6 = (tonumber(config.template_id_base) or 256) + 1,
    batch = {
      v4 = {},
      v6 = {},
    },
    cycle_added_records = 0,
    cycle_sent_records = 0,
    cycle_sent_packets = 0,
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
  -- v9: FlowSet ID 0, length does not need to cover padding (pad4 appends after).
  local body = be_u16(0) .. be_u16(4 + #template_record) .. template_record
  return pad4(body)
end

local function build_v10_template_set(template_id, template_fields)
  local field_specs = {}
  for _, field in ipairs(template_fields) do
    -- RFC 7011: enterprise-specific IEs use bit 15 of the IE id and are followed
    -- by the 4-byte Enterprise Number (8 bytes total per field in the template).
    if field.enterprise then
      local local_id = bit.band(tonumber(field.id) or 0, 0x7FFF)
      local pen = tonumber(field.enterprise_id) or 0
      field_specs[#field_specs + 1] =
        be_u16(bit.bor(0x8000, local_id)) .. be_u16(field.len) .. be_u32(pen)
    else
      field_specs[#field_specs + 1] = be_u16(field.id) .. be_u16(field.len)
    end
  end
  -- Template record: template ID (2) + field count (2) + field specifiers.
  local template_record = be_u16(template_id) .. be_u16(#template_fields) .. table.concat(field_specs)
  -- FIX (Bug 1): Set ID = 2 for IPFIX Template Sets.  v10_padded_set()
  -- writes the Length field AFTER computing padding so it includes padding bytes,
  -- satisfying RFC 7011 §3.3.2.
  return v10_padded_set(2, template_record)
end

local function build_v9_data_flowset(template_id, records)
  local payload = table.concat(records)
  -- v9: FlowSet length field does not need to cover the pad4 trailer.
  local body = be_u16(template_id) .. be_u16(4 + #payload) .. payload
  return pad4(body)
end

local function build_v10_data_set(template_id, records)
  local payload = table.concat(records)
  -- FIX (Bug 1): Set ID = template_id (>= 256) for IPFIX Data Sets.
  -- v10_padded_set() ensures the Length field includes padding bytes,
  -- satisfying RFC 7011 §3.3.2.  Without this, collectors that use the
  -- Set Length to advance their parse cursor will mis-align on all sets
  -- after the first unaligned one and drop the entire IPFIX message.
  return v10_padded_set(template_id, payload)
end

local function build_v9_header(state, now_sec, flow_count)
  local uptime_ms = (tonumber(now_sec) or os.time()) * 1000 - state.boot_time_ms
  if uptime_ms < 0 then
    uptime_ms = 0
  end
  return be_u16(9)
    .. be_u16(flow_count)
    .. be_u32(uptime_ms)
    .. be_u32(now_sec)
    .. be_u32(state.seq)
    .. be_u32(state.source_id)
end

local function build_v10_header(state, now_sec, payload_len)
  local total_len = 16 + payload_len
  return be_u16(10)
    .. be_u16(total_len)
    .. be_u32(now_sec)
    .. be_u32(state.seq)
    .. be_u32(state.source_id)
end

function NetflowEncoder.send_templates(state, sender, fields, now_sec, config)
  local v4_fields = fields.templates.v4
  local v6_fields = fields.templates.v6
  local t4 = state.template_id_v4
  local t6 = state.template_id_v6

  local payload
  if config.netflow_version == "v9" then
    local s1 = build_v9_template_flowset(t4, v4_fields)
    local s2 = build_v9_template_flowset(t6, v6_fields)
    payload = build_v9_header(state, now_sec, 2) .. s1 .. s2
  else
    local s1 = build_v10_template_set(t4, v4_fields)
    local s2 = build_v10_template_set(t6, v6_fields)
    local sets = s1 .. s2
    payload = build_v10_header(state, now_sec, #sets) .. sets
  end

  if sender:send(payload) then
    state.packet_count = state.packet_count + 1
    state.last_template_send_sec = now_sec
    state.last_template_send_packet_count = state.packet_count
    -- Note: template records do NOT count toward the IPFIX sequence number
    -- (RFC 7011 §3.1), so state.seq is intentionally not incremented here.
  end
end

function NetflowEncoder.maybe_send_templates(state, sender, fields, now_sec, config)
  local refresh_seconds = tonumber(config.template_refresh_seconds) or 30
  local refresh_packets = tonumber(config.template_refresh_packets) or 20

  local by_time = (state.last_template_send_sec == 0)
    or (refresh_seconds > 0 and (now_sec - state.last_template_send_sec) >= refresh_seconds)

  local by_packets = (state.last_template_send_packet_count == 0)
    or (refresh_packets > 0 and (state.packet_count - state.last_template_send_packet_count) >= refresh_packets)

  if by_time or by_packets then
    NetflowEncoder.send_templates(state, sender, fields, now_sec, config)
  end
end

function NetflowEncoder.reset_batch(state)
  state.batch.v4 = {}
  state.batch.v6 = {}
  state.cycle_added_records = 0
  state.cycle_sent_records = 0
  state.cycle_sent_packets = 0
end

function NetflowEncoder.is_full(state, config, template_key)
  local max_per_packet = tonumber(config.max_records_per_packet) or 24
  if max_per_packet <= 0 then
    max_per_packet = 1
  end
  if template_key then
    return #state.batch[template_key] >= max_per_packet
  end
  return #state.batch.v4 >= max_per_packet or #state.batch.v6 >= max_per_packet
end

local function send_batch(state, sender, template_key, now_sec, config)
  local records = state.batch[template_key]
  if records == nil or #records == 0 then
    return
  end
  local template_id = (template_key == "v6") and state.template_id_v6 or state.template_id_v4
  local data_set
  local packet
  if config.netflow_version == "v9" then
    data_set = build_v9_data_flowset(template_id, records)
    packet = build_v9_header(state, now_sec, #records) .. data_set
  else
    data_set = build_v10_data_set(template_id, records)
    packet = build_v10_header(state, now_sec, #data_set) .. data_set
  end

  if sender:send(packet) then
    -- FIX (Bug 2): RFC 3954 §8 defines the v9 Sequence Number as a count of
    -- export *packets* (increment by 1), not records.  RFC 7011 §3.1 defines
    -- the v10/IPFIX Sequence Number as a count of prior *data records*
    -- (increment by the number of records in this packet). Thanks to Claude
    if config.netflow_version == "v9" then
      state.seq = state.seq + 1
    else
      state.seq = state.seq + #records
    end
    state.packet_count = state.packet_count + 1
    state.cycle_sent_records = state.cycle_sent_records + #records
    state.cycle_sent_packets = state.cycle_sent_packets + 1
  end
  state.batch[template_key] = {}
end

function NetflowEncoder.add_flow_record(state, fields, flow)
  local key, template_fields, ctx = fields:template_for_flow(flow)
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
    sent_records = state.cycle_sent_records or 0,
    sent_packets = state.cycle_sent_packets or 0,
    queued_v4 = #state.batch.v4,
    queued_v6 = #state.batch.v6,
    sequence = state.seq or 0,
  }
end

return NetflowEncoder
