_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
}


function rule(str)
  local p,isRule = parser(expr)
  
  if gstruct then print(json.encode(p)) end
  f = compiler.compile(p,dump)
end