--
-- INTEL Resource
--   various plugins harvest intel and stream these resources 
-- 
TrisulPlugin = { 

  -- the ID block, you can skip the fields marked 'optional '
  -- 
  id =  {
    name = "Intel harvested",
    description = "Harvested intel", -- optional
  },

  -- resourcegroup  block
  -- 
  resourcegroup  = {

    -- table control 
    -- WHEN CALLED: specify details of your new resource  group
    --              you can use 'trisulctl_probe testbench guid' to get a new GUID
    control = {
      guid = "{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}",
      name = "Intel harvested",
      description = "Indicators harvested from various points in pipeline",
    },

  },
}
