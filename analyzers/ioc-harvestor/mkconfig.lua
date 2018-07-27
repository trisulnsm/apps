function file_exists(name)
  local f=io.open(name,"r")
  if f~=nil then io.close(f) return true else return false end
end


function  make_config( custom_config_file, default_config_table)

    -- load custom config if present 
	local active_config = default_config_table

    if file_exists(custom_config_file) then 
      local newsettings = dofile(custom_config_file) 
      T.loginfo("Loading custom settings from ".. custom_config_file)
      for k,v in pairs(newsettings) do 
        active_config[k]=v
        T.loginfo("Loaded new setting "..k.."="..tostring(v))
      end
    else 
      T.loginfo("Loaded default settings")
    end

	return active_config

end 

