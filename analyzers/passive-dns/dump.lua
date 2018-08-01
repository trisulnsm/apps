-- just a simple test script to dump the entire levelDB to stdout
-- this is not part of the framework, just a helper 

local LevelDB=require'tris_leveldb'
db1=LevelDB.new()
db1:open("/usr/local/var/lib/trisul-probe/domain0/probe0/context0/config/PassiveDNSDB.level")
db1:dump()
db1:close()
