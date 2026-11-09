--
-- ja4common.lua
--
-- TYPE:        MODULE (no TrisulPlugin), shared by ja4hash.lua and ja4shash.lua
-- PURPOSE:     JA4 (ClientHello) and JA4S (ServerHello) per the FoxIO spec
--              https://github.com/FoxIO-LLC/ja4/blob/main/technical_details/JA4.md
--              reference implementation: FoxIO-LLC/ja4 python/ja4.py
--
-- Input to the parsers is one TLS record (5 byte record header + handshake),
-- as delivered in the TLS:RECORD flow attribute. The first handshake message
-- in the record must be the hello; other messages after it (TLS 1.2 servers
-- send ServerHello+Certificate+... in one record) are ignored.
--
-- Does not depend on T.*, so it can be unit tested outside Trisul.
--

local ffi = require('ffi')
local bit = require('bit')

local C
do
  local ok
  for _, lib in ipairs({'libcrypto.so', 'libcrypto.so.3', 'libcrypto.so.1.1', 'libcrypto.so.1.0.2k', 'libcrypto.so.1.0.0'}) do
    ok, C = pcall(function() return ffi.load(lib) end)
    if ok then break end
  end
  if not ok then error "Cant load FFI libcrypto version " end
end

pcall(ffi.cdef, [[
typedef struct sha256_state_st {
  unsigned int h[8];
  unsigned int Nl,Nh;
  unsigned int data[16];
  unsigned int num, md_len;
} SHA256_CTX;
int SHA256_Init(SHA256_CTX *c);
int SHA256_Update(SHA256_CTX *c, const void *data, size_t len);
int SHA256_Final(unsigned char *md, SHA256_CTX *c);
]])

local M = {}

-- sha256, lower case hex, first 12 chars (spec: "All sha256 functions must output in lower case")
local function sha256_12(input)
  local md  = ffi.new("uint8_t[32]")
  local ctx = ffi.new("SHA256_CTX")
  C.SHA256_Init(ctx)
  C.SHA256_Update(ctx, input, #input)
  C.SHA256_Final(md, ctx)
  local out = {}
  for i = 0, 5 do out[#out+1] = string.format("%02x", md[i]) end
  return table.concat(out)
end
M.sha256_12 = sha256_12

-- GREASE: 0x?A?A with both bytes equal (RFC 8701)
local function is_grease(v)
  return bit.band(v, 0x0f0f) == 0x0a0a and bit.rshift(v, 8) == bit.band(v, 0xff)
end
M.is_grease = is_grease

local TLS_VERSION_MAP = {
  [0x0304]="13", [0x0303]="12", [0x0302]="11", [0x0301]="10",
  [0x0300]="s3", [0x0002]="s2",
  [0xfeff]="d1", [0xfefd]="d2", [0xfefc]="d3",
}
local function version_str(v) return TLS_VERSION_MAP[v] or "00" end

local function hex4_csv(list, sorted)
  local copy = {}
  for i, v in ipairs(list) do copy[i] = v end
  if sorted then table.sort(copy) end
  local parts = {}
  for i, v in ipairs(copy) do parts[i] = string.format("%04x", v) end
  return table.concat(parts, ",")
end

-- ALPN: first and last char of the first ALPN value ("http/1.1" -> "h1").
-- "00" if absent/empty; a single char is used twice.
-- A non-ASCII first/last byte becomes '9'. This follows FoxIO's reference
-- implementations (rust tls.rs first_last, python ja4.py first_last_alpn),
-- which produce the public JA4 databases. JA4.md describes a hex rule that
-- those tools do not implement.
local function alpn_char(b)
  return b < 0x80 and string.char(b) or "9"
end
local function first_last_alpn(s)
  if s == nil or #s == 0 then return "00" end
  return alpn_char(s:byte(1)) .. alpn_char(s:byte(#s))
end
M.first_last_alpn = first_last_alpn

-- minimal bounds checked reader; every read returns nil past the end
local function reader(s, pos, limit)
  local r = { s = s, p = pos, lim = limit }
  function r:left()   return self.lim - self.p + 1 end
  function r:u8()     if self:left() < 1 then return nil end local v = self.s:byte(self.p); self.p = self.p + 1; return v end
  function r:u16()    if self:left() < 2 then return nil end local a, b = self.s:byte(self.p, self.p+1); self.p = self.p + 2; return a*256 + b end
  function r:u24()    if self:left() < 3 then return nil end local a, b, c = self.s:byte(self.p, self.p+2); self.p = self.p + 3; return (a*256 + b)*256 + c end
  function r:bytes(n) if n == nil or self:left() < n then return nil end local v = self.s:sub(self.p, self.p+n-1); self.p = self.p + n; return v end
  function r:skip(n)  if n == nil or self:left() < n then return false end self.p = self.p + n; return true end
  function r:sub(n)   if n == nil or self:left() < n then return nil end local c = reader(self.s, self.p, self.p+n-1); self.p = self.p + n; return c end
  return r
end

-- returns a reader over the hello body (after type+length) or nil
local function hello_body(record, want_type)
  local rec = reader(record, 1, #record)
  if rec:u8() ~= 22 then return nil end       -- handshake record
  if not rec:skip(2) then return nil end      -- record version
  local reclen = rec:u16()
  if not reclen then return nil end
  local hs = rec:sub(math.min(reclen, rec:left()))
  if not hs then return nil end
  if hs:u8() ~= want_type then return nil end
  local hslen = hs:u24()
  if not hslen or hslen > hs:left() then return nil end  -- hello must be complete in this record
  return hs:sub(hslen)
end

-- parse extensions block; calls fn(type, ext_reader) for each
local function each_extension(body, fn)
  if body:left() < 2 then return true end    -- no extensions
  local exts = body:sub(body:u16())
  if not exts then return false end
  while exts:left() >= 4 do
    local et = exts:u16()
    local el = exts:u16()
    local ex = exts:sub(el)
    if not ex then return false end
    fn(et, ex)
  end
  return true
end

local function first_alpn_value(ex)
  local list = ex:sub(ex:u16())
  if not list then return nil end
  local n = list:u8()
  if not n then return nil end
  return list:bytes(n)
end

-- JA4 from a ClientHello record, or nil (not a ClientHello / malformed)
-- also returns the SNI host name (or nil)
function M.ja4_from_record(record, proto)
  local body = hello_body(record, 1)
  if not body then return nil end

  local legacy_version = body:u16()
  if not legacy_version or not body:skip(32) then return nil end
  if not body:skip(body:u8()) then return nil end            -- session id

  local ciphers = {}
  local cs = body:sub(body:u16())
  if not cs then return nil end
  while cs:left() >= 2 do
    local v = cs:u16()
    if not is_grease(v) then ciphers[#ciphers+1] = v end
  end
  if not body:skip(body:u8()) then return nil end            -- compression

  local exts, sigalgs = {}, {}
  local sni, sni_present, alpn, best_sv = nil, false, nil, nil

  local ok = each_extension(body, function(et, ex)
    if is_grease(et) then return end
    exts[#exts+1] = et
    if et == 0x0000 then
      sni_present = true
      local list = ex:sub(ex:u16() or 0)
      if list and list:u8() == 0 then sni = list:bytes(list:u16()) end
    elseif et == 0x0010 then
      alpn = first_alpn_value(ex)
    elseif et == 0x000d then
      local sa = ex:sub(ex:u16())
      while sa and sa:left() >= 2 do
        local v = sa:u16()
        if not is_grease(v) then sigalgs[#sigalgs+1] = v end   -- original order
      end
    elseif et == 0x002b then
      local sv = ex:sub(ex:u8())
      while sv and sv:left() >= 2 do
        local v = sv:u16()
        if not is_grease(v) and (best_sv == nil or v > best_sv) then best_sv = v end
      end
    end
  end)
  if not ok then return nil end

  local ver = version_str(best_sv or legacy_version)

  local ja4_a = string.format("%s%s%s%02d%02d%s", proto or "t", ver, sni_present and "d" or "i",
                              math.min(#ciphers, 99), math.min(#exts, 99), first_last_alpn(alpn))

  local ja4_b = (#ciphers > 0) and sha256_12(hex4_csv(ciphers, true)) or "000000000000"

  local ext_c = {}
  for _, v in ipairs(exts) do
    if v ~= 0x0000 and v ~= 0x0010 then ext_c[#ext_c+1] = v end
  end
  local cstr = hex4_csv(ext_c, true)
  if #sigalgs > 0 then cstr = cstr .. "_" .. hex4_csv(sigalgs, false) end
  local ja4_c = (#ext_c > 0) and sha256_12(cstr) or "000000000000"

  return ja4_a .. "_" .. ja4_b .. "_" .. ja4_c, sni
end

-- JA4S from a ServerHello record, or nil
-- JA4S = {proto}{version}{ext count}{alpn}_{cipher}_{sha12(extensions in original order)}
function M.ja4s_from_record(record, proto)
  local body = hello_body(record, 2)
  if not body then return nil end

  local legacy_version = body:u16()
  if not legacy_version or not body:skip(32) then return nil end
  if not body:skip(body:u8()) then return nil end            -- session id
  local cipher = body:u16()
  if not cipher or not body:skip(1) then return nil end      -- compression

  local exts, alpn, sv = {}, nil, nil
  local ok = each_extension(body, function(et, ex)
    exts[#exts+1] = et                                       -- original order, as sent
    if et == 0x0010 then
      alpn = first_alpn_value(ex)
    elseif et == 0x002b then
      sv = ex:u16()                                          -- server sends one version
    end
  end)
  if not ok then return nil end

  local ja4s_a = string.format("%s%s%02d%s", proto or "t", version_str(sv or legacy_version),
                               math.min(#exts, 99), first_last_alpn(alpn))
  local ja4s_c = (#exts > 0) and sha256_12(hex4_csv(exts, false)) or "000000000000"

  return ja4s_a .. "_" .. string.format("%04x", cipher) .. "_" .. ja4s_c
end

return M
