-- api.lua 
-- 
-- allows you to query the live LevelDB database  (for testing and offline purposes) 
-- 
-- 2 commands  supported 
--     listprefix<space>prefix
--     dumpall 


local ffi=require'ffi'
local API_SOCKETFILE_NAME='leveldbapi.sock'
local leveldb=require'tris_leveldb'

-- need to do this mapping .. :-(
-- takes time to get used to LuaJIT FFI but quite easy once you get the 
-- hang of it 
ffi.cdef[[

typedef int   ssize_t;
typedef uint16_t sa_family_t;
typedef uint32_t socklen_t;

struct constants {
    static const int AF_UNIX=1;
    static const int AF_INET=2;
    static const int SOCK_STREAM=1;          /* socket.h        */
    static const int SOCK_DGRAM=2;          /* socket.h        */
    static const int MSG_DONTWAIT=0x40;     /* socket_type.h   */
    static const int SOCK_NONBLOCK=2048;     /* socket_type.h   */
    static const int EAGAIN=11;     /* asm../errno.h */
};

int     socket(int domain, int type, int protocol);

struct sockaddr {
    sa_family_t sa_family;          
    char        sa_data[14];       
};

struct sockaddr_un {
    sa_family_t   sun_family;      
    uint8_t  sun_path[108];  
};

int bind(int socket, const struct sockaddr *, socklen_t addrlen) ;
ssize_t recv(int socket, void * buf, size_t buflen, int flags);
ssize_t send(int sockfd, const void *buf, size_t len, int flags);
int listen(int sockfd, int backlog);
int accept4(int sockfd, struct sockaddr *addr, socklen_t *addrlen, int flags);  
char * strerror(int errno);
int unlink(char * pathname);
int close(int fd);
]] 


strerror = function()
  return ffi.string(ffi.C.strerror( ffi.errno() ))
end

K = ffi.new("struct constants");

TrisulPlugin = {

  id = {
    name = "Trisul-API-Unixsocket",
    description = "Add metrics, alerts, metadata to Trisul by sending strings to a Unix socket",
  },

  -- All those interested in plugging into PDNS listen tothis message and
  -- get a handle to the LevelDB database.  The owner of handle skips it  
  onmessage=function(msgid, msg)
    if msgid=='{4349BFA4-536C-4310-C25E-E7C997B92244}' then
      local dbaddr = msg:match("newleveldb=(%S+)")
      if not T.LevelDB then 
        T.LevelDB = leveldb.new() 
        T.LevelDB:fromaddr(dbaddr);
      end
    end
  end,


  -- returning false from onload will effectively stop the script itself
  -- 
  onload = function()
    T.socket = nil 
  end,


  -- opens a unix socket 
  open_api_socket = function(socket_path ) 

    T.log(T.K.loglevel.INFO, "API Socket setting up the socket : ".. socket_path)

    -- socket 
    local socket = ffi.C.socket( K.AF_UNIX, K.SOCK_STREAM, 0 );
    if  socket == -1 then 
      T.logerror("Error socket() " .. strerror())
      return  false 
    end 

    -- bind to unix socket endpoint
    local addr = ffi.new("struct sockaddr_un");
    addr.sun_family = K.AF_UNIX;
    addr.sun_path = socket_path
    ffi.C.unlink(addr.sun_path);
    local ret = ffi.C.bind( socket,  ffi.cast("const struct sockaddr *", addr) , ffi.sizeof(addr));
    if ret == -1 then
        T.logerror("Error bind() " .. strerror())
        return false
    end

    local ret=ffi.C.listen( socket, 2);
    if ret == -1 then
        T.logerror("Error listen() " .. strerror())
        return false
    end

    T.socket = socket
    T.MAX_MSG_SIZE=64000;
    T.rbuf  = ffi.new("char[?]", T.MAX_MSG_SIZE);
    return true
   end,


  -- engine_monitor block
  --
  engine_monitor  = {

    -- non blocking check for a command every 1 sec
    onmetronome  = function(engine, timestamp, tick_count, tick_interval  )

      -- if you dont have a LevelDB handle, dont bother
      if not T.LevelDB then return end

      -- lazy open of socket
      if T.socket ==nil then 
        local api_socket_filename = T.env.get_config("App>RunStateDirectory").."/"..API_SOCKETFILE_NAME .."."..engine:instanceid() 
        if  not TrisulPlugin.open_api_socket( api_socket_filename) then
          return false
        end 
      end 


      -- this block is repeated  until 
       -- 1. EOF on socket 

      local sock = ffi.C.accept4( T.socket,  nil, nil, K.SOCK_NONBLOCK);
      if sock < 0 then 
        if ffi.errno() ~= K.EAGAIN then 
          T.logerror("Error in accept4: "..strerror())
        end
        return
      end 
    
      T.loginfo("API socket connected, about to read a command")

      local ret = ffi.C.recv(sock, T.rbuf,T.MAX_MSG_SIZE,0)
      if ret < 0 then
        if ffi.errno() ~=  K.EAGAIN then 
          T.logerror("Error ffi.recv " .. strerror())
        end 
        return
      end

      local cmd_string  = ffi.string(T.rbuf, ret)
      TrisulPlugin.dispatch_cmd( sock, timestamp, cmd_string)
      ffi.C.close(sock)

    end

  },

  -- cmd string - split by new line 
  dispatch_cmd = function(wsock, timestamp, cmd_string)

    local args = {}
    for token in cmd_string:gmatch("[^%s]+") do
       args[#args+1]=token
    end

    print(cmd_string)

    if args[1] =="listprefix" then 

      T.loginfo("LevelDB listprefix request ----Dumping----")
      local iter=T.LevelDB:create_iterator(tbl)
      iter:seek_to(args[2])
      while iter:valid() do
        local k,v = iter:key_value()
	if k:match(args[2]) ~= 0  then 
		break
	end 
        local outstr=k.."="..v.."\n"
        ffi.C.send(wsock,outstr,#outstr,0)
        iter:iter_next()
      end
      iter:destroy()

      local ret = ffi.C.send(wsock, "pr-listprefix",10,0)
      if  ret == -1 then 
          T.logerror("Error send() " .. strerror())
          return  false 
      end 

    elseif args[1] == "dump" then 
      T.loginfo("LevelDB dump requested via API  ----Dumping----")
      local iter=T.LevelDB:create_iterator(tbl)
      iter:seek_to_first()
      while iter:valid() do
        local k,v = iter:key_value()
        local outstr=k.."="..v.."\n"
        ffi.C.send(wsock,outstr,#outstr,0)
        iter:iter_next()
      end
      iter:destroy()
    else
      local ret = ffi.C.send(wsock, "unsupported",10,0)
    end

  end,

}
