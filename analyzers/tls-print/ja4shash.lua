--
-- ja4shash.lua
--
-- TYPE: FRONTEND SCRIPT
-- PURPOSE: JA4S TLS fingerprint (server hello only)
-- DESCRIPTION: Implements https://github.com/FoxIO-LLC/ja4
--

local ffi = require('ffi')

local status, C
for _, lib in ipairs({'libcrypto.so', 'libcrypto.so.3', 'libcrypto.so.1.1', 'libcrypto.so.1.0.2k', 'libcrypto.so.1.0.0'}) do
  status, C = pcall(function() return ffi.load(lib) end)
  if status then break end
end
if not status then error "Cant load FFI libcrypto version " end

local SWP = require'sweepbuf'
require 'mkconfig'

ffi.cdef[[
typedef struct sha256_state_st {
  unsigned int h[8];
  unsigned int Nl,Nh;
  unsigned int data[16];
  unsigned int num, md_len;
} SHA256_CTX;
int SHA256_Init(SHA256_CTX *c);
int SHA256_Update(SHA256_CTX *c, const void *data, size_t len);
int SHA256_Final(unsigned char *md, SHA256_CTX *c);
]]

local function sha256_12(input)
  local hashresults = ffi.new("uint8_t[32]")
  local ctx = ffi.new'SHA256_CTX'
  C.SHA256_Init(ctx)
  C.SHA256_Update(ctx, input, #input)
  C.SHA256_Final(hashresults, ctx)
  return T.util.bin2hex(ffi.string(hashresults, 32)):sub(1,12)
end

local GREASE_tbl = {
  [0x0A0A]=true,[0x1A1A]=true,[0x2A2A]=true,[0x3A3A]=true,
  [0x4A4A]=true,[0x5A5A]=true,[0x6A6A]=true,[0x7A7A]=true,
  [0x8A8A]=true,[0x9A9A]=true,[0xAAAA]=true,[0xBABA]=true,
  [0xCACA]=true,[0xDADA]=true,[0xEAEA]=true,[0xFAFA]=true
}

local TLS_VERSION_MAP = {
  [0x0304]="13",[0x0303]="12",[0x0302]="11",
  [0x0301]="10",[0x0300]="s3",[0x0002]="s2",
}

local function sorted_hex_csv(tbl)
  local copy = {}
  for _, v in ipairs(tbl) do copy[#copy+1] = v end
  table.sort(copy)
  local parts = {}
  for _, v in ipairs(copy) do parts[#parts+1] = string.format("%04x", v) end
  return table.concat(parts, ",")
end

-- JA4S = {ja4s_a}_{ja4s_b}
-- ja4s_a : t + version(2) + ext_count(2) + chosen_alpn(2)
-- ja4s_b : SHA256[:12]( chosen_cipher_hex + "_" + sorted ext hex csv )
-- Ref: https://github.com/FoxIO-LLC/ja4/blob/main/technical_details/JA4S.md
local function build_ja4s(ja4sf)
  local ver_str = TLS_VERSION_MAP[ja4sf.tls_version] or "00"
  if ja4sf.supported_version and TLS_VERSION_MAP[ja4sf.supported_version] then
    ver_str = TLS_VERSION_MAP[ja4sf.supported_version]
  end

  local ext_count = math.min(#ja4sf.extensions_raw, 99)

  local alpn_chars = "00"
  if ja4sf.alpn_chosen and #ja4sf.alpn_chosen >= 2 then
    alpn_chars = ja4sf.alpn_chosen:sub(1,2)
  elseif ja4sf.alpn_chosen and #ja4sf.alpn_chosen == 1 then
    alpn_chars = ja4sf.alpn_chosen .. "0"
  end

  local ja4s_a = string.format("t%s%02d%s", ver_str, ext_count, alpn_chars)
  local cipher_hex = string.format("%04x", ja4sf.cipher or 0)
  local ja4s_b = sha256_12(cipher_hex .. "_" .. sorted_hex_csv(ja4sf.extensions_raw))

  return ja4s_a .. "_" .. ja4s_b
end

local GUID = "{D8D4E3C2-AE5F-4B90-C7F6-234567890BCD}"

TrisulPlugin = {

  id = {
    name        = "ja4s hash",
    description = "JA4S TLS Server Hello fingerprint",
  },

  onload = function()
    local enabled = T.env.get_config("//Reassembly/TCPReassembly/Applications/EnableSSLRecordExtraction")
    if enabled:lower() ~= "true" then
      T.logerror("JA4S: needs EnableSSLRecordExtraction=TRUE. Cant proceed.")
      return false
    end
    T.ja4s_config = make_config(
      T.env.get_config("//App/DBRoot").."/config/trisulnsm_tls-fingerprint.lua",
      { LogHashes = false }
    )
  end,

  countergroup = {
    control = {
      guid        = "{D8D4E3C2-AE5F-4B90-C7F6-234567890BCD}",
      name        = "JA4S FINGERPRINT",
      description = "JA4S TLS Server Hello Fingerprint",
      bucketsize  = 60,
    },
    meters = {
      {0, T.K.vartype.COUNTER, 20, 40, "Hits",        "hits",     "hits"},
      {1, T.K.vartype.COUNTER, 20, 40, "Server Hits", "svr-hits", "hits"},
    },
  },

  reassembly_handler = {

    onattribute = function(engine, timestamp, flowkey, attr_name, attr_value)
      if attr_name ~= "TLS:RECORD" then return end

      local payload = SWP.new(attr_value)
      if payload:next_u8() ~= 22 then return end
      if not payload:skip(4) then return end
      if payload:next_u8() ~= 2 then return end  -- server hello only

      payload:reset()
      payload:inc(5)

      local ja4sf = {
        tls_version       = 0,
        supported_version = nil,
        cipher            = 0,
        extensions_raw    = {},
        alpn_chosen       = nil,
      }

      payload:next_u8()
      local hslen = payload:next_u24()
      if hslen ~= #attr_value - 9 then return end

      ja4sf.tls_version = payload:next_u16()
      payload:skip(32)
      payload:skip(payload:next_u8())

      -- server chosen cipher (single)
      local c = payload:next_u16()
      if not GREASE_tbl[c] then ja4sf.cipher = c end

      payload:skip(1) -- compression

      if not payload:has_more() then return end
      payload:push_fence(payload:next_u16())

      while payload:has_more() do
        local ext_type = payload:next_u16()
        local ext_len  = payload:next_u16()

        if ext_type == 16 then
          -- ALPN — server selects exactly one protocol
          local alpn_outer_len = payload:next_u16()
          payload:push_fence(alpn_outer_len)
          if payload:has_more() then
            local plen = payload:next_u8()
            ja4sf.alpn_chosen = payload:next_str_to_len(plen)
          end
          payload:pop_fence()

        elseif ext_type == 0x002b then
          -- supported_versions — server sends a single u16 (no length prefix)
          local sv = payload:next_u16()
          if not GREASE_tbl[sv] then ja4sf.supported_version = sv end

        else
          payload:skip(ext_len)
        end

        if not GREASE_tbl[ext_type] then
          ja4sf.extensions_raw[#ja4sf.extensions_raw+1] = ext_type
        end
      end

      local ja4s_str = build_ja4s(ja4sf)

      if T.ja4s_config.LogHashes then
        print(" flow="..flowkey:to_s().." JA4S="..ja4s_str)
      end

      engine:update_counter(GUID, ja4s_str, 0, 1)
      engine:update_counter(GUID, ja4s_str, 1, 1)
      engine:add_flow_edges(flowkey:id(), GUID, ja4s_str)
    end,

  },
}
