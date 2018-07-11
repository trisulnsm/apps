--
-- counter_monitor.lua skeleton
--
-- harvest Hosts IPv6 : big trick here is to translate from Trisul Format to Readable Intel format 
-- 
local ffi=require'ffi'

ffi.cdef [[
    typedef uint32_t  socklen_t;
    const   char *inet_ntop(int af, const void *src, char *dst, socklen_t size);
    static  const int AF_INET6=10;  
]]

function bin_to_ip6(bin16)
    local outarr = ffi.new(' char  [64]') 
    local s = ffi.C.inet_ntop(ffi.C.AF_INET6, bin16, outarr, 64);
    return ffi.string(s) 
end

TrisulPlugin = { 

  -- id block 
  id =  {
    name = "Hosts IPv6 ",
    description = "Hosts IPv6",   -- optional
  },

  cg_monitor  = {

    counter_guid = "{9807E97A-6CD2-442F-BB18-8C104C8EB204}",

    onnewkey = function(engine, timestamp, key)
        
        local binarr=key:gsub("(%x%x)",function(s) return string.char(tonumber(s, 16)) end)
        local readable6 = bin_to_ip6(binarr) 

        engine:add_resource('{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}',
            "06A:00.00.00.00:p-0000_00.00.00.00:p-0000",
            "INDICATOR:HOSTv6", 
            readable6);
        
    end,
  },
}

