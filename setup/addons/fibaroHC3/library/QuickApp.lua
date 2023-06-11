---@meta

---@class QuickAppBase
---@field id number The deviceID of the QA
---@field name string The name of the QA
---@field parentId number The deviceID of the parent device
QuickAppBase = {}

---@class QuickAppChild : QuickAppBase
QuickAppChild = {}

---@class QuickApp : QuickAppBase
---@field childDevices table<number,QuickAppBase> Mapping of childDevieIDs to QuickAppChild objects
QuickApp = {}

---Sets a QuickApp variable.
---
---@param name string Name of variable.
---@param value any Value to assign variable.
---@return nil
function QuickAppBase:setVariable(name,value) end

---Gets a QuickApp variable.
---
---@param name string Name of variable.
---@return nil
function QuickAppBase:getVariable(name) end

---Update UI element of QuickApp.
---
---@param label string Element name
---@param field string Element field
---@param value string Element field value
---@return nil
function QuickAppBase:updateView(label,field,value) end

function QuickAppBase:debug(...)  end
function QuickAppBase:error(...) end
function QuickAppBase:warning(...) end
function QuickAppBase:trace(...)   end

function QuickAppBase:callAction(name,...) end

function QuickAppBase:setName(name) end

function QuickAppBase:setEnabled(bool) end

function QuickAppBase:setVisible(bool) end

function QuickAppBase:isTypeOf(typ) end

function QuickAppBase:addInterfaces(ifs) end

function QuickAppBase:deleteInterfaces(ifs) end

function QuickAppBase:updateProperty(prop,val) end

function QuickApp:createChildDevice(props,deviceClass) end

function QuickApp:removeChildDevice(id) end

function QuickApp:initChildDevices(map) end

function QuickAppBase:internalStorageSet(key, val, hidden) end

function QuickAppBase:internalStorageGet(key) end

function QuickAppBase:internalStorageRemove(key) end

function QuickAppBase:internalStorageClear() end