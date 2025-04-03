local function local_module_add(name)
	return module_add(name, "__rsad-train-yards__.scripts.gui."..name)
end

--Modules
data:extend{
	local_module_add("overview-gui"),
	--local_module_add("tiergen_selection_area")
}