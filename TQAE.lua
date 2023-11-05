--[[
TQAE - Tiny QuickApp emulator for the Fibaro Home Center 3
Copyright (c) 2021 Jan Gabrielsson
Email: jan@gabrielsson.com
                    GNU GENERAL PUBLIC LICENSE
                       Version 3, 29 June 2007

 Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.

Sources included:
json           -- Copyright (c) 2019 rxi
persistence    -- Copyright (c) 2010 Gerhard Roethlin
file functions -- Credit pkulchenko - ZeroBraneStudio
copas          -- Copyright 2005-2016 - Kepler Project (www.keplerproject.org)
timerwheel     -- Credit https://github.com/Tieske/timerwheel.lua/blob/master/LICENSE
binaryheap     -- Copyright 2015-2019 Thijs Schreijer
LuWS           -- Copyright 2020 Patrick H. Rigney, All Rights Reserved. http://www.toggledbits.com/LuWS

Thanks for bug reports and suggestions:
@ChristianSogaard forum.fibaro.com
@Joep forum.fibaro.com (See also https://docs.joepverhaeg.nl/hc3-tqae/)

--]]

--[[
Emulator options: (set in the header _=loadfile and loadfile("TQAE.lua"){...} )
user=<user>
  Account used to interact with the HC3 via REST api
pwd=<Password>
  Password for account used to interact with the HC3 via REST api
host=<IP address>
  IP address of HC3
configFile = <filename>
  File used to load in emulator options instead of specifying them in the QA file.
  Great place to keep credentials instead of listing them in the QA code, and forget to remove them when uploading codeto forums...
  Default "TQAEconfigs.lua"
modPath = <path>,
  Path to TQAE modules.
  Default "modules/"
temp = <path>
  Path to temp directory.
  Default "temp/"
startTime=<time string>
  Start date for the emulator. Ex. "12/24/2024-07:00" to start emulator at X-mas morning 07:00 2024.
  Default, current local time.
copas=<boolean>
   If true will use the copas scheduler.
   Default true.
noweb=<boolean>
   If true will not start up local web interface.
   Default false
debug={
  html=<boolean>,
  -- If false will strip html formatting from the log output. Default true
  color=<boolean>,
  -- If true will log in ZBS console with color. Default true
  lateTimer=<seconds>
  -- If set to a value will be used to notify if timers are late to execute. Default false
  verboseTimer=<boolean>
  -- If true prints timer reference with extended information (expiration time etc). Default true
  traceFibaro=<boolean>,
  --If true logs fibaro calls. Default 'call','getValue'
  qa=<boolean>,
  -- If true logs QA creation related events. Default true
  module=<boolean>,
  -- If true logs module loading related events. Defaul true
  module2=<boolean>,       --defaul false
  lock=<boolean>,
  -- If true logs internal thread lock events.
  child=<boolean>,
  -- If true logs child creation related events.
  device=<boolean>,
  -- If true logs device creation related events.
  refreshStates=<boolean>,
  -- If true logs incoming events from refreshStates loop.
  webserver=<boolean>,
  -- If true logs internal webserver incoming requests
}

QuickApp options: (set with --%% directive in file)
--%%name=<name>
--%%id=<number>
--%%type=<com.fibaro.XYZ>
--%%properties={<table of initial properties>}
--%%interfaces={<array of interfaces>}
--%%quickVars={<table of initial quickAppVariables>}   -- Ex. { x = 9, y = "Test" }
--%%proxy=<boolean>
--]]

local embedded = ... -- get parameters if emulator included from QA code...
local version = "0.60"
local EM = { cfg = embedded or {} }
local cfg, pfvs = EM.cfg, nil

local win = (os.getenv('WINDIR') or (os.getenv('OS') or ''):match('[Ww]indows')) and
    not (os.getenv('OSTYPE') or ''):match('cygwin')
cfg.arch = win and "Windows" or "Linux"
cfg.pathSeparator = cfg.arch == "Windows" and "\\" or "/"
local _ps = cfg.pathSeparator
local function addPath(p, front) package.path = front and (p .. ";" .. package.path) or (package.path .. ";" .. p) end
addPath("." .. _ps .. "modules" .. _ps .. "?", true)
addPath("." .. _ps .. "modules" .. _ps .. "/?.lua", true)
local function mkPath(...) return table.concat({ ... }, cfg.pathSeparator) end

local function DEF(x, y) if x == nil then return y else return x end end
cfg.root         = DEF(cfg.root, "")
cfg.modPath      = DEF(cfg.modpath, mkPath("modules", ""))     -- Path to modules
cfg.modPath = cfg.root .. cfg.modPath
cfg.configFile    = DEF(cfg.configFile, "TQAEconfigs.lua")
EM.readConfigFile = cfg.configFile
do
  EM.configFileValues = {}
  local pf, _ = loadfile(cfg.root..cfg.configFile)
  if pf then
    local p = pf() or {};
    assert(type(p) == 'table', "Bad format for configuration file")
    EM.configFileValues = pf()             -- Get copy of config values for settings panel
    pfvs = true
    for k, v in pairs(cfg) do p[k] = v end -- Overwrite config values with values from file header
    cfg, EM.cfg = p, p
  end
end

EM.mkPath = mkPath
if package.cpath:match("[Zz]ero[bB]rane[sS]tudio") then
  cfg.editor = "ZB"
else
  cfg.editor = "VSC"
end
                                                      -- directory where TQAE modules are stored
cfg.temp         = DEF(cfg.temp, os.getenv("TMPDIR") or os.getenv("TEMP") or os.getenv("TMP") or mkPath("temp", "")) -- temp directory
cfg.defaultRoom  = DEF(cfg.defaultRoom, 219)
EM.utilities     = dofile(cfg.modPath .. "utilities.lua")
EM.debugFlags    = DEF(cfg.debug, { qa = true, child = true, device = true })

local debugFlags = EM.debugFlags
debugFlags.html  = DEF(debugFlags.html, true)
debugFlags.color = DEF(debugFlags.color, true)
local fibColors  = DEF(cfg.fibColors,
  { ["DEBUG"] = 'green', ["TRACE"] = 'blue', ["WARNING"] = 'orange', ["ERROR"] = 'red' })
local logColors  = DEF(cfg.logColors, { ["SYS"] = 'brown', ["ERROR"] = 'red', ["WARN"] = 'orange', ["TRACE"] = 'blue' })
if debugFlags.dark then
  fibColors['TEXT'] = fibColors['TEXT'] or 'white'
  logColors['TEXT'] = logColors['TEXT'] or 'white'
end

EM.utilities.colorMap  = DEF(cfg.colorMap, {})

local globalModules    = { -- default global modules loaded once into emulator environment
  "net.lua", "json.lua", "files.lua", "webserver.lua", "api.lua", "proxy.lua", "ui.lua", "offline.lua", "time.lua",
  "refreshStates.lua", "stdQA.lua", "Scene.lua", "settings.lua",
}
local localModules     = { -- default local modules loaded into every QA environment
  { "class.lua", "QA" }, "fibaro.lua", "fibaroPatch.lua", { "QuickApp.lua", "QA" }, { "bit32.lua", "QA" }
}

EM.EMURUNNING          = "TQAE_running"
EM.EMURUNNING_INTERVAL = 4
--EM.cfg.copas = true
--EM.cfg.noweb=true
local function main(FB)                                                           -- For running test examples. Running TQAE.lua directly will run this test.
  if not cfg.NOVERIFY then
    local et, res = loadfile(cfg.root .. mkPath("setup", "verify", "verify.lua")) -- more extensive tests.
    if et then et(EM, FB) else error(res) end
  else
    EM.startEmulator(nil)
  end
end

---------------------------------------- TQAE -------------------------------------------------------------
do
  local stat, mobdebug = pcall(require, 'mobdebug'); -- If we have mobdebug, enable coroutine debugging
  if stat then
    local fid = function() end
    EM.mobdebug = stat and mobdebug or { coro = fid, pause = fid, setbreakpoint = fid, on = fid, off = fid }
    mobdebug.coro()
  end
end

local socket                                               = require("socket")
local http                                                 = require("socket.http")
local https                                                = require("ssl.https")
local ltn12                                                = require("ltn12")

-- Modules
-- FB.x exported native fibaro functions. Ex- __fibaro_get_device, setTimeout etc. Plugins can add to this, ex. net.*
-- EM.x internal emulator functions, HTTP, LOG etc. Plugins can add to this...

local FB, Devices                                          = {}, {} -- id->Device map
local Utils                                                = EM.utilities
local fmt, gID, setTimeout, LOG, DEBUG, loadModules, runQA = string.format, 1001, nil, nil, nil, nil, nil
local format, deepCopy, merge, member                      = string.format, Utils.deepCopy, Utils.merge, Utils.member
EM.http, EM.https                                          = http, https
EM._info                                                   = { modules = { ["local"] = {}, global = {} } }

-- luacheck: ignore 142
------------------------ Builtin functions ------------------------------------------------------

local function httpRequest(reqs, extra)
  local resp, req, status, h, resetTimeout, timeout, _ = {}, {}, nil, nil, nil, nil, nil
  for k, v in pairs(extra or {}) do req[k] = v end
  ; for k, v in pairs(reqs) do req[k] = v end
  req.sink, req.headers = ltn12.sink.table(resp), req.headers or {}
  req.headers["Accept"] = req.headers["Accept"] or "*/*"
  req.headers["Content-Type"] = req.headers["Content-Type"] or "application/json"
  if req.timeout then timeout = req.timeout / 1000 end
  if cfg.copas and EM.copas then
    req.timeout = timeout
  else
    resetTimeout, EM.http.TIMEOUT = EM.http.TIMEOUT, timeout
  end
  if req.method == "PUT" or req.method == "POST" then
    req.data = req.data or "[]"
    req.headers["content-length"] = #req.data
    req.source = ltn12.source.string(req.data)
  else
    req.headers["Content-Length"] = 0
  end
  --  req.url = uriEncode(req.url)
  if req.url:sub(1, 5) == "https" then
    _, status, h = EM.https.request(req)
  else
    _, status, h = EM.http.request(req)
  end
  if resetTimeout then EM.http.TIMEOUT = resetTimeout end
  if tonumber(status) and status < 300 then
    return resp[1] and table.concat(resp) or nil, status, h
  else
    return nil, status, h, resp
  end
end

local base = "http://" .. (EM.cfg.host or "") .. "/api"
local function HC3Request(method, path, data, extra)
  if EM.cfg.readOnly and method ~= "GET" then return nil, 501 end
  local req = {
    method = method,
    url = (extra and extra.base or base) .. path,
    user = EM.cfg.user,
    password = EM.cfg.pwd,
    data = data and FB.json.encode(data),
    timeout = 15000,
    headers = { ["Accept"] = '*/*', ["X-Fibaro-Version"] = 2, ["Fibaro-User-PIN"] = EM.cfg.pin },
  }
  for k, v in pairs(extra or {}) do req[k] = v end
  local res, stat, headers, _ = httpRequest(req)
  if res ~= nil then
    local a, b = pcall(FB.json.decode, res)
    if a then
      return b, stat, headers
    else
      LOG.error("Bad HC3 call: %s", path)
      return nil, 500, headers
    end
  else
    if tonumber(stat) and (stat > 400 and stat < 403) then
      LOG.error("Bad credential when logging in to HC3, exiting to avoid account lockout")
      os.exit()
    end
    if tonumber(stat) and stat > 209 then
      DEBUG("api", "error", "Bad HC3 call: %s (%s)", path, stat)
    end
    return nil, stat, headers
  end
end

local function __assert_type(value, typeOfValue)
  if type(value) ~= typeOfValue then -- Wrong parameter type, string required. Provided param 'nil' is type of nil
    error(fmt("Wrong parameter type, %s required. Provided param '%s' is type of %s",
        typeOfValue, tostring(value), type(value)),
      3)
  end
end
function EM.escapeURI(str)
  return str:gsub("[%s%(%)%-%_%/]", function(c) return format("%%% 02X", string.byte(c)) end)
end

function FB.__ternary(test, a1, a2) if test then return a1 else return a2 end end

-- Most __fibaro_x functions defined in api.lua
function FB.__fibaro_get_partition(id) return HC3Request("GET", '/alarms/v1/partitions/' .. id) end

function FB.__fibaroUseAsyncHandler(_) end -- TBD

-- Non standard
function FB.__fibaro_call(id, name, path, data)
  local args, D = data.args or {}, Devices[id]
  if D then -- sim. call in another process/QA
    setTimeout(function()
      D.env.onAction(id, { deviceId = id, actionName = name, args = args })
    end, 0, nil, D)
    return { message = "Accepted" }, 200
  elseif not cfg.offline then
    return HC3Request("POST", path, data)
  else
    return nil, 404
  end
end

function FB.__fibaro_call_UI(id, name, typ, values)
  local D = Devices[id]
  if D then -- sim. call in another process/QA -- onUIEvent(id,{deviceId=id,elementName=btn,eventType='onReleased',values={}})
    return setTimeout(function()
      D.env.onUIEvent(id, {
        deviceId = id,
        elementName = name,
        eventType = typ,
        values =
            values
      })
    end, 0, nil, D)
  end
end

function FB.__fibaro_local(bool)
  local l = EM.locl == true; EM.locl = bool; return l
end

local html2color, ANSICOLORS, ANSIEND = Utils.html2color, Utils.ZBCOLORMAP, Utils.ZBCOLOREND

function FB.__fibaro_add_debug_message(tag, str, typ)
  assert(str, "Missing tag for debug")
  typ = typ:upper()
  str = debugFlags.html and html2color(str, nil, fibColors['TEXT']) or str:gsub("(</?font.->)", "") -- Remove color tags
  typ = debugFlags.color and (ANSICOLORS[(fibColors[typ] or "black")] .. typ .. ANSIEND) or typ
  str = str:gsub("(&nbsp;)", " ")                                                                   -- remove html space
  if debugFlags.color then
    local tcolor = ANSICOLORS[(fibColors['TEXT'] or "black")]
    print(fmt("%s%s [%s%s] [%s]: %s%s", tcolor, EM.osDate("[%d.%m.%Y] [%H:%M:%S]"), typ, tcolor, tag, str, ANSIEND))
  else
    print(fmt("%s [%s] [%s]: %s", EM.osDate("[%d.%m.%Y] [%H:%M:%S]"), typ, tag, str))
  end
end

local function _LOG(typ, ...)
  if debugFlags.color then
    local colorCode = ANSICOLORS[logColors[typ] or 'black']
    local textColor = ANSICOLORS[logColors['TEXT'] or 'black']
    print(fmt("%s%s |%s%-5s|%s %s%s%s", textColor, EM.osDate("[%d.%m.%Y] [%H:%M:%S]"), colorCode, typ, ANSIEND, textColor,
      fmt(...), ANSIEND))
  else
    print(fmt("%s |%-5s| %s", EM.osDate("[%d.%m.%Y] [%H:%M:%S]"), typ, fmt(...)))
  end
end
LOG = { flags = {}, descr = {} }
function LOG.sys(...) _LOG("SYS", ...) end

function LOG.warn(...) _LOG("WARN", ...) end

function LOG.error(...) _LOG("ERROR", ...) end

function LOG.trace(...) _LOG("TRACE", ...) end

function DEBUG(flag, typ, ...)
  LOG.register(flag, LOG.descr[flag]); if debugFlags[flag] then LOG[typ](...) end
end

function LOG.register(fl, descr)
  LOG.flags[fl] = true
  LOG.descr[fl] = descr
end

function LOG.registerList(fl) for _, f in ipairs(fl) do LOG.register(f) end end

LOG.register("color", "If true will log in ZBS console with color")
LOG.register("html", "If false will strip html formatting from the log output")
LOG.register("lateTimer", "If set to a value will be used to notify if timers are late to execute")
LOG.register("verboseTimer", "If true prints timer reference with extended information (expiration time etc)")
LOG.register("onAction", "Logs onAction events")
LOG.register("onUIEvent", "Logs UI events")
LOG.register("traceFibaro", "Logs fibaro.* calls")
LOG.register("module", "Log loaded module")
LOG.register("qa", "Log loaded QAs")
LOG.register("device", "Log device creation events")
LOG.register("lock", "Log thread lock operations")
LOG.register("child", "Log QuickAppChild creation events")

function FB.urldecode(str) return str and str:gsub('%%(%x%x)', function(x) return string.char(tonumber(x, 16)) end) end

function FB.urlencode(str)
  return str and
      str:gsub("([^% w])", function(c) return string.format("%%% 02X", string.byte(c)) end)
end

function string.split(str, sep)
  local fields, s = {}, sep or "%s"
  str:gsub("([^" .. s .. "]+)", function(c) fields[#fields + 1] = c end)
  return fields
end

function loadModules(ms, env, isScene, args)
  ms = type(ms) == 'table' and ms or { ms }
  local stat, res = pcall(function()
    for _, m in ipairs(ms) do
      if type(m) == 'table' then m, args = m[1], m[2] else args = nil end
      if not (args == 'QA' and isScene) then
        DEBUG("module", "sys", "Loading  %s module %s", env and "local" or "global", m)
        EM._info.modules[env and "local" or "global"][m] = true
        local code, res = loadfile(EM.cfg.modPath .. m, "t", env or _G)
        assert(code, res)
        code(EM, FB, args or {})
      end
    end
  end)
  if not stat then error("Loading module " .. res) end
end

local offset = 0
function EM.setTimeOffset(offs) if offs then offset = offs else return offset end end

function EM.clock() return socket.gettime() + offset end

function EM.osTime(a) return a and os.time(a) or math.floor(os.time() + offset + 0.5) end

function EM.osDate(a, b) return os.date(a, b or EM.osTime()) end

local EMEvents = {}
function EM.EMEvents(typ, callback, front)
  local evs = EMEvents[typ] or {}
  if front then table.insert(evs, 1, callback) else evs[#evs + 1] = callback end
  EMEvents[typ] = evs
end

function EM.postEMEvent(ev) for _, m in ipairs(EMEvents[ev.type] or {}) do m(ev) end end

EM.LOG, EM.DEBUG, EM.httpRequest, EM.HC3Request, EM.socket = LOG, DEBUG, httpRequest, HC3Request, socket
EM.Devices = Devices
FB.__assert_type = __assert_type

function FB.setInterval(fun, ms)
  local r = {}
  local function loop()
    fun()
    if r[1] then r[1] = FB.setTimeout(loop, ms) end
  end
  r[1] = FB.setTimeout(loop, ms)
  return r
end

function FB.clearInterval(ref)
  if type(ref) == 'table' and ref[1] then
    FB.clearTimeout(ref[1])
    ref[1] = nil
  end
end

local function milliStr(t)
  return os.date("%H:%M:%S", math.floor(t)) .. string.format(":%03d", math.floor((t % 1) * 1000 +
    0.5))
end
EM.milliStr = milliStr

local timer2str = {
  __tostring = function(t)
    if debugFlags.verboseTimer then
      local ctx = t.ctx
      return fmt("<%s %s(%s), expires=%s>", t.descr, ctx.env.__TAG, ctx.id or 0, milliStr(t.time))
    else
      return t.descr
    end
  end
}
function EM.makeTimer(time, co, ctx, tag, ft, args)
  return setmetatable({ time = time, co = co, ctx = ctx, tag = tag, fun = ft, args = args, descr = tostring(co) },
    timer2str)
end

function EM.timerCheckFun(t)
  local now = EM.clock()
  if (now - t.time) >= (tonumber(debugFlags.lateTimer) or 0.5) then
    LOG.warn("Late timer %.3f - %s", now - t.time, t)
  end
end

------------------------ Emulator functions ------------------------------------------------------
local weakKeys = { __mode = 'k' }
local procs    = setmetatable({}, weakKeys)

local function getContext(co) return procs[co or coroutine.running()] end
EM.getContext, EM.procs = getContext, procs

FB.json = { decode = function(s) return s end } -- Need fake json at this moment, will be replaced when loading json.lua
if not cfg.offline and not HC3Request("GET", "/settings/info", nil, { timeout = 3000 }) then cfg.offline = "NOHC3" end

if EM.cfg.copas then loadfile(EM.cfg.modPath .. "async.lua")(EM, FB) else loadfile(EM.cfg.modPath .. "sync.lua")(EM, FB) end
setTimeout = EM.setTimeout
FB.setTimeout = EM.setTimeout
FB.clearTimeout = EM.clearTimeout

function FB.type(o)
  local t = type(o)
  return t == 'table' and o._TYPE or t
end

-- Check arguments and print a QA error message
local function check(name, stat, err)
  if type(err) == 'table' then return end
  if stat==nil then
    err = err:gsub('(%[string ")(.-)("%])', function(_, s, _) return s end)
    FB.__fibaro_add_debug_message(name, err, "ERROR")
  end
  return stat, err
end
EM.checkErr = check

function EM.getQA(id)
  local D = Devices[tonumber(id) or 0]
  if not D then return end
  if D.dev.parentId == 0 then
    return D.env.quickApp, D.env, true
  else
    return D.env.quickApp.childDevices[id], D.env, false
  end
end

EM.EMEvents('QACreated', function(_) -- Register device and clean-up when QA is created
  --local qa,dev = ev.qa,ev.dev
end)

function EM.createDevice(info) -- Creates device structure
  local typ = info.type or "com.fibaro.binarySensor"
  local deviceTemplates = EM.getDeviceResources()
  local dev = deviceTemplates[typ] and deepCopy(deviceTemplates[typ]) or {
    properties = {},
    type = typ,
    actions = { turnOn = 0, turnOff = 0, setValue = 1, toggle = 0 }
  }
  dev.properties.viewLayout, dev.properties.uiCallbacks = nil, nil
  if info.parentId and info.parentId > 0 then
    local p = Devices[info.parentId]
    info.env, info.childProxy = p.env, p.proxy
    if info.childProxy then DEBUG("child", "sys", "Imported proxy child %s", info.id) end
  end

  dev.name, dev.parentId, dev.roomID = info.name or "MyQuickApp", 0, info.roomID or EM.cfg.defaultRoom
  dev.interfaces = dev.interfaces or {}
  dev.properties = dev.properties or {}
  merge(dev.interfaces, info.interfaces or {})
  merge(dev.properties, info.properties or {})
  info.dev = dev
  EM.addUI(info)

  if not cfg.offline then
    assert(not (info.proxy and info.zombie), "Can't have both proxy and zombie")
    if info.proxy and not (EM.cfg.noproxy) then -- Move out?
      local l = FB.__fibaro_local(false)
      local stat, res = pcall(EM.createProxy, dev)
      FB.__fibaro_local(l)
      if not stat then
        LOG.error("Proxy: %s", res)
        info.proxy = false
      else
        info.id = res.id
      end
    elseif info.zombie then
      if not info.id then
        info.id = gID; gID = gID + 1
      end
      if EM.injectProxy(info.zombie, info.id) then EM.startProxyPinger() end
    end
  end

  if not info.id then
    info.id = gID; gID = gID + 1
  end
  dev.id = info.id
  return dev
end

local function extractInfo(file, code, args) -- Creates info structure from file/code
  local files, info = EM.loadFile(code, file, args)
  info.properties = info.properties or {}
  info.properties.quickAppVariables = info.properties.quickAppVariables or {}
  for k, v in pairs(info.quickVars or {}) do table.insert(info.properties.quickAppVariables, 1, { name = k, value = v }) end
  info.name, info.type = info.name or "MyQuickApp", info.type or "com.fibaro.binarySwitch"
  info.files, info.fileMap, info.codeType = files, {}, "QA"
  for _, f in ipairs(info.files) do if not info.fileMap[f.name] then info.fileMap[f.name] = f end end
  local lock = EM.createLock()
  info.timers, info._lock = {}, lock
  info.lock = {
    get = function()
      DEBUG("lock", "trace", "GET(%s) %s", info.id, coroutine.running())
      lock:get()
      DEBUG("lock", "trace", "GOT(%s) %s", info.id, coroutine.running())
    end,
    release = function()
      DEBUG("lock", "trace", "RELEASE(%s) %s", info.id, coroutine.running())
      lock:release()
    end
  }
  return info
end

local function createQA(args) -- Create QA/info struct from file or code string.
  local info = extractInfo(args.file, args.code, args)
  for _, p in ipairs({ "id", "name", "type", "properties", "interfaces" }) do
    if args[p] ~= nil then info[p] = args[p] end
  end
  EM.createDevice(info) -- assignes info.dev = dev
  return info
end

local function installDevice(info) -- Register device
  local dev = info.dev
  Devices[dev.id] = info
  DEBUG("device", "sys", "Created %s device %s", (member('quickAppChild', info.interfaces or {}) and "child" or ""),
    dev.id)
  EM.postEMEvent({ type = 'deviceInstalled', info = info })
  return dev
end
EM.installDevice = installDevice

function EM.installQA(args, cont)
  runQA(installDevice(createQA(args)).id,
    function()
      LOG.sys("End - runtime %.2f min", (EM.osTime() - EM._info.started) / 60)
      EM._info.started = EM.osTime()
      if cont then cont() else os.exit() end
    end)
end

local LOADLOCK = EM.createLock()

function runQA(id, cont) -- Creates an environment and load file modules and starts QuickApp (:onInit())
  local info, co = Devices[id], coroutine.running()
  info.cont = cont
  local env = {
    -- QA environment, all Lua functions available for  QA,
    plugin = { mainDeviceId = info.id },
    os = {
      time = EM.osTime, date = EM.osDate, clock = os.clock, difftime = os.difftime, exit = EM.exit
    },
    hc3_emulator = {
      getmetatable = getmetatable,
      setmetatable = setmetatable,
      io = io,
      installQA = EM.installQA,
      EM = EM,
      IPaddress = EM.IPAddress,
      os = { setTimer = setTimeout, exit = os.exit, getenv = os.getenv, remove = os.remove },
      trigger = EM.trigger,
      create = EM.create,
      rawset = rawset,
      rawget = rawget,
      registerURL = EM.registerURL,
      webPort = EM.webPort,
    },
    coroutine = EM.userCoroutines,
    table = table,
    select = select,
    pcall = pcall,
    xpcall = xpcall,
    print = print,
    string = string,
    error = error,
    collectgarbage = collectgarbage,
    unpack = table.unpack,
    utf8 = utf8,
    next = next,
    pairs = pairs,
    ipairs = ipairs,
    tostring = tostring,
    tonumber = tonumber,
    math = math,
    assert = assert,
    getmetatable = getmetatable,
    setmetatable = setmetatable,
  }
  if info.fullLUA then
    EM._createQA = createQA
    for _, f in ipairs({ "require", "load", "dofile", "io", "socket" }) do env[f] = _G[f] end
    env.os.execute, env.os.getenv = os.execute, os.getenv
  end
  info.env, env._G = env, env
  for s, v in pairs(FB) do env[s] = v end                 -- Copy local exports to QA environment
  for s, v in pairs(info.extras or {}) do env[s] = v end  -- Copy user provided environment symbols
  loadModules(localModules or {}, env, info.scene)        -- Load default QA specfic modules into environment
  loadModules(EM.cfg.localModules or {}, env, info.scene) -- Load optional user specified module into environment
  EM.postEMEvent({ type = 'infoEnv', info = info })
  procs[co] = info
  LOADLOCK:get()
  DEBUG("module", "sys", "Loading  %s:%s", info.codeType, info.name)
  local fs = {}; for n, f in pairs(info.fileMap) do if not f.isMain then table.insert(fs, 1, f) else fs[#fs + 1] = f end end
  for _, f in pairs(fs) do                                            -- for every file we got, load it..
    DEBUG("files", "sys", "         ...%s", f.name)
    local code = check(env.__TAG, load(f.content, f.fname, "t", env)) -- Load our QA code, check syntax errors
    ---@diagnostic disable-next-line: param-type-mismatch
    EM.checkForExit(true, co, pcall(code))                            -- Run the QA code, check runtime errors
  end
  LOADLOCK:release()
  if env.QuickApp and env.QuickApp.onInit then
    DEBUG("qa", "sys", "Starting QA:%s - ID:%s", info.name, info.id) -- Start QA by "creating instance"
    setTimeout(function()
      env.QuickApp(info.dev)
    end, 0)
  elseif env.ACTION then
    EM.postEMEvent({ type = 'sceneLoaded', info = info })
  end
end

EM.runQA = runQA

loadModules(globalModules or {})                                                       -- Load global modules
loadModules(EM.cfg.globalModules or {})                                                -- Load optional user specified modules into environment

print(fmt("---------------- Tiny QuickAppEmulator (TQAE) v%s -------------", version)) -- Get going...
if cfg.offline == "NOHC3" then LOG.warn("No connection to HC3") end
if cfg.offline then LOG.sys("Running offline") end
if pfvs then LOG.sys("Using config file %s", EM.readConfigFile) end

function EM.startEmulator(cont)
  EM.start(function()
    EM.postEMEvent { type = 'start' }
    if cont then cont() end
  end)
end

if embedded then                -- Embedded call...
  local file = cfg.source and cfg or debug.getinfo(2) -- Find out what file that called us
  if file and file.source then
    if not file.source:sub(1, 1) == '@' then error("Can't locate file:" .. file.source) end
    local fileName = file.source:sub(2)
    EM.startEmulator(function() EM.installQA({ file = fileName }, nil) end)
  end
else
  main(FB)
end
LOG.sys("End - runtime %.2f min", (EM.osTime() - EM._info.started) / 60)
os.exit()
