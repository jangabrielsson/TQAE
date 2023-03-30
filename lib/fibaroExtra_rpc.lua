_MODULES = _MODULES or {} -- Global
_MODULES.rpc={ author = "jan@gabrielsson.com", version = '0.4', init = function()
    local _,format = fibaro.debugFlags,string.format
    local var,cid,n = "RPC"..plugin.mainDeviceId,plugin.mainDeviceId,0
    local vinit,path = { name=var, value=""},"/plugins/"..cid.."/variables/"..var
    api.post("/plugins/"..cid.."/variables",{ name=var, value=""}) -- create var if not exist
    function fibaro._rpc(id,fun,args,timeout,qaf)
      n = n + 1
      api.put(path,vinit)
      fibaro.call(id,"RPC_CALL",path,var,n,fun,args,qaf)
      timeout = os.time()+(timeout or 3)
      while os.time() < timeout do
        local r,_ = api.get(path)
        if r and r.value~="" then
          r = r.value 
          if r[1] == n then
            if not r[2] then error(r[3],3) else return select(3,table.unpack(r)) end
          end
        end 
      end
      error(format("RPC timeout %s:%d",fun,id),3)
    end
    function fibaro.rpc(id,name,timeout) return function(...) return fibaro._rpc(id,name,{...},timeout) end end
    function QuickApp:RPC_CALL(path2,var2,n2,fun,args,qaf)
      local res
      if qaf then res = {n2,pcall(self[fun],self,table.unpack(args))}
      else res = {n2,pcall(_G[fun],table.unpack(args))} end
      api.put(path2,{name=var2, value=res}) 
    end
--local foo = fibaro.rpc(801,"foo")
--function QuickApp:onInit()
--    self:debug("onInit")
--    for i=1,100 do
--      foo(i,3) -- call QA 972, function foo, arguments 3,i and a timeout of 3s
--    end
--end
  end
} -- RPC

