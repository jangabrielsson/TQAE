function class(name)
  local cl = {}
  cl.__index = cl
  local cl2 = {}
  cl2.__index = cl
  cl2.__newindex = cl
  function cl2.__call(_,...)
    local obj = setmetatable({},cl)
    local init = rawget(cl,'__init')
    if init then init(obj,...) end
    return obj
  end
  _G[name] = setmetatable({ __org = cl },cl2)
  return function(parent)
    setmetatable(cl,parent.__org)
  end
end