class_name ToolShop
extends StaticBody3D
## The tool rack at the lean-to: camp storage, equipping and issuing gear
## (Phase 14; purchases happen on the camper computer).


func get_interact_text() -> String:
	var c: CampaignService = Game.campaign
	if c and c.active:
		return "Tool rack: your gear and camp storage"
	return "Inspect axe rack"


func interact(by: Node) -> void:
	var ui: CampaignUI = Game.campaign_ui
	if ui:
		ui.open_shop()
	elif by.has_method("show_message"):
		by.show_message("Small, medium and large axes.")
