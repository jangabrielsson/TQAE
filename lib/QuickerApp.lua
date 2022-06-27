local _=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
--offline = true,
}

--FILE:lib/fibaroExtra.lua,fibaroExtra;

class 'QuickerApp'
function QuickerApp.debug(_,...) fibaro.debug(nil,...) end
function QuickerApp.trace(_,...) fibaro.trace(nil,...) end
function QuickerApp.warning(_,...) fibaro.warning(nil,...) end
function QuickerApp.error(_,...) fibaro.error(nil,...) end
function QuickerApp.debugf(_,...) fibaro.debugf(nil,...) end
function QuickerApp.tracef(_,...) fibaro.tracef(nil,...) end
function QuickerApp.warningf(_,...) fibaro.warningf(nil,...) end
function QuickerApp.errorf(_,...) fibaro.errorf(nil,...) end
function QuickerApp.post(_,...) return fibaro.post(...) end
function QuickerApp.event(_,...) return fibaro.event(...) end
function QuickerApp.cancel(_,...) return fibaro.cancel(...) end
function QuickerApp.postRemote(_,...) return fibaro.postRemote(...) end
function QuickerApp.publish(_,...) return fibaro.publish(...) end
function QuickerApp.subscribe(_,...) return fibaro.subscribe(...) end

local function resolveFn(fn,cfg)
  if type(fn)=='function' then return fn 
elseif type(fn)=='string' then
    if fn:sub(1,1)=='/' then cfg=_G fn=fn:sub(2) end
    for _,p in ipairs(string.split(fn,'.')) do 
      cfg = cfg[p]
    end
    assert(type(cfg)=='function',"Bad function ref:"..fn)
    return cfg
  end
end

foo = {}
function foo.bar() print(8) end

function QuickerApp.__init(self,args)
  self.qa = quickApp
  self.id = self.qa.id
  self.name = args.name or ("QuickApp "..self.id)
  self.version = args.version or 1.0
  self.author = args.author or ""
  self:debugf("%s, deviceId:%s, v%s, %s",self.name, self.id,self.version, self.author)

  for e,fn in pairs(args.sourceTriggers or {}) do
    local f = resolveFn(fn,args)
    fibaro.event(e,f)
  end

  for b,fn in pairs(args.buttons or {}) do
    local f = resolveFn(fn,args)
  end

  for _,c in ipairs(args.children or {}) do
    local child = _G[c.class]{
      name = c.name,
      uid  = c.uid,
      type = c.type,
      properties = c.properties or {},
      interfaces = c.interfaces,
      quickVars  = c.quickVars
    }
  end

end

------------------------------------------------------------

local Config = {
  name = "My App",
  author = "©Joe@acme.com",
  intro = "This is a simple QuickerApp",
  version = 0.5,
  userVariables = {
    user={value="***"},
    password={value="***"},
  },
  persistentValues = {
    x = 88,
    y = 99,
  },
  sourceTriggers = {
    [{type='device',id=99,property='value'}] = "/foo.bar",
    [{type='global_variables',name="X"}] = "refs.fun2",
  },
  buttons = {
    btn_id1 = "refs.fun3",
    btn_id2 = "refs.fun4",
  },
  children = {
    {
      name = "ChildA",
      type = "com.fibaro.binarySwitch",
      class = "MyChild",
      uid = "c1",
    },
    {
      name = "ChildB",
      type = "com.fibaro.binarySwitch",
      class = "MyChild",
      uid = "c2",
    },
  },
  refs = {},
}

function Config.refs.fun1(trigger) QA.child.c1:test() end
function Config.refs.fun2(trigger) QA.child.c2:test() end
function Config.refs.fun3() QA.child.c1:test() end
function Config.refs.fun4() QA.child.c2:test() end

class 'MyChild'(QuickerAppChild)
function MyChild:__init(args) 
  QuickerAppChild.__init(self,args)
end
function MyChild:test()
  self:debug("Child",self.name,self.id)
end

function QuickApp:onInit() QuickerApp(Config) end

