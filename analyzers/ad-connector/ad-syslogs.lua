--
-- new_resource_group.lua skeleton
-- {E3EF6B1A-6553-4474-69B6-D015CEF3D41F}
-- DEFINE_GUID(GUID_xxx,0xE3EF6B1A,0x6553,0x4474,0x69,0xB6,0xD0,0x15,0xCE,0xF3,0xD4,0x1F);
-- 
TrisulPlugin = { 

  id =  {
    name = "AD Syslogs",
    description = "AD syslogs for logon and logoff only", 
  },


  -- resourcegroup  block
  -- 
  resourcegroup  = {

    -- table control 
    -- WHEN CALLED: specify details of your new resource  group
    --              you can use 'trisulctl_probe testbench guid' to get a new GUID
    control = {
      guid = "{E3EF6B1A-6553-4474-69B6-D015CEF3D41F}",
      name = "AD Syslogs",
      description = "Raw AD login/logoff text syslogs",
    },

  },
}
