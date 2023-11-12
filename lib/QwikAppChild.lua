do
  local childID = 'ChildID'
  local classID = 'ClassName'
  local defChildren

  local children = {}
  local undefinedChildren = {}
  local createChild = QuickApp.createChildDevice
  class 'QwikAppChild'(QuickAppChild)

  local function setupUIhandler(self)
     if not self.UIHandler then
        function self:UIHandler(event)
            local obj = self
            if self.id ~= event.deviceId then obj = (self.childDevices or {})[event.deviceId] end
            if not obj then return end
            local elm,etyp = event.elementName, event.eventType
            local cb = obj.uiCallbacks or {}
            if obj[elm] then return obj:callAction(elm, event) end
            if cb[elm] and cb[elm][etyp] and obj[cb[elm][etyp]] then return obj:callAction(cb[elm][etyp], event) end
            if obj[elm.."Clicked"] then return obj:callAction(elm.."Clicked", event) end
            self:warning("UI callback for element:", elm, " not found-")
        end
     end
  end

  local function member(k,tab) for i,v in ipairs(tab) do if v==k then return i end end return false end

  function QwikAppChild:__init(device) 
    QuickAppChild.__init(self, device)
    self:debug("Instantiating object ",device.name)
    local uid = self:getVariable(childID) or ""
    if defChildren[uid] then
      children[uid]=self               -- Keep table with all children indexed by uid. uid is unique.
    else                               -- If uid not in our children table, we will remove this child
      undefinedChildren[#undefinedChildren+1]=self.id 
    end
  end

  local function getVar(child,varName)
    for _,v in ipairs(child.properties.quickAppVariables or {}) do
      if v.name==varName then return v.value end
    end
    return ""
  end

  local function setVar(qvl,name,value)
     qvl[#qvl+1]={name=name,value=value}
     return qvl
  end

  local function setupCallbacks(child)
     local uic = getVar(child,'uiCallbacks')
     local map = {}
     child.uiCallbacks = map
     if type(uic)=='table' then
        for _,u in ipairs(uic) do
           map[u.name] = { [u.eventType] = u.callback }
        end
     end
  end

  function QuickApp:createChildDevice(uid,props,interfaces,className)
    __assert_type(uid,'string')
    __assert_type(className,'string')
    props.initialProperties = props.initialProperties or {}
    local qvars = props.quickVars or {}
    qvars = setVar(qvars,childID,uid)
    qvars = setVar(qvars,classID,className)
    local callbacks = props.initialProperties.uiCallbacks
    if callbacks then
       qvars =  setVar(qvars,'uiCallbacks',callbacks)
    end
    props.initialProperties.quickAppVariables = qvars
    props.initialInterfaces = interfaces or {}
    if props.initialProperties.viewLayout then
        if not member('quickApp',props.initialInterfaces) then
            table.insert(props.initialInterfaces,'quickApp')
        end
    end
    self:debug("Creating device ",props.name)
    local c = createChild(self,props,_G[className])
    if c and callbacks then
       c:updateProperty("uiCallbacks",callbacks)
    end
    if member('quickApp',props.initialInterfaces) then
        local file = {isMain=true,type='lua',isOpen=false,name='main',content=""}
        api.put("/quickApp/"..c.id.."/files/main",file) 
    end
    setupCallbacks(c)
  end

  function QuickApp:loadExistingChildren(chs)
    __assert_type(chs,'table')
    local stat,err = pcall(function()
        defChildren = chs
        self.children = children
        function self.initChildDevices() end
        local cdevs,n = api.get("/devices?parentId="..self.id) or {},0 -- Pick up all my children
        for _,child in ipairs(cdevs) do
          local uid = getVar(child,childID)
          local className = getVar(child,classID)
          local childObject = _G[className] and _G[className](child) or QuickAppChild(child)
          self.childDevices[child.id]=childObject
          childObject.parent = self
          setupCallbacks(childObject)
        end
      end)
    if not stat then self:error("loadExistingChildren:"..err) end
  end

  function QuickApp:createMissingChildren()
    local stat,err = pcall(function()
        local chs = {}
        for uid,data in pairs(defChildren) do chs[#chs+1]={uid=uid,data=data} end
        table.sort(chs,function(a,b) return a.uid<b.uid end)
        for _,ch in ipairs(chs) do
          if not self.children[ch.uid] then
            local props = {
              name = ch.data.name,
              type = ch.data.type,
              initialProperties = ch.data.properties or {},
            }
            if ch.data.UI then
               assert(fibaro.UI,"Please install fibaro.UI extension")
               local viewLayout,uiCallbacks = fibaro.UI.createUI(ch.data.UI)
               props.initialProperties.viewLayout = viewLayout
               props.initialProperties.uiCallbacks = uiCallbacks
            end
            self:createChildDevice(ch.uid,props,ch.data.interfaces,ch.data.className)
          end
        end 
      end)
    if not stat then self:error("createMissingChildren:"..err) end
  end

  function QuickApp:removeUndefinedChildren()
    for _,deviceId in ipairs(undefinedChildren) do -- Remove children not in children table
      self:removeChildDevice(deviceId)
    end
  end

  function QuickApp:initChildren(children)
    setupUIhandler(self)
    self:loadExistingChildren(children)
    self:createMissingChildren()
    self:removeUndefinedChildren()
  end
end