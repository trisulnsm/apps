-- save_exe_prod.lua
--
-- *production version of save_exe.lua, higher performance*
--
-- uses LuaJIT FFI instead of naive version used in save_exe.lua
--
-- Saves all Executable files using the magic number method
-- 
-- Config params            Defaults
-- ---------------          --------
-- OutputDirectory          /tmp/savedfiles
-- Magic Regex              (shockwave|msdownload|dosexec|pdf|macro) to save common malware files
--                          SWF,PDF,MSI,EXE etc
--
local ffi=require('ffi')
local C = ffi.load('libmagic.so.1')

ffi.cdef[[
  static const int MAGIC_NONE=0x000000;
  static const int MAGIC_DEBUG=0x000001;
  typedef void * magic_t;
  magic_t magic_open(int k);
  const char *magic_error(magic_t);
  const char *magic_file(magic_t, const char *);
  int magic_load(magic_t, const char *);
]]


function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end
-- --------------------------------------------
-- override by trisul_apps_save_exe.config.lua 
-- in probe config directory /usr/local/var/lib/trisul-probe/dX/pX/contextX/config 
--
DEFAULT_CONFIG = {
	-- where do you want the extracted files to go
	OutputDirectory="/tmp/savedfiles",

	-- the strings returned by libmagic you want to save
	Regex="(?i)(msdos|ms-dos|microsoft|windows|elf|executable|pdf|flash|macro)"
}
-- --------------------------------------------


-- plugin starts 
-- 
TrisulPlugin = {

  id = {
    name = "Save EXE,PDF,etc",
    description = "Extract MSI,EXE, using magic numbers",
    author = "Unleash",
    version_major = 1,
    version_minor = 0,
  },


  -- make sure the output directory is present 
  onload = function()

	-- load custom config if present 
	local custom_config_file = T.env.get_config("App>DBRoot").."/config/trisulnsm_save_exe.config.lua"
	if file_exists(custom_config_file) then 
		T.active_config = require(custom_config_file) 
	else 
		T.active_config = DEFAULT_CONFIG
	end


  	T.magic_handle=C.magic_open(C.MAGIC_NONE);
	if T.magic_handle == nil then
		T.logerror("Error opening magic handle")
		return false
	end
	if C.magic_load(T.magic_handle,nil) == nil then
	  T.logerror("magic_load(..) error="..ffi.string(C.magic_error(T.magic_handle)) )
	  return false
	end

    os.execute("mkdir -p "..T.active_config.OutputDirectory)
	T.trigger_patterns = T.re2(T.active_config.Regex)
	T.savechunks={}
  end,

  -- Table filex_monitor contains functions in this module 
  filex_monitor  = {


    -- save all content to /tmp/savedfiles  
	-- then check magic number using `file ..` if it matches microsoft pull it out 
    --
    onfile_http  = function ( engine, timestamp, flow, path, req_header, resp_header, length , is_chunk )

      -- you can get 0 length for HTTP 304, etc - skip it (or log it in other ways etc)
      if length == 0 then return; end 

	  -- get magic number 
	  local val_c = C.magic_file( T.magic_handle, path)
	  if val_c== nil then
		  T.logerror("magic_file(..) error="..ffi.string(C.magic_error(T.magic_handle)) )
		  return
	  end 

	  local magic_filetype=ffi.string(val_c)

	  -- 
	  if T.trigger_patterns:partial_match(magic_filetype) then 
		  T.savechunks[flow:id()]=true 
	  elseif not is_chunk then 
		  T.savechunks[flow:id()]=false 
	  end 
	  	

	  -- does this trigger our RE2 pattern 
	  if T.savechunks[flow:id()]  then 

		  if is_chunk then 
			   local fn,off = path:match("^.+/(.+)%.%d+.part$")
			   --  just a chunk , concatenate with prev 
			   --
			   T.async:cat( path, T.active_config.OutputDirectory.."/"..fn)
		  else
			   -- full file 
			   --
			   local fn = path:match("^.+/(.+)$")
			   T.async:copy( path, T.async.OutputDirectory.."/"..fn)
		  end 

	  end 

	end,


	-- flow terminated ; clean up 
	onterminateflow = function(engine, ts, flow)
		T.savechunks[flow:id()]=nil 
	end,
 }
}

