@tool
extends Button
class_name  AssetResourcePreview

signal left_clicked(asset: AssetResourcePreview)
signal right_clicked(asset: AssetResourcePreview)
signal shift_clicked(asset: AssetResourcePreview)
signal ctrl_clicked(asset: AssetResourcePreview)

@onready var label = %Label
@onready var asset_thumbnail = %AssetThumbnail
var resource: AssetResource
var settings_repo = AssetPlacerSettingsRepository.instance
var default_size: Vector2

func _ready():
	default_size = size
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_settings(settings_repo.get_settings())
	settings_repo.settings_changed.connect(set_settings)

	if is_instance_valid(resource):
		label.text = resource.name
		asset_thumbnail.set_resource(resource)

func set_asset(asset: AssetResource):
	self.resource = asset
	if is_instance_valid(label):
		label.text = asset.name
	if is_instance_valid(asset_thumbnail):
		asset_thumbnail.set_resource(asset)

func set_settings(settings: AssetPlacerSettings):
	custom_minimum_size = default_size * settings.ui_scale

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			right_clicked.emit(self)

		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if event.shift_pressed:
				shift_clicked.emit(self)
			elif event.ctrl_pressed:
				ctrl_clicked.emit(self)
			else:
				left_clicked.emit(self)