-- Intel_tester
--
-- TYPE:        BACKEND SCRIPT
-- PURPOSE:     Dumps the Intel IOC harvested by the various poitns in stream 
-- 
-- This is Just a STUB tester does nothing other than print the intel items  
-- 
require'mkconfig' 

TrisulPlugin = { 

  -- id block
  --
  id =  {
    name = "Intel Harvest Tester",
    description = "Dump the INTEL to stdout", 
  },

  onload = function()

    -- load custom config if present 
    T.active_config = make_config(
      T.env.get_config("App>DBRoot").."/config/trisulnsm_ioc-harvestor.lua",
      {
        -- Save these to backend DB (can take up significant disk space) 
        -- in production override this to false  in 
        -- /usr/local/var/lib/trisul-probe/d0/p0/cX/config/trisulnsm_ioc-harvestor.lua config file 
        SaveHarvestedItems=false,
        IOCFile=nil,
      } )

      T.ioc_table = { } 
      if T.active_config.IOCFile then
        local f,err  = io.open( T.active_config.IOCFile) 
        if not f  then
          T.logerror( "Unable to open IOC file err="..err.. " f=" ..  T.active_config.IOCFile) 
        else 
          local nitems=0
          for l in f:lines() do
            T.ioc_table[ l ] = true
            nitems=nitems+1 
          end
          T.loginfo("Loaded IOC items count=".. nitems)
          f:close() 
        end
      end 
  end,

  -- dont store the Intel harvested in backend, save space msems
  resource_monitor  = {

    resource_guid = '{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}', 

    -- WHEN CALLED : a new resource is seen (immediately)
    onnewresource  = function(engine, resource )

      local match = T.ioc_table[ resource:label() ] 
      if match then
        engine:add_alert("{B5F1DECB-51D5-4395-B71B-6FA730B772D9}", -- user alerts : group
             resource:flow():id(),
             "IOC-TESTER",
             1,
             "found a IOC hit ".. resource:uri() .. " hit " .. resource:label()  )
      end 
    end,

  -- 
  -- do you want to save these Harvested resources on the Hub
  -- 
    flushfilter = function(engine, resource) 
      return T.active_config.SaveHarvestedItems 
    end,

  },
}

