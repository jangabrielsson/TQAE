_=loadfile and loadfile("TQAE.lua"){
  --refreshStates=true,
  debug = { webserver = true },
  copas=true,
  shadow=true
  --speed=48,
}

--FILE:lib/fibaroExtra.lua,fibaroExtra;
--FILE:lib/script/parser.lua,parser;
--FILE:lib/script/eval.lua,eval;
--FILE:lib/script/EventScriptFuns.lua,funs;
--FILE:lib/script/EventScript.lua,ES;

--%%name="EventRunner"

function QuickApp:main()
  --fibaro.debugFlags.post=true
  local rule,defvar,defvars = EVENTSCRIPT.rule,EVENTSCRIPT.defvar,EVENTSCRIPT.defvars
  local defTriggerVar,reverseMapDef = EVENTSCRIPT.defTriggerVar, EVENTSCRIPT.reverseMapDef
  
  --rule("@@00:00:05 => log('ping')")
  defTriggerVar('V')
  X=rule("trueFor(00:00:05,V) => log('OK'); again(3)")
  rule("V=true")
  rule("disable(X)")
end


function QuickApp:onInit()
  EVENTSCRIPT.setupES()
  self:main()
end