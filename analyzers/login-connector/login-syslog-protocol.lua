--
-- SYSLOG  (login-connector)
--
TrisulPlugin = {


  -- the ID block, you can skip the fields marked 'optional '
  --
  id =  {
    name = "LOGIN_SYSLOG",
    description = "Login syslog protocol udp 514",
  },


  -- protocol_handler  block
  --
  protocol_handler  = {

  -- new protocol for login syslog
  control = {
    guid  = "{EDCD967A-CEF8-4A21-8D98-1A435A6CD55A}",
    name  = "LOGIN_SYSLOG",
    host_protocol_guid = '{14D7AB53-CC51-47e9-8814-9C06AAE60189}',
    host_protocol_ports = { 514 }
  },


  -- WHEN CALLED: when lower layer is constructed and
  -- return  ( nEaten, nextProtID)
  parselayer = function(layer)


      return layer:layer_bytes(),nil
  end,


  },
}
