class_name SleepSpot
extends StaticBody3D
## The camper bed (Phase 3). A generous interaction volume over the whole
## mattress, so it is easy to select in the dark. Sleeping ends the day
## through CampaignService.sleep() (locked, idempotent settlement).
## Later: the once-only dog-rescue objective can block ordinary sleep via
## `blocked_reason` (a state guard; no rescue exists yet).

var blocked_reason := ""


func get_interact_text() -> String:
	var c: CampaignService = Game.campaign
	if c == null or not c.active:
		return "Bed (sleeping ends the day in the campaign)"
	if blocked_reason != "":
		return blocked_reason
	var ok := c.can_sleep()
	if bool(ok.ok):
		return "Sleep: end day %d%s" % [c.clock.day, "  (the contract closes)" if c.clock.is_final_day() and not c.legacy else ""]
	return str(ok.reason)


func interact(by: Node) -> void:
	var c: CampaignService = Game.campaign
	if c == null or not c.active or blocked_reason != "":
		return
	var res := c.sleep()
	if not bool(res.get("ok", false)) and by.has_method("show_message") and str(res.get("reason", "")) != "":
		by.show_message(str(res.reason))
