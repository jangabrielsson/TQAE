local tqaedir = "/Users/erajgab/development/TQAE/"   -- Set path to TQAE directory
local args = {                                       -- Set TQAE arguments
    debug = { color = true, --[[dark=true--]] }
  }


------------------- Don't touch ---------------------------
require("lldebugger").start()
local tqae = loadfile(tqaedir .. "TQAE.lua")
if tqae then
    args.source="@"..arg[2]
    args.root=tqaedir
    tqae(args)
else print("TQAE.lua not found in " .. tqadir) end