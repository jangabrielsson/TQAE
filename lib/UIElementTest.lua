local _=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
--offline = true,
}

--%%name="My QA"
--%%type="com.fibaro.binarySwitch"
--%%u1={label='label', text=''}
--FILE:lib/UIElements.lua,UIElements;


local function runFuns(tab,i)
  i = i or 1
  if i < #tab then
    local delay,fun = tab[i],tab[i+1]
    setTimeout(function() fun() runFuns(tab,i+2) end,1000*delay)
  end
end

local function emoji(c) return utf8.char(c) end

local emojiMap = {
  lunch = emoji(0x1F372),
  wakeup = emoji(0x23F0),
  night = emoji(0x1F634)
}
local cal = {
  mon = { ["07:00"] = {"wakeup"}, ["11:00"] = {'lunch'}, ["23:00"] = {"night"}},
  tue = { ["07:00"] = {"wakeup"}, ["11:00"] = {"lunch"}, ["23:00"] = {"night"}},
  wed = { ["07:00"] = {"wakeup"}, ["11:00"] = {"lunch"}, ["23:00"] = {"night"}},
  thu = { ["07:00"] = {"wakeup"}, ["11:00"] = {"lunch"}, ["23:00"] = {"night"}},
  fri = { ["07:00"] = {"wakeup"}, ["11:00"] = {"lunch"}, ["23:00"] = {"night"}},
  sat = { ["07:00"] = {"wakeup"}, ["11:00"] = {"lunch"}, ["23:00"] = {"night"}},
  sun = { ["07:00"] = {"wakeup"}, ["11:00"] = {"lunch"}, ["23:00"] = {"night"}},
}

function QuickApp:onInit()
  local c = UIMatrix{label='label',data=cal,qa=self} 
  c:set('tableAttr', 'border=1 width=300')
  c:set('headerAttr',"bgcolor=blue") 
  c:set('headerFont',"color=white")
  c:set('fcolFont',  "color=white")
  c:set('fcolAttr',  "bgcolor=green")     
  c:set('itemAttr',  '')
  
  function c:renderEntry(entry)  -- table of entries
    local str = {}
    for _,e in ipairs(entry) do str[#str+1]=emojiMap[e] or e end
    return table.concat(str) 
  end
  c:update()

  runFuns{
    1,function() c:addEntry("mon","11:00","night") c:update() end,
    1,function() c:addEntry("fri","07:00","lunch") c:update() end,
    1,function() c:addEntry("thu","17:00","wakeup") c:update() end,
--    1,function() c:clearEntry("mon","11:00","night") c:update() end,
--    1,function() c:clearEntry("fri","07:00","lunch") c:update() end,
--    1,function() c:clearEntry("thu","17:00","wakeup") c:update() end,
  }
end

function QuickApp:restart() plugin.restart() end