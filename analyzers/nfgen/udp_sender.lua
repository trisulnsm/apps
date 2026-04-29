local ffi = require("ffi")
local bit = require("bit")

ffi.cdef[[
typedef uint16_t sa_family_t;
typedef uint16_t in_port_t;
typedef uint32_t in_addr_t;
typedef uint32_t socklen_t;
typedef long ssize_t;

struct in_addr {
  in_addr_t s_addr;
};

struct sockaddr {
  sa_family_t sa_family;
  char sa_data[14];
};

struct sockaddr_in {
  sa_family_t sin_family;
  in_port_t sin_port;
  struct in_addr sin_addr;
  unsigned char sin_zero[8];
};

int socket(int domain, int type, int protocol);
int close(int fd);
ssize_t sendto(int sockfd, const void *buf, size_t len, int flags, const struct sockaddr *dest_addr, socklen_t addrlen);
uint32_t inet_addr(const char *cp);
char *strerror(int errnum);
]]

local constants = {
  AF_INET = 2,
  SOCK_DGRAM = 2,
}

local function strerror()
  return ffi.string(ffi.C.strerror(ffi.errno()))
end

local function htons(port)
  local p = tonumber(port) or 0
  p = bit.band(p, 0xFFFF)
  local lo = bit.band(p, 0x00FF)
  local hi = bit.rshift(bit.band(p, 0xFF00), 8)
  return bit.bor(bit.lshift(lo, 8), hi)
end

local UdpSender = {}
UdpSender.__index = UdpSender

function UdpSender.new(ip, port)
  local obj = setmetatable({}, UdpSender)
  obj.ip = tostring(ip or "127.0.0.1")
  obj.port = tonumber(port) or 2055
  obj.fd = ffi.C.socket(constants.AF_INET, constants.SOCK_DGRAM, 0)
  if obj.fd < 0 then
    T.logerror("nfgen: socket() failed " .. strerror())
    obj.fd = -1
    return obj
  end

  obj.addr = ffi.new("struct sockaddr_in")
  obj.addr.sin_family = constants.AF_INET
  obj.addr.sin_port = htons(obj.port)
  obj.addr.sin_addr.s_addr = ffi.C.inet_addr(obj.ip)
  if tonumber(obj.addr.sin_addr.s_addr) == 4294967295 then
    T.logerror("nfgen: invalid collector_ip " .. obj.ip)
    ffi.C.close(obj.fd)
    obj.fd = -1
  end

  return obj
end

function UdpSender:is_open()
  return self.fd ~= nil and self.fd >= 0
end

function UdpSender:send(payload)
  if not self:is_open() then
    return false
  end
  local bytes = tostring(payload or "")
  local ret = ffi.C.sendto(
    self.fd,
    bytes,
    #bytes,
    0,
    ffi.cast("const struct sockaddr *", self.addr),
    ffi.sizeof(self.addr)
  )
  if ret < 0 then
    T.logerror("nfgen: sendto() failed " .. strerror())
    return false
  end
  return true
end

function UdpSender:close()
  if self:is_open() then
    ffi.C.close(self.fd)
    self.fd = -1
  end
end

return UdpSender
