#########################################################################################################
##
## MANAGE LAYERS FUNCTIONS
##
#########################################################################################################

var script_class = "tool"

var switch_button = null
var panel = null
var tree = null
var panels_root = null
var layer_id_line_edit = null
var layer_name_line_edit = null
var confirmwindow = null
var mod_tool_panel = null
var store_tree_items = {}
var _lib_mod_config = null

# Logging Functions
const ENABLE_LOGGING = true
var logging_level = 0

#########################################################################################################
##
## UTILITY FUNCTIONS
##
#########################################################################################################

func outputlog(msg,level=0):
	if ENABLE_LOGGING:
		if level <= logging_level:
			printraw("(%d) <ManageLayers>: " % OS.get_ticks_msec())
			print(msg)
	else:
		pass

# Function to look at resource string and return the texture
func load_image_texture(texture_path: String):

	var image = Image.new()
	var texture = ImageTexture.new()

	# If it isn't an internal resource
	if not "res://" in texture_path:
		image.load(Global.Root + texture_path)
		texture.create_from_image(image)
	# If it is an internal resource then just use the ResourceLoader
	else:
		texture = ResourceLoader.load(texture_path)
	
	return texture

#########################################################################################################
##
## MAKE UI FUNCTIONS
##
#########################################################################################################

# Sets up the UI for our tree to live in
func setup_panel():

	outputlog("setup_panel",2)
	# The PanelContainer styling is a bit of a mystery to me - the below is the result of a lot of
	# trial and error.
	panel = PanelContainer.new()

	# Hacky way of doing hidpi scaling. Can't get anchors to work with the current parent node.
	var scale_factor = OS.get_screen_dpi() / 96.0

	panel.set_custom_minimum_size(Vector2(300.0 * scale_factor, 0))

	# Overrides the theme background (which is a light grey) with translucent black.
	var sb = StyleBoxFlat.new()
	sb.set_bg_color(Color(0, 0, 0, 0.4))

	panel.add_stylebox_override("panel", sb)

	# Container that fills the panel
	var box = VBoxContainer.new()
	box.set_h_size_flags(3)
	box.set_v_size_flags(3)

	# Text label. Should probably make it bold or something, but I don't have the will...
	var label = Label.new()
	label.set_text("Manage Layers")
	var dynamic_font = DynamicFont.new()
	dynamic_font = load("res://ui/fonts/PanelHeadingFont.tres")
	dynamic_font.size = 48
	label.add_font_override("font", dynamic_font)
	box.add_child(label)

	# UI for creating a new layer
	var hbox = HBoxContainer.new()
	box.add_child(hbox)
	var layer_label = Label.new()
	layer_label.text = " New Layer ID: "
	hbox.add_child(layer_label)
	layer_id_line_edit = LineEdit.new()
	layer_id_line_edit.size_flags_horizontal = 3
	layer_id_line_edit.align = LineEdit.ALIGN_LEFT
	layer_id_line_edit.placeholder_text = "New Layer ID"
	hbox.add_child(layer_id_line_edit)
	var hbox2 = HBoxContainer.new()
	box.add_child(hbox2)
	var layer_name_label = Label.new()
	layer_name_label.text = " New Layer Name: "
	hbox2.add_child(layer_name_label)

	layer_name_line_edit = LineEdit.new()
	hbox2.add_child(layer_name_line_edit)
	layer_name_line_edit.size_flags_horizontal = 3
	layer_name_line_edit.placeholder_text = "New Layer Name"
	layer_name_line_edit.align = LineEdit.ALIGN_LEFT

	var button = Button.new()
	box.add_child(button)
	button.icon = load("res://ui/icons/menu/new.png")
	button.text = "Create New Layer"
	button.connect("pressed", self, "on_create_layer_button_pressed")


	# Create the tree and tell it to fill the rest of the panel.
	tree = Tree.new()
	tree.hide_root = true
	tree.columns = 3
	tree.set_column_title(0, "ID")
	tree.set_column_title(1, "Name")
	tree.set_column_titles_visible(true)
	tree.set_select_mode(0)
	tree.set_column_min_width(0, 120.0)
	tree.set_column_min_width(1, 100.0)
	tree.set_column_min_width(2, 40.0)
	tree.set_column_expand(0, false)
	tree.set_column_expand(2, false)
	tree.connect("button_pressed", self, "on_button_pressed")
	tree.connect("item_edited", self, "on_treeitem_edited")

	tree.set_h_size_flags(3)
	tree.set_v_size_flags(3)

	box.add_child(tree)
	panel.add_child(box)
	panels_root.add_child(panel)
	panel.visible = false

	# Draw the tree for the first time
	refresh_tree()

func refresh_tree():

	var level = Global.World.GetCurrentLevel()

	outputlog("Current level: " + str(level.Label),2)

	var layers = Global.API.LayerApi.get_layers(level)
	outputlog("layers: " + str(layers),2)
	var list = layers.keys()
	list.sort()
	tree.clear()
	var root = tree.create_item()
	var child
	store_tree_items = {}

	for key in list:
		if key in Global.API.LayerApi.LOCKED_LAYERS:
			make_new_layer_child(root, key, layers[key], false)
		else:
			make_new_layer_child(root, key, layers[key], true)

# Make a new child layer
func make_new_layer_child(root: TreeItem, layer_id: int, name: String, is_editable: bool):

	var child = tree.create_item(root)
	child.set_text(0,str(layer_id) + " ")
	child.set_text_align(0, TreeItem.ALIGN_RIGHT)
	child.set_editable(0, true)
	child.set_text(1,name)
	child.set_editable(1, true)
	store_tree_items[child] = {"layer_id": layer_id, "layer_name": name}

	if not is_editable:
		for _i in tree.columns:
			child.set_selectable(_i, false)
			child.set_custom_color(_i, Color( 0.66, 0.66, 0.66, 0.5 ))
	else:
		child.add_button(2, expand_texture(ResourceLoader.load("res://ui/icons/misc/delete.png"),32), -1, false, "Delete layer")

	return child

# Expand the texture to a bigger size
func expand_texture(texture, size_pixels: int) -> Texture:

	var image = Image.new()
	image = texture.get_data()
	image.resize(size_pixels,size_pixels,1)
	var new_texture = ImageTexture.new()
	new_texture.create_from_image(image)

	return new_texture

# Check that layer name can only contain numbers, letters, full stops, spaces, underscores, hyphens
func is_valid_layer_name(name: String):

	outputlog("is_valid_layer_name: " + str(name),2)

	for character in [".","-"," "]:
		name = name.replace(character, "_")

	outputlog("name: " + str(name),2)
	
	return name.is_valid_identifier()

# Function to capture when the tree is edited
func on_treeitem_edited():

	outputlog("on_treeitem_edited",2)
	var level = Global.World.GetCurrentLevel()

	var treeitem = tree.get_edited()
	var layers = Global.API.LayerApi.get_layers(level)

	match tree.get_edited_column():
		0:
			outputlog("editing layer id: " + str(treeitem.get_text(0)),2)
			var store_target_id = treeitem.get_text(0).replace(" ","")
			if store_tree_items.has(treeitem):
				if store_tree_items[treeitem].has("layer_id"):
					# If the value hasn't changed, then do nothing
					if int(store_target_id) == store_tree_items[treeitem]["layer_id"]:
						treeitem.set_text(0,store_tree_items[treeitem]["layer_id"])
						return
					if validate_layer_id(str(store_target_id), level):
						Global.API.LayerApi.modify_layer_index(store_tree_items[treeitem]["layer_id"], int(store_target_id), level, true, Global.API.LayerApi.ExistingTargetFlag.FAIL)
					else:
						treeitem.set_text(0,store_tree_items[treeitem]["layer_id"])
		1:
			outputlog("editing layer name: " + str(treeitem.get_text(1)),2)
			if is_valid_layer_name(treeitem.get_text(1)):
				Global.API.LayerApi.rename_layer(int(treeitem.get_text(0)), treeitem.get_text(1))
			else:
				treeitem.set_text(1,"default")
				if store_tree_items.has(treeitem):
					if store_tree_items[treeitem].has("layer_name"):
						treeitem.set_text(1,store_tree_items[treeitem]["layer_name"])
	
	refresh_tree()
	Global.API.ModSignalingApi.emit_signal("layers_changed")

func validate_layer_id(layer_id_string: String, level):

	var layers = Global.API.LayerApi.get_layers(level)

	if not layer_id_string.is_valid_integer():
		var warn_string = "The layer id, " + str(layer_id_string) + ", is not a valid integer."
		Global.Editor.Warn("Layer Creation Failed", warn_string)
		outputlog("layer id is invalid",2)
		return false

	# Check if the layer is taken
	if int(layer_id_string) in layers.keys():
		var warn_string = "The layer id, " + str(layer_id_string) + ", already exists as "
		warn_string += str(layers[layers.keys()[layers.keys().find(int(layer_id_string))]]) + "."
		Global.Editor.Warn("Layer Creation Failed", warn_string)
		outputlog("layer id is taken",2)
		return false
	
	if int(layer_id_string) < -500 || int(layer_id_string) > 2000:
		Global.Editor.Warn("Layer Creation Failed","The layer id, " + str(layer_id_string) + ", can not be higher than 2000 or lower than -500.")
		outputlog("layer id is taken",2)
		return false
	return true


# On create new layer button pressed
func on_create_layer_button_pressed():

	var level = Global.World.GetCurrentLevel()
	var layers = Global.API.LayerApi.get_layers(level)

	if not layer_id_line_edit.text.is_valid_integer():
		var warn_string = "The layer id, " + str(layer_id_line_edit.text) + ", is not a valid integer."
		Global.Editor.Warn("Layer Creation Failed", warn_string)
		layer_id_line_edit.text = ""
		outputlog("layer id is invalid",2)
		return

	# Check if the layer is taken
	if not validate_layer_id(layer_id_line_edit.text, level):
		layer_id_line_edit.text = ""
		return
	
	outputlog("layer_id_line_edit: " + str(layer_id_line_edit.text) + " layer_name_line_edit: " + str(layer_name_line_edit.text),2)

	Global.API.LayerApi.add_layer(int(layer_id_line_edit.text), layer_name_line_edit.text,level)
	refresh_tree()
	Global.API.ModSignalingApi.emit_signal("layers_changed")

func print_popupmenu(popupmenu: PopupMenu):
	outputlog("popupmenu: " + str(popupmenu),2)

	for _i in popupmenu.get_item_count():
		outputlog("_i: " + str(_i) + " text: " + str(popupmenu.get_item_text(_i)),2)

# On deete button pressed
func on_button_pressed(item: TreeItem, column: int, id: int):

	outputlog("on_button_pressed")
	var level = Global.World.GetCurrentLevel()

	var display_string = "This will delete all assets on this layer: ID: " + str(item.get_text(0)) + " Name: " + str(item.get_text(1)) + ". "
	var data = count_assets_on_layer(level,int(item.get_text(0)))

	for type in data.keys():
		display_string += str(data[type]) + " "
		if int(data[type]) == 1:
			display_string += str(type).left(str(type).length()-1).replace("_"," ")
		else:
			display_string += str(type).replace("_"," ")

		if type != "paths":
			display_string += ", "
		else:
			display_string += "."
		
	confirmwindow.find_node("Label").text = display_string
	confirmwindow.find_node("Label").autowrap = true
	confirmwindow.popup_centered_ratio(0.25)
	confirmwindow.set_meta("treeitem_for_deletion",item)

func count_assets_on_layer(level, layer_id: int) -> Dictionary:

	var parent_list = []
	var counts = {"objects": 0, "pattern_shapes": 0, "paths":  0}

	outputlog("count_assets_on_layer" + str(layer_id))

	for asset_type in counts.keys():
		match asset_type:
			"objects":
				parent_list = level.Objects.get_children()
			"pattern_shapes":
				parent_list = level.PatternShapes.GetShapes()
			"paths":
				parent_list = level.Pathways.get_children()
			_:
				continue
			
		outputlog("parent_list: " + str(parent_list))
		for _i in parent_list.size():
			match asset_type:
				"objects", "paths":
					if parent_list[_i].z_index == layer_id:
						counts[asset_type] += 1
				"pattern_shapes":
					if parent_list[_i].GetLayer() == layer_id:
						outputlog("pattern z_index: " + str(parent_list[_i].z_index),2)
						counts[asset_type] += 1

	for layer_node in level.PatternShapes.get_children():
		outputlog("layer_node: " + str(layer_node))
		outputlog("layer_node.z_index: " + str(layer_node.z_index))
	return counts

# Function to confirm that deletion should be actually implemented.
func on_deletion_confirmed():

	confirmwindow.visible = false
	var treeitem = confirmwindow.get_meta("treeitem_for_deletion")
	if treeitem != null:
		if treeitem.get_text(0).rstrip(" ").is_valid_integer():
			Global.API.LayerApi.remove_layer(int(treeitem.get_text(0).rstrip(" ")),Global.World.GetCurrentLevel())
			refresh_tree()
			Global.API.ModSignalingApi.emit_signal("layers_changed")
			return
	
	Global.Editor.Warn("Layer Deletion Failed", "Unable to delete layer.")

# When we think a level change may have occurred
func on_possible_level_change(_ignore_this):
	
	outputlog("on_possible_level_change: " + str(_ignore_this),2)
	var timer = Timer.new()
	timer.autostart = false
	timer.one_shot = true
	Global.Editor.Toolset.GetToolPanel("SelectTool").add_child(timer)

	timer.start(0.2)
	yield(timer,"timeout")

	refresh_tree()

	Global.Editor.Toolset.GetToolPanel("SelectTool").remove_child(timer)
	timer.queue_free()

func on_mod_tool_visibility_changed():

	outputlog("on_mod_tool_visibility_changed: " + str(mod_tool_panel.visible),2)

	panel.visible = mod_tool_panel.visible
	refresh_tree()

#########################################################################################################
##
## UPDATE FUNCTION
##
#########################################################################################################

#########################################################################################################
##
## _LIB CONFIG FUNCTIONS
##
#########################################################################################################

func make_lib_configs():

	# Create a config builder to ensure we can update the offset if needed
	var _lib_config_builder = Global.API.ModConfigApi.create_config()
	_lib_config_builder\
		.h_box_container().enter()\
			.label("Core Log Level ")\
			.option_button("core_log_level", 0, ["0","1","2","3","4"])\
		.exit()
	_lib_mod_config = _lib_config_builder.build()

	logging_level = int(_lib_mod_config.core_log_level)

#########################################################################################################
##
## VERSION CHECKER FUNCTIONS
##
#########################################################################################################

# Check whether a semver strng 2 is greater than string one. Only works on simple comparisons - DO NOT USE THIS FUNCTION OUTSIDE THIS CONTEXT
func compare_semver(semver1: String, semver2: String) -> bool:

	outputlog("compare_semver: semver1: " + str(semver1) + " semver2" + str(semver2),2)
	var semver1data = get_semver_data(semver1)
	var semver2data = get_semver_data(semver2)

	if semver1data == null || semver2data == null : return false

	if semver1data["major"] != semver2data["major"]:
		return semver1data["major"] < semver2data["major"]
	if semver1data["minor"] != semver2data["minor"]:
		return semver1data["minor"] < semver2data["minor"]
	if semver1data["patch"] != semver2data["patch"]:
		return semver1data["major"] < semver2data["major"]
	
	return false

# Parse the semver string
func get_semver_data(semver: String):

	var data = {}

	if semver.split(".").size() < 3: return null

	return {
		"major": int(semver.split(".")[0]),
		"minor": int(semver.split(".")[1]),
		"patch": int(semver.split(".")[2].split("-")[0])
	}


#########################################################################################################
##
## START FUNCTION FUNCTION
##
#########################################################################################################

# Main Script
func start() -> void:

	outputlog("ManageLayers Mod Has been loaded.")

	# We need _Lib for this to work
	if Engine.has_signal("_lib_register_mod"):
		# Register this mod with _lib
		Engine.emit_signal("_lib_register_mod", self)
	else:
		outputlog("_Lib is not loaded, exiting.")
		return
	make_lib_configs()
	panels_root = Global.Editor.get_node("VPartition/Panels")
	setup_panel()
	
	var template = ResourceLoader.load(Global.Root + "windows/ConfirmDeleteWindow.tscn")
	confirmwindow = template.instance()
	confirmwindow.find_node("DiscardButton").visible = false
	confirmwindow.find_node("SaveButton").text = "Okay"
	confirmwindow.find_node("SaveButton").connect("pressed",self,"on_deletion_confirmed")
	confirmwindow.window_title = "Warning: Layer Deletion Can Not Undone"
	Global.Editor.get_child("Windows").add_child(confirmwindow)

	var category = "Settings"
	var unique_id = "uchideshi34.ManageLayers"
	var mod_name = "Manage Layers"
	var icon = Global.Root + "icons/layerx2.png"

	# Make mod tool for exporting and importing preset values
	mod_tool_panel = Global.Editor.Toolset.CreateModTool(self, category, unique_id, mod_name, icon)
	mod_tool_panel.CreateNote("Add, rename and delete layers for this current level on the right hand panel.")
	mod_tool_panel.connect("visibility_changed", self, "on_mod_tool_visibility_changed")

	# Look for possible level changes
	Global.Editor.LevelOptions.connect("item_selected", self, "on_possible_level_change")
	Global.Editor.LevelOptions.get_parent().find_node("LevelUp").connect("pressed", self, "on_possible_level_change",["LevelUp"])
	Global.Editor.LevelOptions.get_parent().find_node("LevelDown").connect("pressed", self, "on_possible_level_change",["LevelDown"])

	# Note that this is not required for copied levels as item_selected triggers but keep for non-copied levels
	Global.Editor.Windows["NewLevel"].connect("popup_hide", self, "on_possible_level_change",["popup_hide"])
	Global.Editor.Windows["Export"].connect("popup_hide", self, "on_possible_level_change",["popup_hide"])

	Global.API.ModSignalingApi.add_user_signal("layers_changed")

	var _lib_mod_meta = Global.API.ModRegistry.get_mod_info("CreepyCre._Lib").mod_meta
	if _lib_mod_meta != null:
		if compare_semver("1.1.2", _lib_mod_meta["version"]):
			var update_checker = Global.API.UpdateChecker
			update_checker.register(Global.API.UpdateChecker.builder()\
													.fetcher(update_checker.github_fetcher("uchideshi34", "ConvertObjectIntoPattern"))\
													.downloader(update_checker.github_downloader("uchideshi34", "ConvertObjectIntoPattern"))\
													.build())
	
