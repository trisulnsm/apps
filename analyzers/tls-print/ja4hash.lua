--
-- ja4hash.lua
--
-- TYPE: FRONTEND SCRIPT
-- PURPOSE: JA4 TLS fingerprint (client hello only)
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

-- JA4 = {ja4_a}_{ja4_b}_{ja4_c}
-- ja4_a : t + version(2) + sni(d/i) + cipher_count(2) + ext_count(2) + alpn_first(2)
-- ja4_b : SHA256[:12]( sorted cipher hex csv )
-- ja4_c : SHA256[:12]( sorted ext csv, SNI+ALPN removed + "_" + sorted sig_algs )
-- Ref: https://github.com/FoxIO-LLC/ja4/blob/main/technical_details/JA4.md
local function build_ja4(ja4f)
  local ver_str = TLS_VERSION_MAP[ja4f.tls_version] or "00"
  if ja4f.supported_version and TLS_VERSION_MAP[ja4f.supported_version] then
    ver_str = TLS_VERSION_MAP[ja4f.supported_version]
  end

  local sni_char     = ja4f.sni_present and "d" or "i"
  local cipher_count = math.min(#ja4f.ciphers, 99)
  local ext_count    = math.min(#ja4f.extensions_raw, 99)

  local alpn_chars = "00"
  if ja4f.alpn_first and #ja4f.alpn_first >= 2 then
    alpn_chars = ja4f.alpn_first:sub(1,2)
  elseif ja4f.alpn_first and #ja4f.alpn_first == 1 then
    alpn_chars = ja4f.alpn_first .. "0"
  end

  local ja4_a = string.format("t%s%s%02d%02d%s", ver_str, sni_char, cipher_count, ext_count, alpn_chars)
  local ja4_b = sha256_12(sorted_hex_csv(ja4f.ciphers))

  local ext_for_hash = {}
  for _, v in ipairs(ja4f.extensions_raw) do
    if v ~= 0 and v ~= 16 then ext_for_hash[#ext_for_hash+1] = v end
  end
  local exts_csv = sorted_hex_csv(ext_for_hash)
  local ja4_c
  if ja4f.sig_algs and #ja4f.sig_algs > 0 then
    ja4_c = sha256_12(exts_csv .. "_" .. sorted_hex_csv(ja4f.sig_algs))
  else
    ja4_c = sha256_12(exts_csv)
  end

  return ja4_a .. "_" .. ja4_b .. "_" .. ja4_c
end

TrisulPlugin = {

  id = {
    name        = "ja4 hash",
    description = "JA4 TLS Client Hello fingerprint",
  },

  onload = function()
    local enabled = T.env.get_config("//Reassembly/TCPReassembly/Applications/EnableSSLRecordExtraction")
    if enabled:lower() ~= "true" then
      T.logerror("JA4: needs EnableSSLRecordExtraction=TRUE. Cant proceed.")
      return false
    end
    T.ja4_config = make_config(
      T.env.get_config("//App/DBRoot").."/config/trisulnsm_tls-fingerprint.lua",
      { LogHashes = false }
    )
  end,

  countergroup = {
    control = {
      guid        = "{D7C3F2B1-9D4E-4A8F-B6E5-123456789ABD}",
      name        = "JA4 FINGERPRINT",
      description = "JA4 TLS Client Hello Fingerprint",
      bucketsize  = 60,
    },
    meters = {
      {0, T.K.vartype.COUNTER, 20, 40, "Hits",        "hits",     "hits"},
      {1, T.K.vartype.COUNTER, 20, 40, "Client Hits", "clt-hits", "hits"},
    },
  },

  reassembly_handler = {

    onattribute = function(engine, timestamp, flowkey, attr_name, attr_value)
      if attr_name ~= "TLS:RECORD" then return end

      local payload = SWP.new(attr_value)
      if payload:next_u8() ~= 22 then return end
      if not payload:skip(4) then return end
      if payload:next_u8() ~= 1 then return end  -- client hello only

      payload:reset()
      payload:inc(5)

      local ja4f = {
        tls_version       = 0,
        supported_version = nil,
        sni_present       = false,
        ciphers           = {},
        extensions_raw    = {},
        sig_algs          = {},
        alpn_first        = nil,
      }

      payload:next_u8()
      local hslen = payload:next_u24()
      if hslen ~= #attr_value - 9 then return end

      ja4f.tls_version = payload:next_u16()
      payload:skip(32)
      payload:skip(payload:next_u8())

      -- ciphers
      local raw_ciphers = payload:next_u16_arr(payload:next_u16() / 2)
      for _, v in ipairs(raw_ciphers) do
        if not GREASE_tbl[v] then ja4f.ciphers[#ja4f.ciphers+1] = v end
      end

      payload:skip(payload:next_u8()) -- compression

      if not payload:has_more() then return end
      payload:push_fence(payload:next_u16())

      local snihostname = nil

      while payload:has_more() do
        local ext_type = payload:next_u16()
        local ext_len  = payload:next_u16()

        if ext_type == 0 and ext_len > 0 then
          -- SNI
          payload:push_fence(payload:next_u16())
          while payload:has_more() do
            payload:skip(1)
            snihostname = payload:next_str_to_len(payload:next_u16())
          end
          payload:pop_fence()
          ja4f.sni_present = true

        elseif ext_type == 13 then
          -- signature_algorithms
          local sa_arr = payload:next_u16_arr(payload:next_u16() / 2)
          for _, v in ipairs(sa_arr) do
            if not GREASE_tbl[v] then ja4f.sig_algs[#ja4f.sig_algs+1] = v end
          end

        elseif ext_type == 16 then
          -- ALPN
          local alpn_outer_len = payload:next_u16()
          payload:push_fence(alpn_outer_len)
          if payload:has_more() then
            local plen = payload:next_u8()
            ja4f.alpn_first = payload:next_str_to_len(plen)
            while payload:has_more() do payload:skip(payload:next_u8()) end
          end
          payload:pop_fence()

        elseif ext_type == 0x002b then
          -- supported_versions
          local sv_arr = payload:next_u16_arr(payload:next_u8() / 2)
          local best = 0
          for _, v in ipairs(sv_arr) do
            if not GREASE_tbl[v] and v > best then best = v end
          end
          if best > 0 then ja4f.supported_version = best end

        else
          payload:skip(ext_len)
        end

        if not GREASE_tbl[ext_type] then
          ja4f.extensions_raw[#ja4f.extensions_raw+1] = ext_type
        end
      end

      local ja4_str = build_ja4(ja4f)

      if T.ja4_config.LogHashes then
        print(" flow="..flowkey:to_s().." JA4="..ja4_str)
      end

      engine:update_counter('{D7C3F2B1-9D4E-4A8F-B6E5-123456789ABD}', ja4_str, 0, 1)
      engine:update_counter('{D7C3F2B1-9D4E-4A8F-B6E5-123456789ABD}', ja4_str, 1, 1)
      engine:add_flow_edges(flowkey:id(), '{D7C3F2B1-9D4E-4A8F-B6E5-123456789ABD}', ja4_str)

      if snihostname then
        engine:add_edge('{D7C3F2B1-9D4E-4A8F-B6E5-123456789ABD}', ja4_str,
          '{B91A8AD4-C6B6-4FBC-E862-FF94BC204A35}', snihostname)
      end
    end,

  },
}
