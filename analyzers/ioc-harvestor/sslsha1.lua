--
-- resource_monitor.lua skeleton
--    harvests SSL Certificates SHA1 
-- 
TrisulPlugin = { 

  -- id block
  --
  id =  {
    name = "SSL Cert SHA1",
    description = "Harvest SHA1 prints", 
  },

  resource_monitor  = {

    resource_guid = '{5AEE3F0B-9304-44BE-BBD0-0467052CF468}', 

    -- put out SHA1 of cert 
    onflush = function(engine, resource) 

      local _,_,sha1 = resource:uri():find("SHA1:(%x+)%s")

      engine:add_resource('{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}',
                          resource:flow():id(),
                          "INDICATOR:CERTSHA1", 
                          sha1)

    end,
  },


}
