-- Selects the first entry of the current menu whose label contains SEL. Test helper.
local c = R("necro.menu.Menu").getCurrent()
if not c then return "no menu" end
for i, e in ipairs(c.entries) do
	local l = e.label
	if type(l) == "function" then l = l(false) end
	if M.Text.clean(tostring(l or "")):find(SEL, 1, true) then c.selection = i return c.name .. " -> " .. i end
end
return "not found in " .. tostring(c.name)
