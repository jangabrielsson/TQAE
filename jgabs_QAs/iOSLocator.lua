-- luacheck: globals ignore QuickAppBase QuickApp QuickAppChild quickApp fibaro class
-- luacheck: globals ignore plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator __fibaro_get_device_property

local _=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { 
    onAction=true, http=false, UIEevent=true 
  },
}

--%%name = "iOSLocator"
--%%type='com.fibaro.binarySensor'
--%%quickVars = {['HomeVar'] = 'iOSHome',['HomeName'] = 'Home',['AwayName'] = 'Away',}
--%%u1={label='version', text=''}
--%%u2={label='home', text=''}
--%%u3={label='user', text=''}

--FILE:lib/fibaroExtra.lua,fibaroExtra;
--FILE:jgabs_QAs/iOSLocatorEngine.lua,iOSLocator;

DEBUG = {
  listDevices = true,
  matchedDevice = true,
}
---------------------- Setup users -----------------------------
ACCOUNTS = {      -- Fill in with iOS credentials
  {
    icloud={user="XXXX1", pwd=".."}, -- iCloud account, user is icloud email account. pwd is icloud account password
    devices = {
      {
        deviceName='iPhone',  -- Is used to match against deviceName from icloud to find right phone
        deviceType='XS',      -- Used to match against the deviceType of from icloud. Defaults to '.*' that match everything
        name='Bob',           -- Name of user for this device
        id=2,                 -- HC3 user id. If not an HC3 user, assign your own id not conflicting with existing HC3 ids. Leave empty to auto assign an id.
        home=true,            -- true if user is considered as part of the people living at home. 
        QA="Bob's iPhone",    -- If set will generate a QA child device (binarySensor) representing the user 
        global="iOS_BOB"      -- If set will update fibaro global variable will state of user
      },
      {                       -- This is another user sharing the same icloud account but another device (ex. a child)
        deviceName='iPhone',  -- It can also be used to track multiple devices for the same account. Note that they need different names. Ex. Bob_iPhone, Bob_watch
        deviceType='iPhone 6S', 
        name='Tim', 
        home=true, 
        QA=true,               -- Will use name (Tim) as name of QA
        global=true            -- Will use "iOS_"..name as name of global variable
      },
    }
  },
  {
    icloud={user="XXXX2", pwd=".."}, -- iCloud account
    devices = {
      {deviceName='iPhone', name='Ann', id=3, home=true}, -- No QA
    }
  },
  {
    icloud={user="XXXX3", pwd=".."}, -- iCloud account
    devices = {
      {
        name='Max', home=false,      -- Family member not living at home (not counted in "all at home")
        deviceName='Apple Watch', 
        deviceType='Apple Watch Series 6 %(GPS%)',   -- Apple watch of specific model
      },  
    }
  },
}
HC3USERS = {
  {
    deviceName='OtherPhone',   -- Not really used
    name='Lisa', 
    id=5,                      -- id must be HC3 user id.
    home=true                  -- Part of the home-crew...
  } 
}

SCHEDULE_TIME = 90 -- seconds
SCHEDULE_INTERVAL = false -- true=delay SCHEDULE_TIME between each account poll, false=delay SCHEDULE_TIME/#accounts between each account poll
SCHEDULE_KEEP_TOGETHER = {} -- {{'XXXX1','XXXX2'}} -- poll these accounts together - beware that it can be throttled by Apple if polled too often

--[[

quickAppVariables:
'HomeName' = name of place that is home. Normally we want to map "HC3-000023" to something more readable like "Home"
'AwayName' = name of place that is not at a place. Defaults to "Away"
'HomeVar' = name of global where home status is stored -- If nil, not used.
'status' = Name of QA variable where all location info is stored

--]]

