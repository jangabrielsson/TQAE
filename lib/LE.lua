local _=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true, color=false },
--offline = true,
}

----------------------------------------
-- LE - Light Event Library
-- Documentation at https://forum.fibaro.com/topic/49113-hc3-quickapps-coding-tips-and-tricks/?do=findComment&comment=251398
-----------------------------------------

--%%name="My QA"
--%%type="com.fibaro.binarySwitch"
--%%quickVars={password="foo"}

function fibaro.lightEvents()
  local LE = { debug = true }
  local EVENT={}; LE.event = EVENT
  local function _debug(self,...) if self.debug then quickApp:debug(self._tag,...) end end
  local function _trace(self,...) quickApp:trace(self._tag,...) end
  local function _error(self,...) quickApp:error(self._tag,...) end
  local function _print(self,...) print(self._tag,...) end
  local function _post(self,event,sec)
    sec = sec or 0
    return setTimeout(function() 
        assert(EVENT[tostring(event.type)],"Undefined event ",tostring(event.type))
        self:debug("Event:",event.type)
        local stat,res = pcall(EVENT[event.type],self,event)
        if not stat then error(res) end
      end,1000*(sec >= os.time() and sec-os.time() or sec))
  end
  function LE:cancel(ref) clearTimeout(ref) end

  local function _send(self,event,method,path,data,opts)
    local url,args = (self.baseURL or "")..path,{}
    args.options = opts or {}
    args.options.headers = args.options.headers or {}
    args.options.headers['content-type']=args.options.headers['content-type'] or "application/json"
    args.options.headers['Accept']=args.options.headers['Accept'] or "application/json"
    args.options.method = method or "GET"
    args.options.data = data and json.encode(data) or nil
    local cont = type(event)=='table' and event.type or tostring(event)
    function args.success(resp)
      if resp.status <= 204 then
        self:debug("success ",url,resp.data:sub(1,10))
        local stat,res = pcall(json.decode,resp.data)
        self:post({type=cont.."_success",url=url,data=stat and res or resp.data})
      else
        self:post({type=cont.."_error",url=url,error="status="..resp.status})
      end
    end
    function args.error(err) self:post({type=event.type.."_error",url=url,error=err}) end 
    return net.HTTPClient():request(url,args)
  end
  LE._send = _send
  function LE:post(event,sec,ctx)
    ctx=ctx or {}
    ctx.post,ctx.debug,ctx.trace,ctx.print,ctx.error,ctx.http,ctx._tag=_post,_debug,_trace,_print,_error,LE._send,ctx._tag or ""
    _post(ctx,event,sec) 
  end
  return LE
end

----------------------------------------------------
-- Example
-----------------------------------------------------

--local LE = fibaro.lightEvents()
--if true then -- redefine send for test purpose when no access to remote server
--  local resps={ login={{value={token={name="myToken"}}}}, value={{value={enable=0}}} } -- Fixed responses
--  function LE._send(self,event,method,path,_) -- ignore data, we make our own response
--    local url,resp = (self.baseURL or "")..path,{}
--    for t,d in pairs(resps) do if path:match(t) then resp=d break end end
--    self:debug("success ",url,json.encode(resp))
--    self:post({type=event.type.."_success",url=url,data=resp})
--  end
--end
--EVENT = LE.event

--function EVENT:test1(event)
--  self:post({type='test2',a=event.a+1},event.a)
--end

--function EVENT:test2(event)
--  self:post({type='test3',a=event.a+1},event.a)
--end

local funs={}
funs['=='] = function(val) return function(x) return x==val end end
funs['>'] = function(val) return function(x) return x>val end end
funs['>='] = function(val) return function(x) return x>=val end end
funs['<'] = function(val) return function(x) return x<val end end
funs['<='] = function(val) return function(x) return x<=val end end
funs['~='] = function(val) return function(x) return x~=val end end

local function parse(str)
  local a = str:split("&")
  local e = map(a,function(o) 
      local es = o:split("|") 
      return map(es,function(e)
        end)
    end)

end

--function EVENT:test3(event)
--  self:dispatch("device_%2_%1",event.id,">30",event.value,"==value")
--  self:print(event.a)
--end

--function QuickApp:onInit()
--  self:debug(self.name, self.id)
--  LE:post({type='test1',a=1})
--  LE:post({type='test1',a=2})
--  LE:post({type='test1',a=3})
--end

--function EVENT:test1(event)
--  self.b=self.b+1
--  self:post({type='test2',a=event.a+1})
--end

--function EVENT:test2(event)
--  self.b=self.b+1
--  self:post({type='test3',a=event.a+1})
--end

--function EVENT:test3(event)
--  self:print(event.a,self.b)
--end

--function QuickApp:onInit()
--  self:debug(self.name, self.id)
--  LE:post({type='test1',a=9},0,{b=8,_tag="A1"})
--  LE:post({type='test1',a=10},0,{b=6,_tag="A2"})
--  LE:post({type='test1',a=12},0,{b=5,_tag="A3"})
--end

------

--function EVENT:getValue(event)
--  self:http(event,"GET","valueGet&name='X'")
--end
--function EVENT:getValue_success(event)
--  self:debug("Enable:",event.data[1].value.enable)
--end
--function EVENT:getValue_error(event)
--  self:error(event.error)
--end

--function QuickApp:onInit()
--  self:debug(self.name, self.id)
--  local pwd = self:getVariable("password")
--  LE:post({type='getValue'},0,{pwd=pwd,baseURL="http://myservices?cmd="})
--end

------

--function EVENT:getValue(event)
--  if not self.token then
--      self.nextStep = 'getValue'
--      self:post({type='login'})
--  else 
--    self:http(event,"GET","valueGet&name=X&token="..self.token)
--  end
--end
--function EVENT:getValue_success(event)
--  self:debug("Enable:",event.data[1].value.enable)
--end
--function EVENT:getValue_error(event)
--  self:error(event.error)
--end
--function EVENT:login(event)
--  self:http(event,"GET","login&pwd="..self.pwd)
--end
--function EVENT:login_success(event)
--  self:debug("Logged in")
--  self.token = event.data[1].value.token.name
--  self:post({type=self.nextStep})
--end
--function EVENT:login_error(event)
--  self:eror(event.error)
--end

--function QuickApp:onInit()
--  self:debug(self.name, self.id)
--  local pwd = self:getVariable("password")
--  LE:post({type='getValue'},0,{pwd=pwd,baseURL="http://myservices?cmd="})
--end


