dofile("lib/script/eval.lua")
dofile("lib/script/parser.lua")

apiResult = "aaaa,79897987|bbbbb"
apiResult = apiResult:gsub("%,(%d-)%|" ,",k|")
print(apiResult)
local tests = {
--  {1,"a = 9",{7},{9},true,true},
--  {1,"a = 9;b=10; c=a+b*2",{7},{29},true,true},
--  {1,"for x=1,3 do print(x) end",{7},{29},true,true},
  {1,"print(8)",{7},{29},true,true},
--  "b[8] = a",
--  "b[8] = foo(9):bar(7)",
--  "b[8] = a+1*5",
}

compiler = makeCompiler()
for _,e in ipairs(tests) do
  local tag,expr,args,res,dump,trace = e[1],e[2],e[3],e[4],e[5],e[6]
  local parser = makeParser()
  local p = parser(expr)
  print(json.encode(p))
  f = compiler.compile(p)
  compiler.trace(true)
  local r = {f(table.unpack(args))}
  print(json.encode(r))
end