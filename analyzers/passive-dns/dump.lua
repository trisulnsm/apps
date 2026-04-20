-- just a simple test script to dump the entire levelDB to stdout
-- this is not part of the framework, just a helper 

local LevelDB=require'tris_leveldb'
local default_db_name = "PassiveDNSDB.level"
local db_path = (arg and arg[1]) or
  ("/usr/local/var/lib/trisul-probe/domain0/probe0/context0/config/" .. default_db_name)

db1=LevelDB.new()
db1:open(db_path)
db1:dump()
db1:close()
