local compile, compile_aux, listToArr, compLocal, compLambda
local Exception, NIL, isLType, lassert

Lisp.inits[#Lisp.inits+1] = function(lisp)
  Exception =lisp.Exception
  isLType, NIL, lassert = lisp.isLType, lisp.NIL, Lisp.lassert
end

class 'Env'
function Env:__init(env,nvars)
  self.vars = {}
  self.nxt = env
  if nvars then self:pushLocals(nvars) end
end
function Env:lookup(var,n)
  n = n or 0
  if self.vars[var] then return self.vars[var],n
  elseif self.nxt then return self.nxt:lookup(var,n+1) 
  else return false end
end
function Env:popEnv() return self.nxt end
function Env:pushLocal(var) self.vars[var]=true end
function Env:pushLocals(nvars) for _,v in ipairs(nvars or {}) do self.vars[v]=true end end
function Env:pushBinding(var,val) self.vars[var]={val} end
function Env:setBinding(var,val) self.vars[var][1]=val end

function Lisp.evalt(e,env)
  if type(e)=='number' then return e
  else return e:eval(env) end
end

class 'CExpr'
function CExpr:__init(expr) 
  self.expr = expr
end
function CExpr:run()
  return Lisp.evalt(self.expr,Env())
end
function CExpr:__tostring()
  return tostring(self.expr)
end

function compile(e)
  local cenv = Env()
  e = compile_aux(e, cenv);
  if isLType(e) then e:isTailRec() end
  return CExpr(e)
end

function compile_aux(e, cenv)
  -- List
  if type(e) ~= 'table' or e.__ltyp==nil then return e end
  if e:isCons() then
    local car,cdr = e.car,e.cdr
    if isLType(car)==nil then 
      Exception.Compile("Bad functor",a) 
    end
    if car:isAtom() then
      local a = car
      -- Quote: i.e. '(1 2 3)
      if a == Lisp.QUOTE then
        return Const(cdr.car)

        -- Lambda: (lambda vars . body)
      elseif a == Lisp.LAMBDA or a == Lisp.FN then
        return compLambda(cenv, cdr.car, listToArr(cdr.cdr))

        -- Flet: (flet ((v1 e1) ...) . body)
      elseif a == Lisp['LET*'] then
        return compLocal(cenv, cdr.car, listToArr(cdr.cdr), true)

        -- Let: (let ((v1 e1) ...) . body)
      elseif a == Lisp.LET then
        return compLocal(cenv, cdr.car, listToArr(cdr.cdr),false)

        -- If: (if test then [else])
      elseif a == Lisp.IF then
        local test,eT,eE = cdr.car, cdr.cdr.car,cdr.cdr.cdr
        if eE ~= NIL then eE = eE.car end
        return IfThenElse(compile_aux(test, cenv), compile_aux(eT, cenv), compile_aux(eE, cenv))

        -- Catch: (catch tag . body)
      elseif a == Lisp.CATCH then
        local tag,body = cdr.car, listToArr(cdr.cdr)
        for i=1,#body do body[i]=compile_aux(body[i],cenv) end
        return Catch(compile_aux(tag, cenv), body)

        -- Progn: (progn . body)
      elseif a == Lisp.PROGN then
        return compProgn(cenv, listToArr(cdr))

      elseif a == Lisp.SETQ then
        local args = listToArr(cdr)
        if #args % 2 ~= 0 then Exception.Compile("Wrong number of args to SETQ", e) end
        for i = 1,#args do args[i] = compile_aux(args[i], cenv) end
        return Setq(args)

      elseif a == Lisp.WHILE then
        local test = cdr.car;
        local args = listToArr(cdr.cdr);
        return While(compile_aux(test, cenv), compProgn(cenv, args))

        -- Defun: (defun name vars . body)
      elseif a == Lisp.DEFUN or a == Lisp.DEFMACRO then
        local name,params,body = cdr.car,cdr.cdr.car,listToArr(cdr.cdr.cdr)
        local lambda = compLambda(cenv, params, body)
        return Defun(name, lambda, a == Lisp.DEFMACRO);       
      end

    end
    -- Call: i.e. (fun . args)
    local args = listToArr(cdr)  
    local fun = compile_aux(car, cenv)  
    if fun:isAtom() and fun:isMacro() then
      for i=1,#args do 
        args[i] = Const(args[i])
      end
      local exp1 = Call(fun, args)
      local exp2 = CExpr(exp1):run()
      Lisp:trace("macroexpand","MacroExpand %s => %s",exp1,exp2)
      return compile_aux(exp2, cenv)
    else
      for i=1,#args do
        args[i] = compile_aux(args[i], cenv)
      end
      return Call(fun, args)
    end

    -- Variable
  elseif e:isAtom() then
    local lcl,n = cenv:lookup(e) 
    if lcl then
      cenv.free = (cenv.free or 0) + (n > 0 and 1 or 0)
      return LocalRef(e)
--    if cenv:lookup(e)  then
--      return LocalRef(e)
    else return (e) end
  else error("Bad expression") end
end

--[[
	 local: (let ((v1 e1) ...) . body) (flet ((v1 e1) ...) . body)
--]]
function compLocal(cenv, args, body, rec) --CEnv env, Expr args, Expr body[], boolean rec
  local vars,exprs,cbody = {},{},{}
  -- Get vars and initial vals
  for vl in args:iter() do 
    vars[#vars+1] = vl.car
    exprs[#exprs+1] = vl.cdr.car
  end
  if rec then cenv = Env(cenv,vars) end
  for i=1,#exprs do exprs[i] = compile_aux(exprs[i], cenv) end
  if not rec then cenv = Env(cenv,vars) end
  for _,b in ipairs(body) do cbody[#cbody+1] = compile_aux(b, cenv) end
  return Local(vars, exprs, cbody, rec)
end

function compProgn(cenv, body)
  local cbody = {}
  for _,b in ipairs(body) do cbody[#cbody+1] = compile_aux(b, cenv) end
  return Progn.mkBody(cbody);
end

local function parseOpt(e)
  local dflt,param,inited
  local stat,res = pcall(function()
      if e:isCons() then
        param = e.car
        local c = e.cdr
        dflt = c.car
        if c.cdr:isCons() then
          inited = c.cdr.car
        end
      else param = e end
      return Lambda_ParamExpr(param,dflt,inited)
    end)

  if not stat then 
    Exception.Compile("Bad parameter",e)
  else return res end
end

function compLambda(cenv, prms, body) 
  local pRest = nil
  local pReg,pOpt,pKey = {},{},{}

  if prms:isCons() then
    local stat = 0
    for e in prms:iter() do
      if e == Lisp.OPTIONAL then 
        lassert(stat==0,Exception.Compile,"Illegal &optional parameter")
        stat = 1 
      elseif e == Lisp.REST then 
        lassert(stat < 3,Exception.Compile,"Illegal &rest parameter")
        stat = 3
      elseif e == Lisp.KEYS then 
        lassert(stat < 2,Exception.Compile,"Illegal &keys parameter")
        stat = 2
      elseif stat == 0 then pReg[#pReg+1] = e
      elseif stat == 1 then pOpt[#pOpt+1] = parseOpt(e)
      elseif stat == 2 then pKey[#pKey+1] = parseOpt(e)
      elseif stat == 3 then pRest = e stat = 4 
      elseif stat == 4 then Exception.Compile("Multiple &rest parameters") 
      end
    end
  end

  local nEnv = Env(cenv)
  nEnv:pushLocals(pReg)
  for _,o in ipairs(pOpt) do nEnv:pushLocal(o.param) end

  if pRest then nEnv:pushLocal(pRest) end

  -- Compile optional params default values.
  for _,o in ipairs(pOpt) do if o.dlft then o.dflt = compile_aux(o.dflt,nEnv) end end

  -- Get body, i.e vector of Exprs, while computing free vars.
  for i=1,#body do body[i] = compile_aux(body[i], nEnv) end

  return Lambda(Lambda_ParamBlock(pReg,pOpt,pRest), body, nEnv.free or 0)

end

-----------------------

function listToArr(e)
  local r = {}
  if e:isCons() then
    for e1 in e:iter() do r[#r+1]=e1 end 
  end
  return r
end

Lisp.listToArr = listToArr

function Lisp:arrToListRest(es)
  local s = {}
  for _,e in ipairs(es) do s[#s+1]=tostring(e) end
  return table.concat(s," ")
end

function Lisp:arrToList(es) return "("..self:arrToListRest(es)..")" end

Lisp.compile = compile