_MODULES = _MODULES or {} -- Global
_MODULES.weather={ author = "jan@gabrielsson.com", version = '0.4', depends={'base'},
  init = function()
    local _,_ = fibaro.debugFlags,string.format
    fibaro.weather = {}
    function fibaro.weather.temperature() return api.get("/weather").Temperature end
    function fibaro.weather.temperatureUnit() return api.get("/weather").TemperatureUnit end
    function fibaro.weather.humidity() return api.get("/weather").Humidity end
    function fibaro.weather.wind() return api.get("/weather").Wind end
    function fibaro.weather.weatherCondition() return api.get("/weather").WeatherCondition end
    function fibaro.weather.conditionCode() return api.get("/weather").ConditionCode end
  end
} -- Weather

