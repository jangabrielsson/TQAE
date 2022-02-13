_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  user="admin", 
  pwd="admin", 
  host="192.168.1.57",
  temp = "temp/",
  startTime="12/24/2024-07:00",
}

--%%name="Wrapper"

--Example of loading and running another QA
hc3_emulator.installQA{id=88,file='examples/Pong.lua'} -- from file
--hc3_emulator.installQA{breakOnInit=true,id=811,code=api.get("/quickApp/export/811")} -- from the HC3