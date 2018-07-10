-- fts_monitor.lua skeleton
-- Extracts URL and HTTP-Host and HTTP-Referer for INTEL 
-- 
TrisulPlugin = { 

  -- id block
  id =  {
    name = "HTTP Harvestor",
    description = "harvest from HTTP headers",
  },

  -- load up AC matcher regex 
  onload = function() 
    T.achit   = T.ac( {'Host', 'Referer', 'User-Agent' } )
    T.re2line = T.re2( "(GET|POST|PUT|PATCH|DELETE|HEAD)\\s+([^?\\s]+)")
  end, 

  fts_monitor  = {

    fts_guid = '{28217924-E7A5-4523-993C-44B52758D5A8}',

    onflush = function(engine, fts) 

        local text = fts:text()

        local matched, method, uri = T.re2line:partial_match_c2(text)
        if not matched then return end

        local m = T.achit:match_all( text)
        for k,v in pairs(m) do
            if k=="Host" then
                local _,_,host = text:find("%s*:%s*(%S+)",v)
                engine:add_resource('{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}',
                    fts:flow():id(),
                    "INDICATOR:HTTPURI",
                    host..uri)
                engine:add_resource('{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}',
                    fts:flow():id(),
                    "INDICATOR:HTTPHOST",
                    host)
            elseif  k=="User-Agent" then
                local _,_,ua = text:find("%s*:%s*(%S+)",v)
                engine:add_resource('{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}',
                    fts:flow():id(),
                    "INDICATOR:HTTPUA",
                    ua)
            elseif k=="Referer" then
                local _,_,referer = text:find("%s*:%s*([^%?%s]+)",v)
                engine:add_resource('{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}',
                    fts:flow():id(),
                    "INDICATOR:HTTPREFERER",
                    referer)
            end
        end
    end,
  },
}
