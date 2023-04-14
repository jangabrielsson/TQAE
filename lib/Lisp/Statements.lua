local Exception, NIL, isLType, evalt, debug

Lisp.inits[#Lisp.inits+1] = function(lisp)
  Exception =lisp.Exception
  isLType, evalt, NIL = lisp.isLType, lisp.evalt, lisp.NIL
  debug = Lisp.debug
end

local fmt = string.format

-------------------
class 'LocalRef'(Expr)
function LocalRef:__init(atom)
  self.atom = atom
end 
function LocalRef:isLocal() return true end 

function LocalRef:eval(env) 
  local res = env:lookup(self.atom)
  if res ~= nil then
    return res[1]
  else Exception.Unbound(self) end
end

function LocalRef:set(env, expr) 
  local b = env:lookup(self.atom)
  b[1]=expr
  return expr
end

function LocalRef:__tostring()
  if Lisp.verbose then
    return "L:"..tostring(self.atom)
  else
    return tostring(self.atom)
  end
end

--------------------------------
class 'IfThenElse'(Expr)
function IfThenElse:__init(eTest, eThen, eElse) 
  self.eTest = eTest
  self.eThen = eThen
  self.eElse = eElse
end

function IfThenElse:eval(env) 
  if evalt(self.eTest,env) ~= Lisp.NIL then return evalt(self.eThen,env)
  else return evalt(self.eElse,env) end
end 

function IfThenElse:isTailRec(curr) 
  local b1 = isLType(self.eThen) and self.eThen:isTailRec(curr)
  local b2 = isLType(self.eElse) and self.eElse:isTailRec(curr)
  return b1 or b2;
end

function IfThenElse:__tostring() 
  return "(IF " .. tostring(self.eTest) .. " " .. tostring(self.eThen) .. " " .. tostring(self.eElse) .. ")"
end

----------------------------------

class 'Call'(Expr)
Call.__ltyp='Call'
function Call:__init(fun,args)
  self.fun = fun
  self.args = args
  self.tail = false
end

function Call:eval(env) 
  env:pushBinding('_call',self)
  return self.tail and self or self.fun:funBinding(env):apply(env, self.args)
end

function Call:isTailRec(curr)
  if self.fun:isFree() then
    self.tail = self.fun.atom == curr
  else
    self.tail = self.fun == curr
    return self.tail
  end
end

function Call:traceStr(args) return fmt("(%s%s %s)",self.tail and "@" or "",self.fun,Lisp:arrToListRest(args)) end
function Call:trace(args) Lisp:trace("trace",self:traceStr(args)) end

function Call:__tostring()
  return fmt("(%s%s %s)",self.tail and "@" or "",tostring(self.fun),Lisp:arrToListRest(self.args))
end

--------------

class 'Local'(Expr)
function Local:__init(vars, exprs, body, rec) 
  self.vars = vars
  self.exprs = exprs
  self.body = Progn.mkBody(body)
  self.rec = rec
end

function Local:eval(env)
  local vars,exprs = self.vars,self.exprs
  for i=1,#vars do
    env:pushBinding(vars[i],evalt(exprs[i],env))
  end
  return self.body:eval(env)
end

function Local:isTailRec(curr)
  local vars,exprs = self.vars,self.exprs
  if self.rec then
    for i=1,#exprs do if type(exprs[i])~='number' then exprs[i]:isTailRec(vars[i]) end end
  end
  return self.body:isTailRec(curr);
end

local function va(self)
  local vars,exprs = self.vars,self.exprs
  if #vars == 0 then return "()" end
  local s = {}
  for i=1,#vars do s[#s+1] = fmt("(%s %s)",tostring(vars[i]),tostring(exprs[i])) end
  return "(" .. table.concat(s," ") .. ")"
end

function Local:__tostring() 
  return fmt("(%s %s %s)",self.rec and "FLET" or "LET",va(self),tostring(self.body))
end

---------------

class'Progn'(Expr) 

function Progn:__init(exprs) 
  self.exprs = exprs
end

function Progn:eval(env) 
  local e = Lisp.NIL
  for i=1,#self.exprs do e = evalt(self.exprs[i],env) end
  return e
end

function Progn:isTailRec(curr)
  if #self.exprs > 0 then return self.exprs[#self.exprs]:isTailRec(curr) else return false end
end

function Progn:__tostring() 
  return "(PROGN " .. Lisp:arrToListRest(self.exprs) .. ")"
end

function Progn.mkBody(exprs)
  if #exprs == 0 then return Lisp.NIL
  elseif #exprs == 1 then return exprs[1]
  else return Progn(exprs) end
end

----------------------

class'While'(Expr)
function While:__init(test, body)
  self.test = test
  self.body = body
end

function While:eval(env)
  while evalt(self.test,env) ~= NIL do
    self.body:eval(env)
  end
end

function While:__tostring() 
  return fmt("(WHILE %s %s)",tostring(self.test),tostring(self.body)) 
end
------------------------

class 'Setq'(Expr)
function Setq:__init(exprs)
  self.exprs = exprs
end

function Setq:eval(env)
  local e,exprs = NIL,self.exprs
  for i=1,#self.exprs,2 do e = exprs[i]:set(env,evalt(exprs[i+1],env)) end
  return e
end

function Setq:__tostring()
  return fmt("(SETQ %s)",Lisp:arrToListRest(self.exprs))
end

--------------------------

class'Lambda_ParamExpr'
function Lambda_ParamExpr:__init(param, dflt, inited)
  self.param = param
  self.dflt = dflt
  self.inited = inited
end
function Lambda_ParamExpr:bind(e,env)
  if e then 
    if self.inited then env.pushBinding(self.inited,Lisp.T) end
    return self.param,e 
  end
  e = self.dflt and evalt(self.dflt,env) or NIL
  if self.inited then env.pushBinding(self.inited,Lisp.NIL) end
  return self.param,e
end
function Lambda_ParamExpr:__tostring()
  if self.dflt then
    return fmt("(%s %s%s)",self.param,self.dflt,self.inited and " "..self.inited or "")
  else return tostring(self.param) end
end

class'Lambda_ParamBlock'
function Lambda_ParamBlock:__init(regular, optional, restVar, keys)
  self.regular = regular
  self.optional = optional
  self.restVar = restVar
  self.keys = keys
end

function Lambda_ParamBlock:bind(args,env)
  local regular,optional = self.regular,self.optional
  local ra = #regular
  if #args < ra then 
    local call = env:lookup('_call')
    Exception.Eval("Wrong number of arguments:"..(call.fun or "")) 
  end
  for i=1,ra do env:pushBinding(regular[i],args[i]) end
  for i=1,#optional do env:pushBinding(optional[i]:bind(args[ra+i],env)) end
  if self.restVar then
    local r = NIL
    for i=#args,ra+#optional+1,-1 do
      r = Cons(args[i],r)
    end
    env:pushBinding(self.restVar,r)
  end
end

function Lambda_ParamBlock:set(args,env)
  local regular,optional = self.regular,self.optional
  local ra = #regular
  if #args < ra then 
    local call = env:lookup('_call')
    Exception.Eval("Wrong number of arguments:"..(call.fun or "")) 
  end
  for i=1,ra do env:setBinding(regular[i],args[i]) end
  for i=1,#optional do env:setBinding(optional[i]:bind(args[ra+i],env)) end
  if self.restVar then
    local r = NIL
    for i=#args,ra+#optional+1,-1 do
      r = Cons(args[i],r)
    end
    env:pushBinding(self.restVar,r)
  end
end

local function strT(arr) 
  local r,p="",""
  for _,a in ipairs(arr) do if a and a~="" then  r=r..p..tostring(a) p= " " end end
  return r
end

function Lambda_ParamBlock:__tostring() 
  return fmt("(%s)",
    strT({Lisp:arrToListRest(self.regular),
        Lisp:arrToListRest(self.optional),
        self.restVar and ("&REST "..tostring(self.restVar))}))
end

class 'Lambda'(Expr)
function Lambda:__init(pb, body, free)
  self.pb = pb
  self.free = free
  self.body = Progn.mkBody(body)
end

function Lambda:funBinding(env)
  return self:eval(env)
end

function Lambda:isMacro() return self.macro end

function Lambda:eval(env)
  if self.free > 0 then 
    return Closure(self, env)
  else return self end
end

function Lambda:apply(env, args) 
  local eargs = {}
  for _,e in ipairs(args) do eargs[#eargs+1]=evalt(e,env) end
  return self:apply2(env,eargs)
end

local function traceCall(call, args)
  if call then call[1]:trace(args) end
end

function Lambda:apply2(env, args)
  local pb,body = self.pb,self.body
  env = Env(env)
  pb:bind(args,env)

  while true do
    if debug.trace then traceCall(env:lookup('_call'),args) end
    local e = body:eval(env);
    if isLType(e) == 'Call' then -- Tail recursive call
      args = {}
      for _,e1 in ipairs(e.args) do args[#args+1]=evalt(e1,env) end
      pb:set(args,env)
    else
      return e
    end
  end
end

function Lambda:isTailRec(curr)
  self.tail = self.body:isTailRec(curr)
  return self.tail
end

function Lambda:__tostring() 
  return fmt("(%sLAMBDA %s %s)",self.free > 0 and "C:" or "",tostring(self.pb),tostring(self.body))
end

------

class 'Closure'(Expr)
function Closure:__init(lambda,env)
  self.lambda = lambda
  self.env = env
end

function Closure:eval(env) 
  return self
end

function Closure:isTailRec(curr)
  self.tail = self.lambda:isTailRec(curr)
  return self.tail
end

function Closure:isMacro()
  return self.lambda:isMacro()
end

function Closure:apply(env, args) 
  return self.lambda:apply(env, args)
end

function Closure:apply2(env, args) 
  return self.lambda:apply2(env, args)
end

function Closure:__tostring() 
  return tostring(self.lambda)
end

----------------------------

class 'Defun'(Expr)
function Defun:__init(name, lambda, macro)
  self.name = name
  self.lambda = lambda
  self.macro = macro
end

function Defun:eval(env)
  self.name:funset(env, self.lambda:eval(env))
  self.lambda.macro = self.macro
  return self.name
end

function Defun:isTailRec(curr) 
  return self.lambda:isTailRec(self.name)
end

function Defun:__tostring()
  return "(DEFUN " .. tostring(self.name) .. " " .. tostring(self.lambda)
end

------------------------------

class 'Catch'(Expr)
function Catch:__init(tag, body) 
  self.tag = tag
  self.body = Progn.mkBody(body)
end

function Catch:eval(env)
  local tag = self.tag:eval(env)
  local stat,res = pcall(function()
      return self.body:eval(env)
    end)
  if stat then return res
  else
    if type(res) == 'table' and res.type then
      if res.type == tag then
        return res.value or NIL
      elseif tag == NIL then
        return tostring(res)
      else error(res) end
    else error(res) end
  end
end

function Catch:isTailRec(curr) return self.body:isTailRec(curr) end

function Catch:__tostring()
  return fmt("(CATCH %s %s)",tostring(self.tag),tostring(self.body))
end
