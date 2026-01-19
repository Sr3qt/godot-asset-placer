@tool
extends PopupMenu
class_name CollectionPicker

const _SUFFIX: = " (*)"

signal collection_selected(collection: AssetCollection, selected: bool)

@onready var presenter := AssetCollectionsPresenter.new()

var pre_selected: Array[AssetCollection]
var all_pre_selected: Array[AssetCollection]
var any_pre_selected: Array[AssetCollection]

var _tags_count : Dictionary[int, int]
var _selected_count: int

func _ready():
	hide_on_checkable_item_selection = false
	presenter.show_collections.connect(show_collections)
	presenter.show_empty_view.connect(show_empty_view)
	presenter.ready()


func show_empty_view():
	add_item("No Collections added yet")
	index_pressed.connect(func(i):
		AssetPlacerDockPresenter.instance.show_tab.emit(
			AssetPlacerDockPresenter.Tab.Collections
		)
	)

func show_collections(collections: Array[AssetCollection]):
	var circle_tex := load("uid://ofkf56gtg5g3") # Circle.svg
	for i in collections.size():
		var collection_id: = collections[i].id
		var collection_name: = collections[i].name

		add_check_item(collection_name)
		var selected: = false
		if not pre_selected.is_empty():
			selected = pre_selected.any(func(c): return c.id == collection_id)
		else:
			if _tags_count.has(collection_id):
				selected = _tags_count[collection_id] == _selected_count

				if not selected:
					# collection_name += " (partially selected)"
					set_item_tooltip(i, "%s/%s selected assets in collection." % [
						_tags_count[collection_id], _selected_count]
					)
					set_item_text(i, collection_name + _SUFFIX)

		set_item_checked(i, selected)
		set_item_icon(i, circle_tex)
		set_item_icon_modulate(i, collections[i].backgroundColor)

	index_pressed.connect(func(index):
		toggle_item_checked(index)
		if not get_item_tooltip(index).is_empty():
			set_item_tooltip(index, "")
			set_item_text(index, get_item_text(index).left(-_SUFFIX.length()))
		collection_selected.emit(collections[index], is_item_checked(index))
	)

static func show_in(context: Control, selected: Array[AssetCollection], on_select: Callable):
	var picker: CollectionPicker = CollectionPicker.new()
	picker.collection_selected.connect(on_select)
	picker.pre_selected = selected
	var size = picker.get_contents_minimum_size()
	var position = DisplayServer.mouse_get_position()
	EditorInterface.popup_dialog(picker, Rect2(position, size))

static func show_at(
		top_left: Vector2,
		on_select: Callable,
		selected: Array[AssetCollection],
	):
	var picker: CollectionPicker = CollectionPicker.new()
	picker.collection_selected.connect(on_select)
	picker.pre_selected = selected
	var size: = picker.get_contents_minimum_size()
	EditorInterface.popup_dialog(picker, Rect2(top_left, size))

static func show_dynamic_at(
		top_left: Vector2,
		on_select: Callable,
		tags_count : Dictionary[int, int],
		selected_count : int
	):
	var picker: CollectionPicker = CollectionPicker.new()
	picker.collection_selected.connect(on_select)
	picker._tags_count = tags_count
	picker._selected_count = selected_count
	var size: = picker.get_contents_minimum_size()
	EditorInterface.popup_dialog(picker, Rect2(top_left, size))
