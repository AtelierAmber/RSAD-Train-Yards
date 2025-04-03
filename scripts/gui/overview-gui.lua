local gui = require("__gui-modules__.gui")

gui.new{ --MARK: window_def
	window_def = {
		namespace = names.namespace,
		root = "screen",
		version = 1,
		custominput = names.namespace,
		shortcut = names.namespace,
		definition = {
			type = "module", module_type = "window_frame",
			name = names.namespace, title = {"tiergen.menu"},
			has_close_button = true, has_pin_button = true,
			children = {
				{ --MARK: Options
					type = "frame", style = "inside_shallow_frame",
					direction = "vertical",
					children = {
						{ --MARK: Requested items
							type = "module", module_type = "tiergen_selection_area",
							caption = {"tiergen.item-selection"},
							confirm_name = names.calculate, confirm_locale = {"tiergen.calculate"},
							confirm_handler = names.calculate,
	---@diagnostic disable-next-line: missing-fields
							style_mods = {top_margin = 8},
							children = {{
								type = "tabbed-pane", style = "tiergen_tabbed_pane",
	---@diagnostic disable-next-line: missing-fields
								elem_mods = {selected_tab_index = 1},
								handler = {
									[defines.events.on_gui_selected_tab_changed] = "tab-changed"
								},
								children = {
									make_item_selection_pane(1),
									make_item_selection_pane(2),
									make_item_selection_pane(3),
								}
							},{
---@diagnostic disable-next-line: missing-fields
								type = "empty-widget", style_mods = {height = 0, width = 5}
							}}
						} --[[@as SelectionAreaParams]],
						{ --MARK: Base items
							type = "module", module_type = "tiergen_selection_area",
							caption = {"tiergen.base-selection"},
							confirm_name = names.base, confirm_locale = {"tiergen.define-base"},
							confirm_handler = names.base, confirm_enabled_default = false,
							children = {
								{
									type = "label",
									caption = {"tiergen.items"}
								},
								{
									type = "module", module_type = "elem_selector_table",
									frame_style = "tiergen_elem_selector_table_frame",
									name = names.base_items, elem_type = "item",
									height = table_size.item_height, width = table_size.width,
									on_elem_changed = "elems-changed",
								} --[[@as ElemSelectorTableParams]],
								{
									type = "label",
									caption = {"tiergen.fluids"}
								},
								{
									type = "module", module_type = "elem_selector_table",
									frame_style = "tiergen_elem_selector_table_frame",
									name = names.base_fluids, elem_type = "fluid",
									height = table_size.fluid_height, width = table_size.width,
									on_elem_changed = "elems-changed",
								} --[[@as ElemSelectorTableParams]],
								{
---@diagnostic disable-next-line: missing-fields
									type = "empty-widget", style_mods = {height = 0, width = 5}
								}
							}
						} --[[@as SelectionAreaParams]],
						{ --MARK: Ignored recipes
							type = "module", module_type = "tiergen_selection_area",
							caption = {"tiergen.ignored-selection"},
							confirm_name = names.ignored, confirm_locale = {"tiergen.define-ignored"},
							confirm_handler = names.ignored, confirm_enabled_default = false,
	---@diagnostic disable-next-line: missing-fields
							style_mods = {bottom_margin = 4},
							children = {
								{
									type = "module", module_type = "elem_selector_table",
									frame_style = "tiergen_elem_selector_table_frame",
									name = names.ignored_recipes, elem_type = "recipe",
									height = table_size.fluid_height, width = table_size.width,
									on_elem_changed = "elems-changed",
								} --[[@as ElemSelectorTableParams]],
							}
						} --[[@as SelectionAreaParams]],
					}
				},
				{ --MARK: Tier pane
					type = "frame", style = "inside_shallow_frame",
---@diagnostic disable-next-line: missing-fields
					style_mods = {height = 16*44 },
					children = {
						{ --MARK: Error message
							type = "flow", name = names.error_message,
							direction = "vertical",
							children = {
								{type = "empty-widget", style = "flib_vertical_pusher"},
								{
									type = "label",
									caption = {"tiergen.no-tiers"},
	---@diagnostic disable-next-line: missing-fields
									style_mods = {padding = 40},
								},
								{type = "empty-widget", style = "flib_vertical_pusher"},
							}
						},
						{ --MARK: Tier graph
							type = "scroll-pane", style = "naked_scroll_pane",
---@diagnostic disable-next-line: missing-fields
							elem_mods = {visible = false},
							-- style_mods = {left_padding = 8},
							children = {{
								type = "table", direction = "vertical",
								name = names.tier_table, column_count = 2,
								draw_horizontal_lines = true,
	---@diagnostic disable-next-line: missing-fields
								style_mods = {left_padding = 8},
							},{
								type = "frame", style = "tiergen_tierlist_background",
							}}
						}
					}
				}
			}
		} --[[@as WindowFrameButtonsDef]]
	} --[[@as GuiWindowDef]],
	handlers = {
		["tab-changed"] = function (state, elem)
			--MARK: tab changed
			local selected_tab = elem.selected_tab_index --[[@as integer]]
			state.selected_tab = selected_tab
			local calculate = state.elems[names.calculate]

			if state.selected_tab ~= state.calculated_tab then
				calculate.enabled = true
			else
				calculate.enabled = state[selected_tab].has_changed
			end
		end,
		["elems-changed"] = function (state, elem)
			--MARK: elems changed
			local name = elem.name
			if name:match("base") then
				-- Base items
				state.base_changed = true
				state.elems[names.base].enabled = true

			elseif name:match("ignored") then
				-- Ignored items
				state.ignored_changed = true
				state.elems[names.ignored].enabled = true

			else
				-- Tab
				local tab = state[state.selected_tab]
				tab.has_changed = true
				tab.has_changed_from_default = true
				state.elems[names.calculate].enabled = true
			end
		end,

		[names.calculate] = function (state, elem)
			--MARK: calculate
			elem.enabled = false
			local selected_index = state.selected_tab
			local calculated_index = state.calculated_tab
			state.calculated_tab = selected_index
			local tab = state[selected_index]

			if not tab.has_changed then
				update_tier_table(state, tab.result)
				return
			end

			---@type simpleItem[]
			local new_calculated = {}
			for _, type in pairs{"item","fluid"} do
				local table = state.selector_table[selected_index.."_"..type.."_selection"] or {}
				for index, value in pairs(table) do
					if lib.type(index) == "number" then 
						---@cast value string
						new_calculated[#new_calculated+1] = lib.item(value, type)
					end
				end
			end
			tab.has_changed = false

			local calculated_tab = state[calculated_index]
			if calculated_tab then
				local old_calculated = calculated_tab.calculated
				if #old_calculated == #new_calculated then
					local isDifferent = false
					local index = 1
					while not isDifferent and index <= #new_calculated do
						isDifferent = new_calculated[index] ~= old_calculated[index]
						index = index + 1
					end
					if not isDifferent then
						tab.calculated = new_calculated
						tab.result = calculated_tab.result
						return -- Tier table is already set
					end
				end
			end
			tab.calculated = new_calculated

			if #new_calculated == 0 then
				tab.result = {}
				update_tier_table(state, {})
				return
			end

			local results = calculator.getArray(new_calculated)
			tab.result = results
			update_tier_table(state, results)
		end,
		[names.base] = function (state, elem)
			--MARK: define base
			elem.enabled = false

			---@type simpleItem[]
			local new_base,old_base = {},global.config.base_items
			local index, is_different = 0, false
			for _, type in pairs{"item","fluid"} do
				local table = state.selector_table["base_"..type.."_selection"] or {}
				for item_index, value in pairs(table) do
					if lib.type(item_index) ~= "number" then goto continue end
					---@cast value string
					index = index + 1
					local new_item = lib.item(value, type, item_index)
					new_base[index] = new_item
					if not is_different and new_item ~= old_base[index] then
						is_different = true
					end
			    ::continue::
				end
			end

			--Mark as different if the old one had more
			if not is_different then
				is_different = #old_base ~= index
			end

			if not is_different then
				return -- Don't do anything if it wasn't changed
			end

			invalidateTiers()
			state.base_changed = false
			tierMenu.update_base(new_base)
			global.config.base_items = new_base
		end,
		[names.ignored] = function (state, elem)
			--MARK: define ignored
			elem.enabled = false

			---@type table<string,integer>
			local new_ignored,old_ignored = {},global.config.ignored_recipes
			local new_count,old_count = 0,0
			local is_different = false
			local table = state.selector_table[names.ignored_recipes] or {}
			for index, recipe in pairs(table) do
				if lib.type(index) ~= "number" then goto continue end
				---@cast recipe string
				new_count = new_count + 1
				new_ignored[recipe] = index
				if not is_different and not old_ignored[recipe] then
					is_different = true
				end
			  ::continue::
			end

			--Count the old table because you can't do # on table<string,true>
			for _ in pairs(old_ignored) do
				old_count = old_count + 1
			end

			--Mark as different if the old one had a different amount
			if not is_different then
				is_different = old_count ~= new_count
			end

			if not is_different then
				return -- Don't do anything if it wasn't changed
			end

			global.reprocess = true
			invalidateTiers()
			state.ignored_changed = false
			tierMenu.update_ignored(new_ignored)
			global.config.ignored_recipes = new_ignored
		end
	} --[[@as table<any, fun(state:WindowState.TierMenu,elem:LuaGuiElement,event:GuiEventData)>]],
	state_setup = function (state)
		--MARK: Window setup
		---@cast state WindowState.TierMenu
		state.selected_tab = state.selected_tab or 1
		state.calculated_tab = state.calculated_tab or 0

		state[1] = state[1] or base_tab(true)
		state[2] = state[2] or base_tab(true)
		state[3] = state[3] or base_tab(true)

		local permission_group = state.player.permission_group
		---@type boolean
		local can_define
		if permission_group then
			can_define = permission_group.allows_action(defines.input_action.mod_settings_changed)
		else
			can_define = state.can_define == true
		end
		update_defining_permission(state, can_define, true)

		state.base_changed = false
		state.base_state = {}
		state.ignored_changed = false
		state.ignored_state = {}

		local config = global.config
		if config then
			local player_index = state.player.index
			tierMenu.set_items(player_index, {
				config.all_sciences,
				{config.ultimate_science},
				{}
			})
			tierMenu.update_base(config.base_items)
			tierMenu.update_ignored(config.ignored_recipes)
		end
	end
} --[[@as newWindowParams]]