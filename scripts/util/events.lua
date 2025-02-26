local build_registrar = {}
local destroy_registrar = {}

local paste_registrar = {}

local train_registrar = {}

local init_registrar = {}
local load_registrar = {}

local build_filter = {}
local destroy_filter = {}

---@param event EventData.on_built_entity|EventData.on_robot_built_entity|EventData.on_space_platform_built_entity|EventData.script_raised_built|EventData.script_raised_revive|EventData.on_entity_cloned
local function on_built(event)
	local entity = event.entity
	if not entity or not entity.valid then return end

    for kind, registrar in pairs(build_registrar) do
        if kind == "name" then
            if (registrar and registrar[entity.name]) then
                for _, func in pairs(registrar[entity.name]) do
                    if func then
                        if func(entity) == false then 
                            return -- If event function returns false, stop processing event
                        end
                    end
                end
            end
        elseif kind == "type" then
            if (registrar and registrar[entity.type]) then
                for _, func in pairs(registrar[entity.name]) do
                    if func then
                        if func(entity) == false then 
                            return -- If event function returns false, stop processing event
                        end
                    end
                end
            end
        elseif kind == "rolling-stock" then
            if (registrar) then
                for _, r in pairs(registrar) do
                    for _, func in pairs(r) do
                        if func then
                            if func(entity) == false then 
                                return -- If event function returns false, stop processing event
                            end
                        end
                    end
                end
            end
        elseif kind == "rail" then
            if (registrar and registrar[entity.name]) then
                for _, func in pairs(registrar[entity.name]) do
                    if func then
                        if func(entity) == false then 
                            return -- If event function returns false, stop processing event
                        end
                    end
                end
            end
        end
    end
end

---@param event EventData.on_pre_player_mined_item|EventData.on_robot_pre_mined|EventData.on_space_platform_pre_mined|EventData.on_entity_died|EventData.script_raised_destroy
local function on_broken(event)
    local entity = event.entity
	if not entity or not entity.valid then return end

    for kind, registrar in pairs(destroy_registrar) do
        if kind == "name" then
            if (registrar and registrar[entity.name]) then
                for _, func in pairs(registrar[entity.name]) do
                    if func then
                        if func(entity) == false then 
                            return -- If event function returns false, stop processing event
                        end
                    end
                end
            end
        elseif kind == "type" then
            if (registrar and registrar[entity.type]) then
                for _, func in pairs(registrar[entity.name]) do
                    if func then
                        if func(entity) == false then 
                            return -- If event function returns false, stop processing event
                        end
                    end
                end
            end
        elseif kind == "rolling-stock" then
            if (registrar) then
                for _, r in pairs(registrar) do
                    for _, func in pairs(r) do
                        if func then
                            if func(entity) == false then 
                                return -- If event function returns false, stop processing event
                            end
                        end
                    end
                end
            end
        elseif kind == "rail" then
            if (registrar and registrar[entity.name]) then
                for _, func in pairs(registrar[entity.name]) do
                    if func then
                        if func(entity) == false then 
                            return -- If event function returns false, stop processing event
                        end
                    end
                end
            end
        end
    end
end

---@param event EventData.on_entity_settings_pasted
local function on_train_event(event)
    local registrar = train_registrar[event.name]
    for _, registry in pairs(registrar) do
        if registry then
            registry(event)
        end
    end
end

local function on_init()
    for _, registry in pairs(init_registrar) do
        if registry then
            registry()
        end
    end
end

local function on_load()
    for _, registry in pairs(load_registrar) do
        if registry then
            registry()
        end
    end
end



---@param event EventData.on_entity_settings_pasted
local function on_paste(event)
    for _, registry in pairs(paste_registrar) do
        if registry then
            registry(event.destination)
        end
    end
end

---@param type defines.events.on_train_changed_state | defines.events.on_train_created | defines.events.on_train_schedule_changed
---@param func fun(event:EventData.on_train_changed_state|EventData.on_train_created|EventData.on_train_schedule_changed)
function register_train_handler(type, func)
    train_registrar[type] = train_registrar[type] or {}
    train_registrar[type][#train_registrar[type]+1] = func
end

-- If event function returns false, stop processing event
--- kind can be any built entity filter
---@param kind string
---@param name string
---@param func fun(entity:LuaEntity):boolean
function register_build(kind, name, func)
    build_registrar[kind] = build_registrar[kind] or {}
    local registration = build_registrar[kind][name] or {}
    registration[#registration+1] = func
    build_registrar[kind][name] = registration

    for _, f in pairs(build_filter) do
        if f.filter == kind and f.name == name then
            return
        end
    end

    build_filter[#build_filter+1] = {filter = kind, name = name, type = name, ghost_name = name, ghost_type = name}
end

-- If event function returns false, stop processing event
---@param kind string
---@param name string
---@param func fun(entity:LuaEntity):boolean
function register_break(kind, name, func)
    destroy_registrar[kind] = destroy_registrar[kind] or {}
    local registration = destroy_registrar[kind][name] or {}
    registration[#registration+1] = func
    destroy_registrar[kind][name] = registration
    
    for _, f in pairs(destroy_filter) do
        if f.filter == kind and f.name == name then
            return
        end
    end

    destroy_filter[#destroy_filter+1] = {filter = kind, name = name, type = name, ghost_name = name, ghost_type = name}
end

---@param func fun()
function register_init(func)
    init_registrar[#init_registrar+1] = func
end

---@param func fun()
function register_load(func)
    load_registrar[#load_registrar+1] = func
end

---@param func fun(entity:LuaEntity)
function register_paste(func)
    paste_registrar[#paste_registrar+1] = func
end

local function register_build_events()
    --NOTE: Using the on placement trigger might be better but would have to expand a lot of things and it would only work on a per-prototype basis
	script.on_event(defines.events.on_built_entity, on_built, build_filter)
	script.on_event(defines.events.on_robot_built_entity, on_built, build_filter)
	script.on_event(defines.events.on_space_platform_built_entity, on_built, build_filter)
	script.on_event(
		{
			defines.events.script_raised_built,
			defines.events.script_raised_revive,
			defines.events.on_entity_cloned,
		}, on_built)

end

local function register_destroy_events()
    script.on_event(defines.events.on_pre_player_mined_item, on_broken, destroy_filter)
	script.on_event(defines.events.on_robot_pre_mined, on_broken, destroy_filter)
	script.on_event(defines.events.on_space_platform_pre_mined, on_broken, destroy_filter)
	script.on_event(defines.events.on_entity_died, on_broken, destroy_filter)
	script.on_event(defines.events.script_raised_destroy, on_broken)
end

local function register_train_events()
    script.on_event(defines.events.on_train_changed_state, on_train_event)
    script.on_event(defines.events.on_train_created, on_train_event)
    script.on_event(defines.events.on_train_schedule_changed, on_train_event)
end

local function init()
    register_build_events()
    register_destroy_events()

    register_train_events()

	script.on_event(defines.events.on_entity_settings_pasted, on_paste)
    
    script.on_init()
    script.on_load()
	---script.on_event(defines.events.on_player_rotated_entity, on_rotate)

	--script.on_event({ defines.events.on_pre_surface_deleted, defines.events.on_pre_surface_cleared }, on_surface_removed)


	-- script.on_event(defines.events.on_train_created, on_train_built)
	-- script.on_event(defines.events.on_train_changed_state, on_train_changed)

	-- script.on_event(defines.events.on_entity_renamed, on_rename)

	-- script.on_event(defines.events.on_runtime_mod_setting_changed, on_settings_changed)

	-- register_gui_actions()

	-- local MANAGER_ENABLED = mod_settings.manager_enabled

	-- script.on_init(function()
	-- 	init_global()
	-- 	se_compat.setup_se_compat()
	-- 	picker_dollies_compat.setup_picker_dollies_compat()
	-- 	if MANAGER_ENABLED then
	-- 		manager.on_init()
	-- 	end
	-- end)

	-- script.on_configuration_changed(function(e)
	-- 	on_config_changed(e)
	-- 	if MANAGER_ENABLED then
	-- 		manager.on_migration()
	-- 	end
	-- end)

	-- script.on_load(function()
	-- 	se_compat.setup_se_compat()
	-- 	picker_dollies_compat.setup_picker_dollies_compat()
	-- end)

	-- if MANAGER_ENABLED then
	-- 	script.on_event(defines.events.on_player_removed, manager.on_player_removed)
	-- 	script.on_event(defines.events.on_player_created, manager.on_player_created)
	-- 	script.on_event(defines.events.on_lua_shortcut, manager.on_lua_shortcut)
	-- 	script.on_event(defines.events.on_gui_closed, manager.on_lua_shortcut)
	-- 	script.on_event("cybersyn-toggle-gui", manager.on_lua_shortcut)
	-- end

	-- register_tick()
end

init()