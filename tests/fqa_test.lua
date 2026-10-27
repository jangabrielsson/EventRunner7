--%%name:fqa_test
--%%mode:offline

-- Boots the packaged dist/EventRunner7.fqa in the flua emulator with the
-- custom rules file tests/fqa_rules.lua attached (the old plua desktop-panel
-- test). flua's replacement for fibaro.plua.lib.loadFQA is
-- _FLUA.loadFQAfromFile(path, extraDirectives): it unpacks the package to a
-- temp dir, wires up all packaged files, and boots it as a QuickApp. Extra
-- --%% directives (like the rules file) are appended to the QA's header.

local newmain = [[
function QuickApp:onInit()
  local str = "EventRunner 7, v"..fibaro.EventRunnerVersion
  self:debug(string.format("<font color='green'>%s</font>",str))
  self:updateView('info','text',str)
  print("OKOK",main)
  fibaro.EventRunner(main)
end
]]

local f = io.open("dist/EventRunner7.fqa")
assert(f, "cannot open dist/EventRunner7.fqa — build it first")
local fqa = f:read("*a")
f:close()
fqa = json.decode(fqa)
for _,file in ipairs(fqa.files) do
  if file.name == 'main' then
    file.content = newmain
  end
end
-- Write the patched package to a temp file and boot it in the emulator.
local tmp = os.tmpname()
local out = assert(io.open(tmp, "w"))
out:write(json.encode(fqa))
out:close()
local qaId, err = _FLUA.loadFQAfromFile(tmp, {"mode:offline", "file:"..os.getenv("PWD").."/tests/fqa_rules.lua,pl"})
assert(qaId, err)
