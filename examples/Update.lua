_=loadfile and loadfile("TQAE.lua"){
  user="admin", 
  pwd="admin", 
  host="192.168.1.57",
  temp = "temp/",
  startTime="12/24/2024-07:00",
}

--%%name="Update"

--FILE:fibaroExtra.lua,fibaroExtra;

--Example of updating QAs on the HC3 with new a file
--Based on that your file on the HC3 is uniquely named
--In this case we update all files named "fibaroExtra". 
--Files to update needs to be included in this QA with the --FILE: directive.
--Note that a QA that gets a file updated will restart

local files2update = {"fibaroExtra"}

function QuickApp:onInit()
  for _,qa in ipairs(api.get("/devices?interface=quickApp")) do
    local files = api.get("/quickApp/"..qa.id.."/files") or {}
    for _,f in ipairs(files) do
      if files2update:member(f.name) then
        local newFile = api.get("/quickApp/"..self.id.."/files/"..f.name)
        f.content = newFile.content
        f.type = "lua"
        api.put("/quickApp/"..qa.id.."/files/"..f.name,f)
      end
    end
  end
end
