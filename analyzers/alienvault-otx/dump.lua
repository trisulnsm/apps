-- Just dumps the Trisul Intel DB to stdout 
-- this is not part of the framework, just a helper 

local LevelDB=require'tris_leveldb'
db1=LevelDB.new()
db1:open("/usr/local/share/trisul-probe/plugins/trisul-intel.leveldb.0") 
db1:dump()
db1:close()

