class_name ToolShop
extends StaticBody3D
## The tool rack / ledger at the lean-to: opens the axe shop (Phase 3).


func get_interact_text() -> String:
	var c: CampaignService = Game.campaign
	if c and c.active:
		return "Axe rack: buy or equip axes"
	return "Inspect axe rack"


func interact(by: Node) -> void:
	var ui: CampaignUI = Game.campaign_ui
	if ui:
		ui.open_shop()
	elif by.has_method("show_message"):
		by.show_message("Small, medium and large axes.")
