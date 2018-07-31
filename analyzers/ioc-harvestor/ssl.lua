--
-- fts_monitor.lua skeleton
-- Extracts CN,  list of SAN  names 
-- 
TrisulPlugin = { 

  -- id block
  -- 
  id =  {
    name = "SSL FTS Harvestor",
    description = "harvest from SAN/CNAME",
  },

  -- Hook to SSL Certs FTS Stream (Full Text Search Document)
  --
  fts_monitor  = {

    fts_guid = '{9FEB8ADE-ADBB-49AD-BC68-C6A02F389C71}',

    onflush = function(engine, fts) 

      local text = fts:text()

      -- CN
      local _,_,cn= text:find("CN=([%w%.-]+)")
      engine:add_resource('{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}',
                          fts:flow():id(),
                          "INDICATOR:SSLCN", 
                          cn) 

      -- SAN  records 
      for san in  text:gmatch("DNS:([%w%.%-]+)") do
        engine:add_resource('{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}',
                            fts:flow():id(),
                            "INDICATOR:SAN", 
                            san) 
      end 
    end,
  },
}
