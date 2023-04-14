_MODULES = _MODULES or {} -- Global
_MODULES.trace={ author = "jan@gabrielsson.com", version = '0.4', depends={}, init = function()
    local _,_ = fibaro.debugFlags,string.format
  end
} -- Trace functions

