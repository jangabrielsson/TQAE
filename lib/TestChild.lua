_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
--offline = true,
}

--FILE:lib/UI.lua,UI;
--FILE:lib/QwikAppChild.lua,Child;

local TestChildUI = {
    {{button='b1', text='B1', onReleased='test'}, {button='b2', text='B2', onReleased='test'}},
    {slider='s1', text="...", onChanged='test'}
}

class 'TestChild'(QwikAppChild)
function TestChild:__init(device) 
    QwikAppChild.__init(self, device)
    self.uid = self:getVariable("ChildID")
    print("Child ID:",self.id, "Child UID:",self.uid)
end

function TestChild:test() 
    self:debug("Child",self.name,self.id)
end

function QuickApp:onInit()
    
    local children = {
        ['uid1'] = {
            name='Test', 
            type = "com.fibaro.binarySwitch", 
            className = 'TestChild',
            UI = TestChildUI,
            interfaces = {"power"}
        }
    }
    self:initChildren(children) 
end
