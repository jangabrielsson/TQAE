-- luacheck: globals ignore makeCompiler json

--[[
  ToDo:
  V -loop,break,continue and rewrite while/repeat
  -better function compilation and closures
  -error checks compile/runtime
  -source ptr for errors
  V -local/global variables (track when compiling)
  - optimization: split local/global variable handling ?
--]]

--[[
(progn [<expr_1> ...<expr_n>])
(return [<expr_1> ...<expr_n>])
(and <expr> <expr>)
(or <expr> <expr>)
([+,-,*,/,modulo,>,>=,<,<=,==,~=,not,neg] <expr> <expr>)
(incvar name <value>)
(decvar name <value>)
(local (<name_1> [...<name_n>]) <expr>)
(params (<name_1> [...<name_n>]) <expr>)
(fun (<p_1> [...<p_n>]) <expr>)
(call name [<expr_1> ...<expr_n>])
(var name)
(aref <table> <key>)
(getglobal <name>)
(getprop <id> <key>)
(setvar name <expr>)
(aset <table> <key>)
(setglobal <name>)
(setprop <id> <key> <value>)
(setvars (<ref_1> [...<ref2_n>]) [<expr_1> ...<expr_n>]
(if <test> <then> [<else>])
(loop [<expr_1> ...<expr_n>]) -- block
(break)
(continue)
(while <test> <expr>)
(repeat <expr> <test>)
(for_idx var <start> <stop> <step> <exprs>)  -- block
(for_in var1 var2 <iterator> <exprs>)  -- block
(yield [<expr_1> ...<expr_n>])
(resume [<expr_1> ...<expr_n>])
(print [<expr_1> ...<expr_n>])
(table [<val_1> ...<val_n>])
(quote <expr>)
(encode <table>)
(decode <string>)
(mval)
(assert <type> <err msg>)
(trace <bool>)
----------
(push <expr>)
(pop [<n>])
(block <n>)
(unblock <n>)
(jmp <n>)
(jmp_true_a <n>)
(jmp_true_s <n>)
(jmp_true_j <n>)
(jmp_false_s <n>)
(jmp_false_j <n>)
--]]

EVENTSCRIPT = EVENTSCRIPT or {}
function EVENTSCRIPT.makeCompiler()

  local fmt = string.format
  local function printf(fm,...) print(fmt(fm,...))  end
  local compile,compileExpr,runCode,renderInstr,instr
  local function idF(x) return x end
  local hooks = { marshallTo=idF, marshallFrom = idF, reservedVars = {}, globalLuaVar={} }
  function hooks.globalLuaVar.set(n,v) _G[n]=v end
  function hooks.globalLuaVar.get(n) return _G[n] end
  local getGlobalLuaVar,setGlobalLuaVar = hooks.globalLuaVar.get,hooks.globalLuaVar.set
  local marshallTo,marshallFrom = hooks.marshallTo,hooks.marshallFrom 
  local trace = false
  local reservedVars = hooks.reservedVars
  local function map(f,l) local r={} for i=1,#l do r[#r+1]=f(l[i]) end return r end

  local function setupHooks()
    getGlobalLuaVar,setGlobalLuaVar = hooks.globalLuaVar.get,hooks.globalLuaVar.set
    marshallTo,marshallFrom = hooks.marshallTo,hooks.marshallFrom
  end

  local function makeStack()
    local p,x,self,stack  = 0,0,{},{}
    self.stack = stack
    local function push(e) p=p+1 x=p stack[p]=e end
    local function pushExtra(e) x=x+1 stack[x]=e end
    self.push,self.pushExtra=push,pushExtra
    function self.pushValues(values,offs)
      offs = offs or 0
      if #values-offs > 0 then
        self.push(values[1+offs])
        if #values-offs>1 then -- Push multiple-values "above" stack
          for i=2+offs,#values do self.pushExtra(values[i]) end
        end
      else self.push(nil) end
    end
    local function iter(n, i)
      i = i+1; local b = p+n+i
      if b <= x then return i,stack[b]
      else p = p+n; x = p end
    end
    self.viter = iter
    function self.values(n) return iter,n,0 end
    function self.pop(n) local r = stack[p] p=p-(n or 1) return r end
    function self.popValues(n)
      local res,i={},p+n+1
      while i <= x do  res[#res+1]=stack[i] i=i+1 end
      p=p+n; x=p
      return res
    end
    function self.trimX(n) x=x+n end
    function self.peek(n) n=n or 0 if p+n <= x then return stack[p+n] end end
    function self.peekEOS(n) n=n or 0 if p+n <= x then return stack[p+n] else return "_EOS_" end end
    function self.size() return p end
    function self.setSize(n) p=n end
    return self
  end

  local function makeEnv(locals)
    local self,env  = {},locals or {} self._vars=env
    function self.bind(x,val) env[x]={val} end
    function self.pop() env = env._next or {} end
    function self.push() local e = { _next=env };  env = e end
    function self.lookup(var,locl)
      if locl then
        local e = env
        while e and e[var]==nil do e = e._next end
        return e and e[var][1]
      else return getGlobalLuaVar(var) end
    end
    function self.set(var,val,locl)
      if locl then 
        local e = env
        while e and e[var]==nil do e = e._next end
        if e then e[var][1] = val else setGlobalLuaVar(var,val) end
      else setGlobalLuaVar(var,val) end
      return val
    end
    return self
  end

  local function makeCode()
    local self,code,labels,env,n  = {},{},{},{},0
    self.code = code
    function self.label() n=n+1; return n end
    function self.addLabel(l) labels[l]=#code+1 end
    function self.resolveLabels()
      for n1,i in ipairs(code) do
        if i[1]:sub(1,3)=='jmp' then
          local n2 = labels[i[2]] or #code+1
          i[2] = n2-n1
        elseif i[1]=='block' and i[3] then
          i[3][1],i[3][2]=labels[i[3][1]],labels[i[3][2]]
        end
      end
    end
    function self.pushLocals(vars)
      for _,v in ipairs(vars) do env[v]=true end
    end
    function self.pushBlock() local e  = {_next = env } env = e end
    function self.popBlock() env = env._next or {} end
    function self.isLocal(var)
      local e = env
      while e do if e[var] then return true else e=e._next end end
      return false
    end
    function self.emit(...) code[#code+1]={...} return code[#code] end
    return self
  end

  local GS = 0
  local function gensym(str)  GS=GS+1 return fmt("%s:%03d",str,GS) end

  local assert_types = {}
  assert_types['list'] = function(t) return type(t)=='table' and (t[1] or next(t)~=nil) end
  assert_types['string'] = function(t) return type(t)=='string' end
  assert_types['empty_list'] = function(t) return type(t)=='table' and next(t)==nil end
  assert_types['string_list'] = function(t) 
    if type(t)~='table' then return false end
    for i=1,#t do if type(t[i])~='string' then return false end  end
    return true
  end
  local function assert_type(typ,val,msg) if not assert_types[typ](val) then error(msg,2) end end

  local function dump(code)
    assert_type('list',code,"dump code called on non list")
    for n=1,#code do
      printf("%03d: %s",n,renderInstr(code[n]))
    end
    print(string.rep('-',50))
  end

  local function conc(...)
    local v = {...}
    local l = table.remove(v,#v)
    for i=#v,1,-1 do table.insert(l,1,v[i]) end
    return l
  end

  -------------------- Compile expression ---------------

  local comp={}
--[[
      {'and',a1,a2}
      <a1>
      jumpfalse <label1>
      pop
      <a2>
      <label1>
--]]
  comp['and'] = function(code,_,a1,a2)
    local  label1 = code.label()
    compileExpr(a1,code)
    code.emit('jmp_false_s',label1)
    compileExpr(a2,code)
    code.addLabel(label1)
  end
--[[
      {'or',a1,a2}
      <a1>
      jumptrue <label1>
      pop
      <a2>
      <label1>
--]]
  comp['or'] = function(code,_,a1,a2)
    local  label1 = code.label()
    compileExpr(a1,code)
    code.emit('jmp_true_s',label1)
    compileExpr(a2,code)
    code.addLabel(label1)
  end
--[[
      {'loop',<exprs>}
      block n,<label2>
      <label1>
      <exprs>
      jump_t n,<label1>
      <label2>
      unblock n
--]]
  comp['loop'] = function(code,_,...)
    local label1,label2 = code.label(),code.label()
    local exprs = {...}
    code.emit('block',#exprs,{label1,label2})
    code.addLabel(label1)
    for _,e in ipairs(exprs) do compileExpr(e,code) end
    code.emit('jmp_t',label1,#exprs)
    code.addLabel(label2)
    code.emit('unblock',#exprs)
  end
  comp['break'] = function(code,_,test) code.emit('break',test,#code.code+1) end
  comp['continue'] = function(code,_,...) code.emit('continue',#code.code+1) end
--[[
      {'while',a1,a2}
      ('loop' <a1> (break false) <a2>)
--]]
  comp['while'] = function(code,_,test,...)
    local wh = conc('loop',test,{'break',false},{...})
    compileExpr(wh,code)
  end
--[[
      {'repeat',a2,a1}
      ('loop' <a2> <a1> (break true))
--]]
  comp['repeat'] = function(code,_,...)
    local exprs = {...}
    local test = exprs[#exprs]
    table.remove(exprs,#exprs)
    exprs[#exprs+1]=test
    exprs[#exprs+1]={'break',true}
    table.insert(exprs,1,'loop')
    compileExpr(exprs,code)
  end
--[[
      {'if',a1,a2,a3}
      <a1>
      jumppopfalse <label1>
      pop
      <a2>
      jump <label2>
      <label1>
      <a3>
      <label2>
--]]
  comp['if'] = function(code,_,IF,THEN,ELSE)
    local label1,label2 = code.label(),code.label()
    if ELSE then
      compileExpr(IF,code)
      code.emit('jmp_false_a',label1)
      compileExpr(THEN,code)
      code.emit('jmp',label2)
      code.addLabel(label1)
      compileExpr(ELSE,code)
      code.addLabel(label2)
    else
      compileExpr(IF,code)
      code.emit('jmp_false_s',label1)
      compileExpr(THEN,code)
      code.addLabel(label1)  
    end
  end

-- (for_idx var start stop step expr)
  comp['for_idx'] = function(code,_,var,start_e,stop_e,step_e,...)
    local stop,step = gensym('n'),gensym('step')
    step_e = step_e or 1
    local exprs = {...}
    table.insert(exprs,{'incvar',var,{'var',step}})
    compileExpr(
      {'progn',
        {'local', {var,stop,step}, start_e, stop_e, step_e},
        conc('while', {'loopIdxCmp',{'var',var},{'var',stop},{'var',step}},exprs),
      },
      code)
  end

--[[
-- (for_in k v fun expr)
f = ipairs
x = {8,6,4}

c1,c2,c3 =  f(x)
i = c1
l = c2
c1,c2,c3 = i(l,c3)
while c1 do
  a=c1
  b=c2
  print(a,b)
  c1,c2,c3=i(l,a)
end
end
--]]
  comp['for_in'] = function(code,_,k,v,iterator,...)
    local c1,c2,c3,i,l = gensym('c1'),gensym('c2'),gensym('c3'),gensym('i'),gensym('l')

    local  exprs = {...}
    table.insert(exprs,1,{'setvars',{k,v},{'var',c1},{'var',c2}})
    table.insert(exprs,1,'progn')
    table.insert(exprs,{'setvars',{c1,c2,c3},{'call',i,{'var',l},{'var',k}}})

    compileExpr(
      {'progn',
        {'local',{c1,c2,c3},iterator},
        {'var',c1},
        {'assert','function','non-function iterator'},
        {'local',{i,l},{'var',c1},{'var',c2}},
        {'setvars',{c1,c2,c3},{'call',i,{'var',l},{'var',c3}}},
        {'while', {'var',c1,},
          exprs
        }
      },
      code)
  end

  comp['progn'] = function(code,_,...) comp['block'](code,_,...) end
  comp['block'] = function(code,_,...)
    local exprs = {...}
    code.emit('block',#exprs); code.pushBlock()
    for i=1,#exprs do
      compileExpr(exprs[i],code)
    end
    code.emit('unblock',#exprs) code.popBlock()
  end
  comp['params'] = function(code,_,params,...)
    assert_type('string_list',params,"params with non-list vars field")
    local exprs = {...}
    for i=1,#exprs do
      compileExpr(exprs[i],code)
    end
    code.emit('local',params,true,#params,#exprs); code.pushLocals(params)
  end
  comp['local'] = function(code,_,vars,...)
    assert_type('string_list',vars,"local with non-list vars field")
    local exprs = {...}
    for i=1,#exprs do
      compileExpr(exprs[i],code)
    end
    code.emit('local',vars,false,#vars,#exprs); code.pushLocals(vars)
  end

  local function compConst(expr,code)
    if type(expr)=='table' and expr[1]=='quote' then return {expr[2]}
    elseif type(expr)~='table' then return {expr} else compileExpr(expr,code) return '<st>' end 
  end
  local setpComp = {
    ['var'] = function(lv,code) local var = lv[2] return {code.isLocal(var) and "local" or "global",var,1} end,
    ['tab'] = function(lv,code)
      local tab,key = lv[2],lv[3]
      assert(false,"Not implemented yet")
    end,
    ['gv'] = function(lv,code) return {'gv',lv[2],1} end,
  }

  comp['setp'] = function(code,_,lvs,...) 
    assert_type('list',lvs,"setp with non-list LVs field")
    local exprs = {...}
    for i=1,#exprs do
      compileExpr(exprs[i],code)
    end
    local lvsi = {}
    for _,v in ipairs(lvs) do
      assert(type(v)=='table' and setpComp[v[1]],"Bad LV for setp")
      lvsi[#lvsi+1]=setpComp[v[1]](v,code) 
    end
    code.emit('setp',lvsi,#lvsi,#exprs)
  end

  comp['call'] = function(code,_,fun,...)
    local exprs={...}
    for i=1,#exprs do
      compileExpr(exprs[i],code)
    end
    if type(fun)=='string' then
      code.emit('call0',#exprs,fun,code.isLocal(fun))
    else 
      compileExpr(fun,code) 
      code.emit('call1',#exprs) 
    end
  end

  comp['quote'] = function(code,_,expr) code.emit('push',expr) end
  comp['var'] = function(code,_,var)
    if reservedVars[var] then
      code.emit(var,1) 
    else code.emit('var',var,code.isLocal(var)) end
  end
  comp['setvar'] = function(code,_,var,expr) local c = compConst(expr,code) code.emit('setvar',var,code.isLocal(var),c) end
  comp['incvar'] = function(code,_,var,expr) local c = compConst(expr,code) code.emit('incvar',var,code.isLocal(var),c) end
  comp['decvar'] = function(code,_,var,expr) local c = compConst(expr,code) code.emit('decvar',var,code.isLocal(var),c) end
  comp['arg'] = function(code,_,n) code.emit('arg',n) end
  comp['yield'] = function(code,_,...) 
    local exprs =  {...}
    for _,e in ipairs(exprs) do compileExpr(e,code) end
    code.emit('yield',#exprs)
  end
  comp['aref'] = function(code,_,tab,key) 
    compileExpr(tab,code)
    local c = compConst(key,code) 
    code.emit('aref',c)
  end
  comp['aset'] = function(code,_,tab,key,val) 
    compileExpr(tab,code)
    key = compConst(key,code) 
    val = compConst(val,code) 
    code.emit('aset',key,val)
  end
  comp['getprop'] = function(code,_,id,key) 
    assert_type('string',key,"id property must be string")
    local c = compConst(id,code) 
    code.emit('getprop',key,c)
  end
  comp['setprop'] = function(code,_,id,key,val)
    assert_type('string',key,"id property must be string")
    local c = compConst(id,code)
    val = compConst(val,code) 
    code.emit('setprop',key,c,val)
  end
  comp['getglobal'] = function(code,_,name)
    assert_type('string',name,"Global name must be string")
    code.emit('getglobal',name)
  end
  comp['setglobal'] = function(code,_,name,val)
    assert_type('string',name,"Global name must be string")
    local c = compConst(val,code)
    code.emit('setglobal',name,c)
  end
  comp['assert']  = function(code,_,typ,msg) code.emit('assert',typ,msg) end
  comp['wait']  = function(code,_,time) local c = compConst(time,code) code.emit('wait',c) end
  --[[
      fun (x,y,...) . body {'fun',{'x','y','...'},body}
      local x,y,... = ...
--]]
  local function compFun(code,_,params,...)
    assert_type('string_list',params,"fun with non-list params field")
    local body = {...}
    if params[#params] == '...' then
      table.remove(params,#params)
    end
    return compile( conc('progn',{'params',params,{'varargs'}},body))
  end

  function compileExpr(expr,code,top)
    if type(expr) == 'table' then
      if #expr==0 then return code.emit('push',expr) end
      local op = expr[1]
      if op=='fun' then
        local f = compFun(code,table.unpack(expr))
        return top and f or {'push',f}
      end
      if comp[op] then
        comp[op](code,table.unpack(expr)) 
      else
        for  i=2,#expr do compileExpr(expr[i],code) end
        if instr[expr[1]] then
          code.emit(op,#expr-1)
        else
          op = type(op)=='table' and op[2] or op
          code.emit('call0',#expr-1,op)
        end
      end
    else code.emit('push',expr) end
  end

  function compile(expr,opts)
    opts = opts or {}
    setupHooks()
    local code = makeCode()
    if opts.locals then
      local vs = {} for v,_ in pairs(opts.locals) do vs[#vs+1]=v end
      code.pushLocals(vs) 
    end
    expr=hooks.optimizeExpr(expr)
    local f = compileExpr(expr,code,true)
    code.code=hooks.optimizeCode(code.code)
    if type(f)=='function' then
      local c = f('_INSPECT_')
      if opts.dumpcode then dump(c) end
      return f
    end
    if opts.dumpcode then dump(code.code) end
    code.resolveLabels()
    local c = code.code
    return function(e,...)
      local p,st,env = 1,makeStack(),makeEnv(opts.locals)
      if e == '_INSPECT_' then return c,st,env,opts end
      env.args,env.opts =  {e,...},opts
      if opts.entryHook then opts.entryHook(opts,env) end
      local stat,err,_,vals =runCode(c,p,st,env)
      if stat then return table.unpack(vals) else error(err) end
    end
  end

  local _coroutine,running = {}
  function _coroutine.resume(co,...)
    if co.state == 'dead' then return false,"cannot resume dead coroutine"
    elseif co.state ~= 'suspended' then return false, "cannot resume non-suspended coroutine" end
    co.state = 'running'
    if co.inited then
      co.inited = false
      co.env.args = {...}      -- setup parameters. first entry (fun parameters)
      if co.env.opts.entryHook then co.env.opts.entryHook(co.env.opts,co.env) end
    else
      co.st.pushValues({...})  -- Return from yield
    end
    running = co
    local success,err,p,vals = runCode(co.code,co.p,co.st,co.env)
    if success then
      if err=='_yield_' then
        co.state = 'suspended'
        co.p = p+1
      else co.state = 'dead' end
      return true,table.unpack(vals)
    else return success,err end
  end

  function _coroutine.yield(co,...)
  end

  function _coroutine.status(co) return co.state end

  function _coroutine.running() return running end

  function _coroutine.create(fun)
    local  code,_,_,opts = fun('_INSPECT_') -- hack...
    local env =  makeEnv()
    env.opts = opts
    return { p = 1, st = makeStack(), inited=true, env = env, code = code, state='suspended' } 
  end

  ---------------- Optimize --------------
  local opts={}
  local opfuns={}
  opfuns['+'] = function(a,b) return a+b end
  opfuns['-'] = function(a,b) return a-b end
  opfuns['*'] = function(a,b) return a*b end
  opfuns['/'] = function(a,b) return a/b end
  local opmap={['+']='_OP_',['-']='_OP_',['*']='_OP_',['/']='_OP_',}

  opts['_OP_'] = function(e,op,a,b) 
    if tonumber(a) and tonumber(b) then 
      return opfuns[op](a,b)
    else return e end
  end
  opts['quote'] = function(e,op) return e end

  function hooks.optimizeExpr(expr)
    if type(expr)=='table' and expr[1] then
      local op = expr[1]
      local expr2 = {table.unpack(expr)}
      for i=2,#expr2 do expr2[i]=hooks.optimizeExpr(expr2[i]) end
      local opm = opmap[op] or op
      local opf = opts[opm]
      if opf then return opf(expr,op,select(2,table.unpack(expr2))) else return expr2 end
    end
    return expr
  end

  function hooks.optimizeCode(code)
    return code
  end
  ---------------- Running code --------------
  local function getArg(iv,st) if iv~='<st>' then return iv[1] else return st.pop() end end
  local function peekArg(iv,st) if iv~='<st>' then return iv[1] else return st.peek() end end

  instr = {}
  instr['+']  = function(i,st) st.push(st.pop()+st.pop()) end
  instr['-']  = function(i,st) local b,a = st.pop(),st.pop()  st.push(a-b) end
  instr['*']  = function(i,st) local b,a = st.pop(),st.pop()  st.push(a*b) end
  instr['/']  = function(i,st) local b,a = st.pop(),st.pop()  st.push(a/b) end
  instr['>']  = function(i,st) local b,a = st.pop(),st.pop()  st.push(a>b) end
  instr['>='] = function(i,st) local b,a = st.pop(),st.pop()  st.push(a>=b) end
  instr['<']  = function(i,st) local b,a = st.pop(),st.pop()  st.push(a<b) end
  instr['<='] = function(i,st) local b,a = st.pop(),st.pop()  st.push(a<=b) end
  instr['=='] = function(i,st) local b,a = st.pop(),st.pop()  st.push(a==b) end
  instr['~='] = function(i,st) local b,a = st.pop(),st.pop()  st.push(a~=b) end
  instr['not'] = function(i,st) st.push(not st.pop()) end
  function instr.neg(i,st) st.push(-st.pop()) end
  function instr.modulo(i,st) local b,a = st.pop(),st.pop()  st.push(a % b) end
  function instr.print(i,st) print(table.unpack(st.popValues(-i[2]))) st.push(true) end
  function instr.call0(i,st,env)
    local name,n,locl = i[3],i[2],i[4]
    local f  = env.lookup(name,locl)
    if not f then error(fmt("Undefined global function '%s'",tostring(name)),3)  end
    st.pushValues({f(table.unpack(st.popValues(-n)))})
  end
  function instr.call1(i,st,env)
    local f,n = st.pop(),i[2]
    if type(f)~='function' then error(fmt("Undefined global function '%s'",tostring(f)),3)  end
    st.trimX(-1)
    st.pushValues({f(table.unpack(st.popValues(-n)))})
  end
  function instr.mval(i,st) st.push(st.getValues()) end
  function instr.jmp(i,st) return i[2] end
  function instr.jmp_t(i,st) st.setSize(i[3]) return i[2] end 
  function instr.jmp_true_a(i,st) if st.pop() then return i[2] end end 
  function instr.jmp_true_s(i,st) if st.peek() then return i[2] else st.pop() end end 
  function instr.jmp_true_j(i,st) if st.peek() then st.pop() return i[2] end end
  function instr.jmp_false_a(i,st) if not st.pop() then return i[2] end end 
  function instr.jmp_false_s(i,st) if not st.peek() then return i[2] else st.pop() end end 
  function instr.jmp_false_j(i,st) if not st.peek() then st.pop() return i[2] end end 
  function instr.push(i,st) st.push(i[2]) end
  function instr.pop(i,st) st.pop() end
  function instr.block(i,st,env) 
    env.push() env.bind('_stackp_',st.size()) env.bind('_loop_',i[3]) 
  end
  function instr.unblock(i,st,env) 
    local p = env.lookup('_stackp_',true) 
    env.pop() 
    local r = st.pop(); 
    st.setSize(p) 
    st.push(r) 
  end
  instr['break'] = function(i,st,env)
    local v = st.peek(0)
    if i[2]~=nil and (not (v==nil or v==false)) ~= i[2] then return end
    local p = env.lookup('_loop_',true)
    if not p then error("break outside loop") end
    return p[2]-i[3]
  end
  instr['continue'] = function(i,st,env) 
    local p = env.lookup('_loop_',true)
    if not p then error("continue outside loop") end
    return p[2]-i[2]-1
  end 
  instr['return']  = function(i,st,env) error({'_RET_','_return_',i[2]}) end
  function instr.yield(i,st) error({'_RET_','_yield_',i[2]}) end
  function instr.resume(i,st) end
  instr['local']  = function(i,st,env) 
    local  vars,trim,vn,en,val = i[2],i[3],i[4],i[5]
    for j=1,vn do 
      val = st.peek(j-en) 
      if vars[j] then env.bind(vars[j],val) end 
    end
    if trim then env.pn = vn end
    st.pop(en)
    st.push(val)
  end
  instr['varargs']  = function(i,st,env) st.pushValues(env.args,env.pn) end
  function instr.var(i,st,env) st.push(env.lookup(i[2],i[3])) end
  function instr.setvar(i,st,env) 
    local val,locl = getArg(i[4],st),i[3]
    st.push(env.set(i[2],val,locl)) 
  end

  local setpF={
    ['local'] =  function(lv,val,st,env) env.set(lv[2],val,true) end,
    ['global'] =  function(lv,val,st,env) env.set(lv[2],val,false) end,
    ['gv'] =  function(lv,val,st,env) 
      fibaro.setGlobalVariable(lv[2],tostring(marshallTo(val)))
    end,
    ['tab'] = function(lv,val,st,env) assert(false,"Not implemented yet") end,
  }
  function instr.setp(i,st,env) 
    local  vars,vn,en,val,var = i[2],i[3],i[4]
    for j=1,vn do 
      var,val=vars[j],st.peek(j-en) 
      setpF[var[1]](var,val,st,env) 
    end 
    st.pop(en) st.push(val)
  end
  function instr.incvar(i,st,env)  -- name,local,const
    local var,val,locl= i[2],getArg(i[4],st),i[3]
    st.push(env.set(var,env.lookup(var,locl)+val,locl))
  end
  function instr.decvar(i,st,env)  -- name,local,const
    local var,val,locl= i[2],getArg(i[4],st),i[3]
    st.push(env.set(var,env.lookup(var,locl)+val,locl))
  end
  function instr.arg(i,st,env) st.push(env.args[i[2]]) end
  function instr.encode(i,st) st.push(json.encode(st.pop())) end
  function instr.decode(i,st) st.push(json.decode(st.pop())) end
  local TAB_KEY = "__KEY_"
  function instr.table(i,st)
    local  en,j,tab,idx = i[2],1,{},1
    local val = st.peekEOS(j-en)
    while  val ~= '_EOS_' do
      if val==TAB_KEY then
        local key = st.peekEOS(j-en+1); if key=='_EOS_' then error("table key constructor") end
        val = st.peekEOS(j-en+2);       if val=='_EOS_' then error("table key constructor") end
        tab[key]=val
        j=j+3
      else
        tab[idx]=val
        j=j+1; idx=idx+1
      end
      val = st.peekEOS(j-en)
    end
    st.pop(en)
    st.push(tab)
  end
  function instr.aref(i,st) -- aref,const
    local key = getArg(i[2],st)
    local tab=st.pop()
    st.push(tab[key])
  end
  function instr.aset(i,st) -- aref,const
    local key = getArg(i[2],st)
    local val = getArg(i[3],st)
    local tab=st.pop()
    tab[key]=val
    st.push(val)
  end
  function instr.loopIdxCmp(i,st)
    local sign,n,ix = st.pop(),st.pop(),st.pop()
    if sign > 0 then st.push(ix <= n) else st.push(ix >= n) end
  end
  instr['assert']=function(i,st) if type(st.peek(0))~=i[2] then error(i[3],2) end end
  instr['trace']=function(i,st) trace = st.peek(0) end

  instr['getglobal']=function(i,st)
    local name = i[2]
    local v,t = fibaro.getGlobalVariable(name)
    st.push(marshallFrom(v))
  end
  instr['setglobal']=function(i,st)
    local name,value = i[2],getArg(i[3],st)
    fibaro.setGlobalVariable(name,tostring(hooks.marshallTo(value)))
    st.push(value)
  end

  instr['wait']=function(i,st)
    local value = getArg(i[2],st)
    st.push(value)
    error({'_RET_','_yield_',1})
    st.push(true)
  end

  local function isReturn(r) return type(r)=='table'  and r[1]=='_RET_' end

  local function cArg(v) if type(v)=='table' then return v[1] else return "" end end
  local function notNil(v,op) if v==nil then return op else return v end end 
  local lvMap = {
    ['local']=function(lv) return lv[2].."/L" end,
    ['global']=function(lv) return lv[2].."/G" end,
    ['gv']=function(lv) return "$"..lv[2] end,
  }

  local function safeEncode(t) local stat,res = pcall(json.encode,t) return stat and res or tostring(t) end

  local instrFmt = {}
  local defInstrFmt = function(i) return fmt("%s %s %s",i[1],i[2] or "",i[3] or "") end
  instrFmt['local'] = function(i) return fmt("%s %s %s",i[1],table.concat(i[2],","),notNil(i[3],"") and "trim" or "") end
  instrFmt['params'] = function(i) return fmt("%s %s %s",i[1],table.concat(i[2],","),notNil(i[3],"")) end
  instrFmt['setp'] = function(i) return fmt("%s %s",i[1],table.concat(map(function(v) return lvMap[v[1]](v) end,i[2]),",")) end
  instrFmt['setvar'] = function(i) return fmt("%s %s/%s %s",i[1],i[2],i[3] and 'L' or 'G',cArg(i[4])) end
  instrFmt['var'] = function(i) return fmt("%s %s/%s",i[1],i[2],i[3] and 'L' or 'G') end
  instrFmt['incvar'] = function(i) return fmt("%s %s/%s %s",i[1],i[2],i[3] and 'L' or 'G',cArg(i[4])) end
  instrFmt['decvar'] = function(i) return fmt("%s %s/%s %s",i[1],i[2],i[3] and 'L' or 'G',cArg(i[4])) end
  instrFmt['block'] = function(i) return fmt("%s %s %s",i[1],i[2],notNil(i[3],"") and json.encode(i[3])) end
  instrFmt['assert'] = function(i) return fmt("%s '%s' '%s'",i[1],i[2],i[3]) end
  instrFmt['aset'] = function(i) return fmt("%s [%s] '%s'",i[1],cArg(i[2]),cArg(i[3])) end
  instrFmt['aref'] = function(i) return fmt("%s '%s'",i[1],cArg(i[2])) end
  instrFmt['getprop'] = function(i) return fmt("%s %s %s",i[1],i[2],cArg(i[3])) end

  function renderInstr(i) return instrFmt[i[1]] and instrFmt[i[1]](i) or defInstrFmt(i) end

  function runCode(code,p,st,env)
    local stat,res = pcall(function()
        while p <= #code do
          local i,str = code[p]
          if trace then 
            str =  fmt("%03d:%02d %s",p,st.size(),renderInstr(i))
            p = p + (instr[i[1]](i,st,env) or 1)
            local res = st.peek()
            printf("%-40s -> %02d:%s",str,st.size(), tostring(res):sub(1,40))
          else
            p = p + (instr[i[1]](i,st,env) or 1)
          end
        end
      end)
    if not stat then
      if  isReturn(res) then
        return true,res[2],p,st.popValues(-res[3])
      else return false,res,p end
    else return true,'dead',p,st.popValues(-1) end
  end

  function hooks.addInstr(i,f,c) instr[i]=f or instr[i]; comp[i]=c or comp[i] end
  hooks.getArg = getArg
  hooks.peekArg = peekArg
  hooks.compConst = compConst

  return {
    dump = dump,
    compile = compile,
    coroutine = _coroutine,
    trace = function(b) trace = b end,
    hooks = hooks
  }
end