@tool
extends Control
class_name AssetLibraryWindow

## If true, keep selected previews when assets are refreshed.
var keep_selected := true
var selected_previews : Array[AssetResourcePreview] = []

var _new_assets: Array[AssetResource]

@onready var presenter = AssetLibraryPresenter.new()
@onready var folder_presenter = FolderPresenter.new()

@onready var placer_presenter := AssetPlacerPresenter._instance
@onready var grid_container: Container = %GridContainer
@onready var preview_resource = preload("res://addons/asset_placer/ui/components/asset_resource_preview.tscn")
@onready var unhandled_click_handler = %UnhandledClickHandler

@onready var add_folder_button: Button = %AddFolderButton
@onready var search_field: LineEdit = %SearchField
@onready var filter_button: Button = %FilterButton
@onready var filters_label: Label = %FiltersLabel
@onready var reload_button: Button = %ReloadButton

@onready var progress_bar = %ProgressBar
@onready var empty_content = %EmptyContent
@onready var main_content = %MainContent
@onready var empty_collection_content = %EmptyCollectionContent
@onready var empty_collection_view_add_folder_btn: Button = %EmptyCollectionViewAddFolderBtn
@onready var scroll_container = %ScrollContainer
@onready var empty_search_content = %EmptySearchContent
@onready var empty_view_add_folder_btn = %EmptyViewAddFolderBtn


func _ready():
	presenter.assets_loaded.connect(func(assets): _new_assets = assets)
	presenter.show_filter_info.connect(show_filter_info)
	presenter.show_sync_active.connect(show_sync_in_progress)

	empty_collection_view_add_folder_btn.pressed.connect(show_folder_dialog)
	empty_view_add_folder_btn.pressed.connect(show_folder_dialog)
	presenter.show_empty_view.connect(show_empty_view)

	presenter.on_ready()
	add_folder_button.pressed.connect(show_folder_dialog)
	search_field.text_changed.connect(presenter.on_query_change)
	reload_button.pressed.connect(presenter.sync)
	filter_button.pressed.connect(func ():
		CollectionPicker.show_at(
			filter_button.get_screen_position() + Vector2(filter_button.size.x, 0),
			presenter.toggle_collection_filter,
			presenter._active_collections,
		)
	)

	unhandled_click_handler.pressed.connect(clear_selected_previews)

func _process(_delta: float) -> void:
	if not _new_assets.is_empty():
		show_assets(_new_assets)
		_new_assets = []

func show_assets(assets: Array[AssetResource]):
	placer_presenter.current_assets = assets
	empty_collection_content.hide()
	scroll_container.show()

	var previous_ids : Array[String]
	if keep_selected:
		for preview in selected_previews:
			previous_ids.append(preview.resource.id)

	clear_selected_previews()
	for child in grid_container.get_children():
		child.queue_free()

	for asset in assets:
		var child: AssetResourcePreview = preview_resource.instantiate()
		child.left_clicked.connect(_on_preview_left_clicked)
		child.right_clicked.connect(_on_preview_right_clicked)
		child.shift_clicked.connect(_on_preview_shift_clicked)
		child.ctrl_clicked.connect(_on_preview_ctrl_clicked)
		grid_container.add_child(child)
		child.set_asset(asset)

		if keep_selected and asset.id in previous_ids:
			selected_previews.append(child)
			child.set_pressed_no_signal(true)

func show_asset_menu(asset: AssetResource, control: Control):
	var options_menu := PopupMenu.new()
	var mouse_pos = DisplayServer.mouse_get_position()
	options_menu.add_icon_item(EditorIconTexture2D.new("Groups"), "Manage collections")
	options_menu.add_icon_item(EditorIconTexture2D.new("File"), "Open")
	options_menu.add_icon_item(EditorIconTexture2D.new("Remove"), "Remove")
	options_menu.index_pressed.connect(func(index):
		match index:
			0:
				CollectionPicker.show_dynamic_at(
					mouse_pos,
					_on_collection_button_pressed,
					_get_selected_tags_count(),
					selected_previews.size(),
				)
			1:
				EditorInterface.open_scene_from_path(asset.scene.resource_path)
				EditorInterface.set_main_screen_editor("3D")
			2:
				if placer_presenter._selected_asset == asset:
					placer_presenter.clear_selection()
				presenter.delete_asset(asset)
			_:
				pass
	)
	EditorInterface.popup_dialog(options_menu, Rect2(mouse_pos, options_menu.get_contents_minimum_size()))

func show_folder_dialog():
	var folder_dialog = EditorFileDialog.new()
	folder_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	folder_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	folder_dialog.dir_selected.connect(presenter.add_asset_folder)
	EditorInterface.popup_dialog_centered(folder_dialog)

func _can_drop_data(at_position, data):
	if data is Dictionary:
		var type = data["type"]
		var files_or_dirs = type == "files_and_dirs" || type == "files"
		return files_or_dirs and data.has("files")
	return false

func _drop_data(at_position, data):
	var dirs: PackedStringArray = data["files"]
	presenter.add_assets_or_folders(dirs)

func show_filter_info(size: int):
	if size == 0:
		filters_label.hide()
	else:
		filters_label.show()
		filters_label.text = str(size)

func _get_selected_tags_count() -> Dictionary[int, int]:
	var tags: Dictionary[int, int] = {}
	for preview in selected_previews:
		for tag in preview.resource.tags:
			if not tag in tags:
				tags[tag] = 1
			else:
				tags[tag] += 1
	return tags

func get_selected_collections_count() -> Dictionary[AssetCollection, int]:
	var dict: = _get_selected_tags_count()
	var out: Dictionary[AssetCollection, int] = {}
	for key in dict.keys():
		var collection: = AssetCollection.new("name", Color(), key)
		out[collection] = dict[key]
	return out

func get_selected_assets() -> Array[AssetResource]:
	var out: Array[AssetResource] = []
	for preview in selected_previews:
		out.append(preview.resource)
	return out

func clear_selected_previews():
	for preview in selected_previews:
		preview.set_pressed_no_signal(false)
	selected_previews.clear()
	AssetPlacerPresenter._instance.clear_selection()

func set_presenter_asset(preview: AssetResourcePreview):
	selected_previews.append(preview)
	AssetPlacerPresenter._instance.select_asset(preview.resource)

## Select all previews between from and to, both inclusively.
func select_preview_range(from : int, to : int):
	var size: = grid_container.get_children().size()
	assert(absi(from) < size)
	assert(absi(to) < size)

	var _from: = mini((from + size) % size, (to + size) % size)
	var _to: = maxi((from + size) % size, (to + size) % size)

	for child in grid_container.get_children().slice(_from, _to + 1):
		if child is AssetResourcePreview:
			if child not in selected_previews:
				selected_previews.append(child)
				child.set_pressed_no_signal(true)

func show_empty_view(type: AssetLibraryPresenter.EmptyType):
	match type:
		AssetLibraryPresenter.EmptyType.Search:
			show_empty_search_content()
		AssetLibraryPresenter.EmptyType.Collection:
			show_empty_collection_view()
		AssetLibraryPresenter.EmptyType.All:
			show_onboarding()
		AssetLibraryPresenter.EmptyType.None:
			show_main_content()

func show_main_content():
	main_content.show()
	empty_content.hide()
	scroll_container.show()
	empty_collection_content.hide()
	empty_search_content.hide()

func show_onboarding():
	main_content.hide()
	empty_collection_content.hide()
	empty_search_content.hide()
	empty_content.show()

func show_empty_collection_view():
	main_content.show()
	scroll_container.hide()
	empty_collection_content.hide()
	empty_collection_content.show()
	empty_content.hide()

func show_empty_search_content():
	main_content.show()
	scroll_container.hide()
	empty_collection_content.hide()
	empty_search_content.show()

func show_sync_in_progress(active: bool):
	if active:
		reload_button.hide()
		progress_bar.show()
	else:
		reload_button.show()
		progress_bar.hide()

func _on_preview_left_clicked(preview: AssetResourcePreview) -> void:
	if selected_previews.is_empty():
		set_presenter_asset(preview)
	elif selected_previews.size() == 1 and preview in selected_previews:
		clear_selected_previews()
	else:
		clear_selected_previews()
		set_presenter_asset(preview)
		preview.set_pressed_no_signal(true)

func _on_preview_right_clicked(preview: AssetResourcePreview) -> void:
	show_asset_menu(preview.resource, preview)

func _on_preview_shift_clicked(preview: AssetResourcePreview) -> void:
	if selected_previews.is_empty():
		set_presenter_asset(preview)

	if selected_previews.size() == 1 and preview in selected_previews:
		preview.set_pressed_no_signal(!preview.is_pressed())
		return

	var children: = grid_container.get_children()
	var preview_index: = children.find(preview)

	var start_preview: = selected_previews[0]
	var start_index: = children.find(start_preview)

	assert(preview_index != -1)
	assert(start_index != -1)

	var new_start_index: = _get_index_last_connected(start_index, preview_index)
	if new_start_index == preview_index:
		preview.set_pressed_no_signal(!preview.is_pressed())
		return

	clear_selected_previews()

	select_preview_range(new_start_index, preview_index)

func _get_index_last_connected(start_index : int, preview_index : int) -> int:
	if start_index == 0 or start_index == grid_container.get_children().size():
		return start_index

	var end_index: = -(grid_container.get_children().size() + 1)
	var reverse: = -1
	if start_index >= preview_index:
		end_index = grid_container.get_children().size()
		reverse = 1

	var new_start_index = start_index
	start_index = start_index + reverse

	for child in grid_container.get_children().slice(start_index, end_index, reverse):
		if child in selected_previews:
			new_start_index += reverse
		else:
			break

	return new_start_index

func _on_preview_ctrl_clicked(preview: AssetResourcePreview) -> void:
	if preview in selected_previews:
		if selected_previews.size() == 1:
			clear_selected_previews()
		else:
			selected_previews.erase(preview)
	else:
		if selected_previews.is_empty():
			set_presenter_asset(preview)
		else:
			selected_previews.append(preview)

func _on_collection_button_pressed(collection, add):
	presenter.set_assets_collection(get_selected_assets(), collection, add)

