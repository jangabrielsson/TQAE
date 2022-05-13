--[[
TQAE - Tiny QuickApp emulator for the Fibaro Home Center 3
Copyright (c) 2021 Jan Gabrielsson
Email: jan@gabrielsson.com
MIT License

Support for local shadowing global variables, rooms, sections, customEvents - and other resources

--]]
local EM,_ = ...

local HC3Request = EM.HC3Request

local rsrc = {
  rooms = {},
  sections={},
  globalVariables={},
  customEvents={},
  devices = {},
  ['settings/localtion'] = {},
  ['settings/info'] = {},
  ['settings/led'] ={ },
  ['settings/network'] = {},
  ['alarms/v1/partitions'] = {},
  ['alarms/v1/devices'] = {},
  notificationCenter = {},
  profiles = {},
  users = {},
  icons = {},
  weather = {},
  debugMessages = {},
  home = {},
  iosDevices = {},
  ['energy/devices'] = {},
  ['panels/location'] = {},
  ['panels/notifications'] = {},
  ['panels/family'] = {},
  ['panels/sprinklers'] = {},
  ['panels/humidity'] = {},
  ['panels/favoriteColors'] = {},
  diagnostics = {},
  sortOrder = {},
  loginStatus = {},
  RGBprograms = {},
}

EM.rsrc = rsrc

rsrc['settings/location'] = {
  city = "Berlin",
  latitude = 52.520008,
  longitude = 13.404954,
}

rsrc['settings/info'] = {
  serialNumber = "HC3-00000999",
  platform = "HC3",
  zwaveEngineVersion = "2.0",
  hcName = "HC3-00000999",
  mac = "ac:17:02:0d:35:c8",
  zwaveVersion = "4.33",
  timeFormat = 24,
  zwaveRegion = "EU",
  serverStatus = os.time(),
  defaultLanguage = "en",
  defaultRoomId = 219,
  sunsetHour = "15:23",
  sunriseHour = "07:40",
  hotelMode = false,
  temperatureUnit = "C",
  batteryLowNotification = false,
  date = "09:53 | 15.11.2021",
  dateFormat = "dd.mm.yy",
  decimalMark = ".",
  timezoneOffset = 3600,
  currency = "EUR",
  softVersion = "5.090.17",
  beta = false,
  currentVersion = {
    version = "5.090.17",
    type = "stable"
  },
  installVersion = {
    version = "",
    type = "",
    status = "",
    progress = 0
  },
  timestamp = os.time(),
  online = false,
  tosAccepted = true,
  skin = "light",
  skinSetting = "manual",
  updateStableAvailable = false,
  updateBetaAvailable = false,
  newestStableVersion = "5.090.17",
  newestBetaVersion = "5.000.15",
  isFTIConfigured = true,
  isSlave = false,
}

rsrc.users = {
  [2] = {
    id = 2,
    name = "admin",
    type = "superuser",
    email = "foo@bar.com",
    deviceRights =  {},
    sceneRights =  {},
    alarmRights =  {},
    profileRights =  {},
    climateZoneRights =  {},
  }
}

rsrc['panels/location'] = {
  [6] = {
    id =  6,
    name =  "My Home",
    address =  "Serdeczna 3, Wysogotowo",
    longitude =  16.791597,
    latitude =  52.404958,
    radius =  150,
    home =  true,
  }
}

rsrc.weather = {
  Temperature=  3.1,
  TemperatureUnit=  "C",
  Humidity=  51.4,
  Wind=  29.52,
  WindUnit=  "km/h",
  WeatherCondition=  "clear",
  ConditionCode=  32
}


local profileData = { activeProfile = 1, profiles = {}}
for i,name in ipairs({'Home','Away','Vacation','Night'}) do
  profileData.profiles[#profileData.profiles+1]={
    id = i,
    name = name,
    iconId = 1,
    devices =  {
    },
    scenes =  { },
    climateZones =  { },
    partitions =  { }
  }
end
EM.rsrc.profiles  =  profileData

---------------- Profile  handling ---------------------
local function profileInfo(method,client,data,opts,id)
  if method=='GET' and id==nil then return profileData,200 end
  if method=='GET' and id then
    for _,p in ipairs(profileData.profiles) do
      if p.id == id then return p,200 end
    end
    return nil,404
  end
  if method == "PUT" and type(data)=='table' then
    local old = profileData.activeProfile
    local id = data.activeProfile or old
    if old ~= id then
      EM.addRefreshEvent({
          type='ActiveProfileChangedEvent',
          created = EM.osTime(),
          data={newActiveProfile=id, oldActiveProfile=old}
        })
    end
    profileData = data
    return data,200
  end
  return 500,nil
end

local function profileSet(method,client,data,opts,id)
  if method=='POST' and tonumber(id) then
    local old = profileData.activeProfile
    profileData.activeProfile=id
    if old ~= id then
      EM.addRefreshEvent({
          type='ActiveProfileChangedEvent',
          created = EM.osTime(),
          data={newActiveProfile=id, oldActiveProfile=old}
        })
    end
    return id,200
  else return nil,500 end
end
------------------------------

local function notificationCenter(method,client,data,opts,id)
  if method=='POST' then
    data = data.data
    print(string.format("Notification: ID:%s, %s - %s",data.deviceId, data.title,data.text))
  end
end

--------------------------------
local  primaryController  = {
  id= 1,
  name = "zwave",
  roomID = 219,
  type = "com.fibaro.zwavePrimaryController",
  baseType = "",
  enabled = true,
  properties = {
    sunriseHour = "08:40",
    sunsetHour = "15:08",
  },
}

local function setup()

  rsrc.devices[1] = primaryController
  EM.create.room{id=219,name="Default Room"}
  EM.create.section{id=219,name="Default Section"}

  if EM.cfg.location then rsrc.settings.location = EM.cfg.location  end

  -- Intercept some useful APIs...
  local function map2arr(t) local r={}; for k,v in pairs(t) do r[#r+1]=v end return r end

  EM.addAPI("GET/settings/location",function() return rsrc['settings/location'],200 end)
  EM.addAPI("GET/settings/info",function() return rsrc['settings/info'],200 end)
  EM.addAPI("GET/alarms/v1/partitions",function() return rsrc['alarms/v1/partitions'],200 end)
  EM.addAPI("GET/alarms/v1/devices",function() return rsrc['alarms/v1/devices'],200 end)
  EM.addAPI("GET/notificationCenter",function() return rsrc.notificationCenter,200 end)
  EM.addAPI("POST/notificationCenter",notificationCenter)
  EM.addAPI("GET/profiles",profileInfo)
  EM.addAPI("PUT/profiles",profileInfo)
  EM.addAPI("GET/profiles/#id",profileInfo)
  EM.addAPI("POST/profiles/activeProfile/#id",profileSet)
  EM.addAPI("GET/weather",function() return rsrc.weather,200 end)
  EM.addAPI("GET/debugMessages",function() return rsrc.debugMessages,200 end)
  EM.addAPI("GET/home",function() return rsrc.home,200 end)
  EM.addAPI("GET/icons",function() return map2arr(rsrc.icons),200 end)
  EM.addAPI("GET/iosDevices",function() return map2arr(rsrc.iosDevices),200 end)
  EM.addAPI("GET/energy/devices",function() return rsrc['energy/devices'],200 end)
end

EM.shadow={}
for _,name in  ipairs({'globalVariables','rooms','sections','customEvents'}) do
  EM.shadow[name]=function(id)
    if EM.cfg.offline or EM.cfg.shadow and EM.rsrc[name][id] then return end
    if EM.cfg.shadow then
      EM.rsrc[name][id] = HC3Request("/"..name.."/"..id)
    end
  end
end

local roomID = 1001
local sectionID = 1001

EM.create = EM.create or {}
function EM.create.globalVariable(args)
  local v = {
    name=args.name,
    value=args.value,
    modified=EM.osTime(),
  }
  EM.rsrc.globalVariables[args.name]=v
  EM.addRefreshEvent({
      type='GlobalVariableAddedEvent',
      created = EM.osTime(),
      data={variableName=args.name, value=v}
    })
  return v,v.name
end

function EM.create.room(args)
  local v = {
    name = "Room",
    sectionID = EM.cfg.defaultSection or 219,
    isDefault = true,
    visible = true,
    icon = "",
    defaultSensors = { temperature = 0, humidity = 0, light = 0 },
    meters = { energy = 0 },
    defaultThermostat = 0,
    sortOrder = 1,
    category = "other"
  }
  for _,k in ipairs(
    {"id","name","sectionID","isDefault","visible","icon","defaultSensors","meters","defaultThermostat","sortOrder","category"}
    ) do v[k] = args[k] or v[k]
  end
  if not v.id then v.id = roomID roomID=roomID+1 end
  EM.rsrc.rooms[v.id]=v
  return v
end

function EM.create.section(args)
  local v = {
    name = "Section" ,
    sortOrder = 1
  }
  for _,k in ipairs({"id","name","sortOrder"}) do v[k] = args[k] or v[k]  end
  if not v.id then v.id = sectionID sectionID=sectionID+1 end
  EM.rsrc.sections[v.id]=v
  return v
end

function EM.create.customEvent(args)
  local v = { name=args.name, userDescription=args.userDescription or "" }
  EM.rsrc.customEvents[v.id]=v
  return v
end

function EM.create.user(args)
  local u = {} for k,v in  pairs(args) do u[k]=v end
  EM.rsrc.users[u.id]=u
  return u
end

EM.create['panels/location'] = function(args)
  local u = {} for k,v in  pairs(args) do u[k]=v end
  EM.rsrc['panels/location'][u.id]=u
  return u
end

EM.create.globalVariables = EM.create.globalVariable

EM.EMEvents('start',function(_)
    if EM.cfg.offline then setup() end
  end)
