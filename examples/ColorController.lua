-- luacheck: globals ignore QuickAppBase QuickApp QuickAppChild quickApp fibaro
-- luacheck: globals ignore api json class setInterval clearInterval
-- luacheck: globals ignore ColorComponents

_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
--offline = true,
}

--FILE:lib/colorComponents.lua,colorComponents;

--%%name="MyColorController"
--%%type="com.fibaro.colorController"

------------------ QuickApp that is a ColorController  using  ColorComponents

function QuickApp:onInit()
  quickApp = self
  self:debug(self.id,self.name)
  self.colorComponent = ColorComponents{
    parent = self,
    colorComponents = { -- Comment out components not needed
      warmWhite =  0,
      coldWhite = 0,
      red = 0,
      green = 0,
      blue = 0,
      amber = 0,
      cyan = 0,
      purple = 0,
    },
    dim_time   = 10000,  -- Time to do a full dim cycle, max to min, min to max
    dim_min    = 0,      -- Min value
    dim_max    = 99,     -- Max value
    dim_interv = 1000    -- Interval between dim steps
  }
end
