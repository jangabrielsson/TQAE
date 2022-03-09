-- luacheck: globals ignore makeCompiler json

dofile("lib/script/eval.lua")

local fmt = string.format

local function parse(str)
  local strs = {}
  str = str:gsub("%b''",function(s) strs[#strs+1]=s return "_STR"..#strs end)
  str = str:gsub('%b""',function(s) strs[#strs+1]=s return "_STR"..#strs end)
  str=str:gsub("%$(%w+)",function(s) return fmt('(var %s)',s)  end)  
  str=str:gsub("%(","[")
  str=str:gsub("%)","]")
  str=str:gsub("([_<>=~%w%+%-%*%/%%]+)",function(s) return '"'..s..'"'  end)
  str=str:gsub("(%.%.%.)",function(s) return '"..."'  end)
  str=str:gsub('(".-")',function(s) return s..","  end)
  str=str:gsub("(%]%s)",function(s) return "],"  end)
  str=str:gsub('"true"',function(s) return 'true' end)
  str=str:gsub('"false"',function(s) return 'false' end)
  str=str:gsub('"(%-?%d+)"',function(s) return s end)
  str = str:gsub('"_STR(%d+)"',function(d) return strs[tonumber(d)] end)
  return json.decode(str)
end

local c = makeCompiler()

local function printf(f,...) print(fmt(f,...)) end

local function equal(e1,e2)
  if e1==e2 then return true
  else
    if type(e1) ~= 'table' or type(e2) ~= 'table' then return false
    else
      for k1,v1 in pairs(e1) do if e2[k1] == nil or not equal(v1,e2[k1]) then return false end end
      for k2,_  in pairs(e2) do if e1[k2] == nil then return false end end
      return true
    end
  end
end

local function pres(correct,n,r0,r1,t)
  printf("%05.2f:%s %-36s => %-20s %.2fms",n,correct and "OK" or  "NO",(json.encode(r0)):sub(2,-2),(json.encode(r1)):sub(2,-2),t)
end

local function runTest(expr,args,dump,trace)
  local f = c.compile(expr,{dump=dump})
  c.trace(trace==true)
  local t0 = os.clock()
  local res1 = {f(table.unpack(args))}
  t0 = (os.clock()-t0)*1000
  return res1,t0
end

local function singleTest(nr,ts)
  local tl
  for _,t in ipairs(ts) do
    if t[1]==nr then tl=t break end
  end
  local expr,args,res,trace,dump = parse(tl[2]),tl[3],tl[4],tl[5],tl[6]
  local res1,t0,stackp = runTest(expr,args,true,true)
  local correct = equal(res,res1)
  pres(correct,tl[1],res1,res,t0)  
end

local function runTests(ts)
  local errors = {}
  for  _,e in ipairs(ts) do
    local expr,args,res,trace,dump = parse(e[2]),e[3],e[4],e[5],e[6]
    local res1,t0,stackp = runTest(expr,args,alwaysDump or dump,trace)
    if trace then print(string.rep("-",50)) end
    local correct = equal(res,res1)
    if not correct then errors[#errors+1] = {e[1],res1,res,t0} end
    if not silent then pres(correct,e[1],res1,res,t0) end
  end
  if  #errors > 0 and silent then 
    for _,e in ipairs(errors) do pres(false,table.unpack(e)) end
  elseif #errors > 0 then
    printf("Errors: %s",#errors)
  else
    printf("all OK")
  end
end

local function runCTests(ts,d)
  for  _,e in ipairs(ts) do
    local expr,args,res,trace,dump = parse(e[2]),e[3],e[4],e[5],e[6]
    local f = c.compile(expr,{dump=dump})
    local co = c.coroutine.create(f)
    c.trace(trace==true)
    local t0 = os.clock()
    local res1 = {c.coroutine.resume(co,table.unpack(args))}
    if trace then print(string.rep("-",50)) end
    t0 = (os.clock()-t0)*1000
    if res1[1] then
      table.remove(res1,1)
      local correct = equal(res,res1)
      pres(correct,e[1],res1,res,t0)
    else
      printf("Error:")
    end
  end
end

function foo2(...) 
  local a={...} 
  return a[1]*a[2] 
end
function foo1(...) 
  local a = {...}
  return 8*a[1] 
end
function foo0(...) 
  local a = {...}
  return 64 
end
function bar(...) return {...} end
function ret(...) return ... end
ppp = print
function ppp2() return print end

local tests = {
  {1,"(fun(x) (+ $x $x))",{7},{14}},
  {1.1,"(fun(x) (+ 8 9))",{7},{17}},
  {1.2,"(fun(x) (call $print 8) 17)",{7},{17}},
  {1.3,"(fun(x) {4,2,3})",{7},{14}},
  {2,"(fun(x ...) (table (varargs)))",{3,2,1},{{2,1}}},
  {3,"(fun(x ...) (table 66 (varargs)))",{3,2,1},{{66,2,1}}},
  {4,"(fun(...) (return (varargs)))",{3,2,1},{3,2,1}},
  {5,"(fun(x) (if $x 42 17))",{true},{42}},
  {6,"(fun(x) (if $x 42 17))",{false},{17}},
  {7,"(fun(x) (if $x 42))",{true},{42}},
  {8,"(fun(x) (if $x 42))",{false},{false}},
  {9,"(fun(x) (quote (6 7)))",{false},{{6,7}}},
  {10,[[(fun(x) (aref $x "test"))]],{{test=66}},{66}},
  {10.1,[[(fun(x) (aset $x "test" 77) (aref $x "test"))]],{{test=66}},{77}},
  {11,[[(fun(x) (+ (foo2 $x 8) 6))]],{8},{70}},
  {12,[[(fun(x) (+ (foo1 $x) 6))]],{8},{70}},
  {13,[[(fun(x) (+ 6 (foo2 $x 8)))]],{8},{70}},
  {14,[[(fun(x) (+ 6 (foo1 $x)))]],{8},{70}},
  {15,[[(fun(x) (+ 6 (foo0)))]],{8},{70}},
  {16,[[(fun(x) (+ (foo2 (ret $x 8)) 6))]],{8},{70}},
  {16.1,[[(fun(x) (local (v) (table "__KEY_" "k1" 66 "__KEY_" "k2"  77)) $v)]],{8},{{k1=66,k2=77}}},  
  {17,[[(fun(x) (local (x y z) 7 6 (varargs)) (+ $x $z))]],{3,4},{11}},
  {18,[[(fun(x) (local (s) 0) (for_idx z 1 $x 1 (incvar s 1)) $s)]],{101},{101}},
  {19,[[(fun(x) (local (s) 0) (for_idx z $x 1 -1 (incvar s 1)) $s)]],{102},{102}},
  {20,[[(fun(x) (local (s) 0) (for_in k z (ipairs $x) (incvar s $z)) $s)]],{{4,5,6}},{15}},
  {21,[[(fun(x) (local (s) 0) (for_in k z (pairs $x) (incvar s $z)) $s)]],{{a=4,b=5,c=6}},{15}},
  {21.1,[[(fun(x) (local (s) 0) (loop (incvar s 1) (break) (print $s)) $s)]],{1},{1}},


  {22,[[(fun(x)
       (local (y) 1)
       (while true
          (progn
           (if (< $x 1) (return $y))
           (setvar y (* $y $x))
           (setvar x (- $x 1))
          )
       ))]],{5},{120}},

  {23,[[(fun(x)
       (local (y) 1)
       (repeat
          (progn
           (setvar y (* $y $x))
           (setvar x (- $x 1))
          )
          (< $x 1))
        (return $y)
       )]],{5},{120}},


--  {[[(fun(x)
--       (local (receive send)
--          (fun(prod) (resume $prod))
--          (fun(x) (yield $x))
--        )
--       (local (producer)
--          (coro (fun() (while true (setvar x (g)) ($send $x))))
--        )
--       (local (consumer)
--          (coro (fun() (while true (setvar x ($$recieve)) (print $x))))
--        )
--       ($consumer ($producer))
--       )]],{8},{16}},
}

--silent = true--alwaysDump = true
alwaysTrace = false

local ctests = {
  {1,"(fun(x) (yield  $x))",{7,8},{7}},
  {2,"(fun(x y) (yield  $x $y))",{7,8},{7,8}},
}

singleTest(1.3,tests)

--runTests(tests)
--runCTests(ctests)
