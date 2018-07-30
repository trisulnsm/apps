-- resource_monitor.lua skeleton
--
--  harvests Binary file hashes - Needs the "Save Binaries" app  
--
TrisulPlugin = { 

  id =  {
    name = "Binary files harvest",
    description = "Hashes of binary files", 
  },

  resource_monitor  = {

    resource_guid = '{9781DB2C-F78A-4F7F-A7E8-2B1A9A7BE71A}', 

    -- Pull out file hashes 
    onflush = function(engine, resource) 
    engine:add_resource('{EE1C9F46-0542-4A7E-4C6A-55E2C4689419}',
                        resource:flow():id(),
                        "INDICATOR:FILEHASH", 
                        resource:uri());
    end,
  },
}
