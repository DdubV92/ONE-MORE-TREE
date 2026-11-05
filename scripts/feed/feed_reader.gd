class_name FeedReader
extends RefCounted
## Phase 17: the reading views of the camper computer's Mail, News, Forums
## and Archives apps (built into DeskComputer's content area). Bounded
## pages (no endless scroll), unread dots, bookmarks, thread depth, quoted
## context, edits and moderation notes, back navigation and restored
## scroll position. Reading is live time; leaving the desk returns control
## at once (the desk handles input).

const PAGE := 30
const MAX_DEPTH := 4


static func build(parent: Control, app: String, desk: Node) -> void:
	var feed: FeedService = Game.feed
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(root)
	if feed == null:
		root.add_child(_label("Offline.", 16))
		return
	var state: Dictionary = feed.positions.get(app, {"view": "list", "page": 0, "thread": "", "only_marked": false})
	feed.positions[app] = state
	if str(state.view) == "thread" and str(state.thread) != "":
		_thread(root, app, str(state.thread), feed, desk)
	else:
		_list(root, app, feed, desk, state)


static func _label(t: String, size := 15, color := UITheme.TEXT) -> Label:
	var l := UITheme.label(t, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func _refresh(desk: Node, app: String) -> void:
	if desk and desk.has_method("refresh_app"):
		desk.call("refresh_app", app)      # Phase 22: rebuild inside its window
	elif desk and desk.has_method("open_app"):
		desk.call("open_app", app)


static func _list(root: VBoxContainer, app: String, feed: FeedService, desk: Node, state: Dictionary) -> void:
	var head := HBoxContainer.new()
	root.add_child(head)
	head.add_child(UITheme.label({"Mail": "Inbox", "News": "News & notices", "Forums": "Forums", "Archives": "Archives"}.get(app, app), 19, UITheme.ACCENT))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var only := bool(state.get("only_marked", false))
	head.add_child(UITheme.button("Bookmarked" + (" *" if only else ""), func() -> void:
		state.only_marked = not only
		state.page = 0
		_refresh(desk, app), 0))
	head.add_child(UITheme.button("Mark all read", func() -> void:
		var ids: Array = []
		for t in feed.threads(app, 100000):
			for u in feed.thread_units(str(t.key)):
				ids.append(str(u.id))
		feed.mark_read(ids)
		_refresh(desk, app), 0))
	root.add_child(_label(feed.digest(app), 14, UITheme.MUTED))
	if app == "Mail":
		_supplier_notices(root)
	var page := int(state.get("page", 0))
	var all := feed.threads(app, 100000)
	if only:
		all = all.filter(func(t: Dictionary) -> bool: return feed.bookmarks.has(str(t.key)))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	if all.is_empty():
		v.add_child(_label("Nothing here yet. New messages and posts arrive with the days and nights." if not only else "No bookmarks.", 15, UITheme.MUTED))
	for t in all.slice(page * PAGE, page * PAGE + PAGE):
		var key := str(t.key)
		var title := str(t.title) if str(t.title) != "" else "(no subject)"
		var site := _site_name(str(t.site))
		var txt := "%s%s%s  ·  %s  ·  %d%s" % ["● " if int(t.unread) > 0 else "   ", "★ " if feed.bookmarks.has(key) else "", title, site, int(t.count), (" (%d new)" % int(t.unread)) if int(t.unread) > 0 else ""]
		var b := UITheme.button(txt, func() -> void:
			state.view = "thread"
			state.thread = key
			_refresh(desk, app), 0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_ALL
		v.add_child(b)
	var nav := HBoxContainer.new()
	root.add_child(nav)
	if page > 0:
		nav.add_child(UITheme.button("Newer", func() -> void:
			state.page = page - 1
			_refresh(desk, app), 0))
	if (page + 1) * PAGE < all.size():
		nav.add_child(UITheme.button("Older", func() -> void:
			state.page = page + 1
			_refresh(desk, app), 0))
	nav.add_child(_label("%d threads · page %d of %d" % [all.size(), page + 1, maxi(1, ceili(all.size() / float(PAGE)))], 13, UITheme.MUTED))
	feed.visit(app)


static func _supplier_notices(root: VBoxContainer) -> void:
	var cs: CampaignService = Game.campaign
	if cs == null or not cs.active or cs.supplier == null or cs.supplier.orders.is_empty():
		return
	var o: Dictionary = cs.supplier.orders[cs.supplier.orders.size() - 1]
	root.add_child(_label("Camp Supply (live order status): order %s - %s" % [str(o.id), cs.supplier.state_words(o)], 14, UITheme.ACCENT))


static func _site_name(s: String) -> String:
	return {"soundboard": "The Sound Board", "lamphours": "Lamp Hours", "lowband": "LowBand", "dellow": "Dellow Court Residents", "harbour": "Gilliver Harbour Chat", "courier": "The Ammet Courier", "soundfm": "Sound FM News", "weypost": "Weyhaven Evening Post", "tradejournal": "Timber & Land Trade Journal", "met": "Met Office", "ferry": "Sound Lines", "power": "Sound Power Co-op", "council": "Ammet District Council", "coast": "Coastguard", "history": "History Society wiki", "fieldnotes": "Field Notes", "courierarchive": "Courier archive", "lowbandarchive": "LowBand archive", "mail": "Mail"}.get(s, s)


static func when_words(u: Dictionary) -> String:
	var s := "Day %d, %s" % [int(u.get("day", 0)), {"day": "daytime", "dusk": "dusk", "night": "night"}.get(str(u.get("slot", "day")), "")]
	var oc: Dictionary = u.get("occurred", {})
	if not oc.is_empty():
		s += "  ·  about something at %s %s on day %d" % [str(oc.get("local", "")), str(oc.get("tz", "ST")), int(oc.get("day", u.get("day", 0)))]
	return s


static func _thread(root: VBoxContainer, app: String, key: String, feed: FeedService, desk: Node) -> void:
	var state: Dictionary = feed.positions[app]
	var units := feed.thread_units(key)
	var head := HBoxContainer.new()
	root.add_child(head)
	head.add_child(UITheme.button("< Back", func() -> void:
		state.view = "list"
		_refresh(desk, app), 0))
	var marked := feed.bookmarks.has(key)
	head.add_child(UITheme.button("Unbookmark" if marked else "Bookmark", func() -> void:
		feed.toggle_bookmark(key)
		_refresh(desk, app), 0))
	var title := ""
	for u in units:
		if str(u.get("title", "")) != "":
			title = str(u.title)
			break
	head.add_child(_label(title, 17, UITheme.ACCENT))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	var ids: Array = []
	for u in units:
		ids.append(str(u.id))
		var box := MarginContainer.new()
		box.add_theme_constant_override("margin_left", 22 * mini(feed.depth(u), MAX_DEPTH))
		v.add_child(box)
		var pv := VBoxContainer.new()
		box.add_child(pv)
		var unread := not feed.read.has(str(u.id))
		var who := feed.author_name(u)
		if str(u.kind) == "mail":
			who = "From: " + who
		pv.add_child(_label("%s%s  ·  %s%s" % ["● " if unread else "", who, when_words(u), ("  ·  %d" % int(u.votes)) if u.has("votes") else ""], 13, UITheme.MUTED))
		var q := str(u.get("quote", ""))
		if q != "" and feed.visible(q):
			var qu := FeedService.unit(q)
			pv.add_child(_label("> %s: %s" % [feed.author_name(qu), feed.shown_text(qu).left(160)], 13, UITheme.MUTED))
		var st := str(u.get("status", "ok"))
		pv.add_child(_label(feed.shown_text(u), 15, UITheme.MUTED if st == "removed" else UITheme.TEXT))
		if st == "locked":
			pv.add_child(_label("[Thread locked by a moderator.]", 13, UITheme.ACCENT))
	feed.mark_read(ids)
	# Scroll restoration per thread.
	var pos := int((feed.positions.get("scroll", {}) as Dictionary).get(key, 0))
	sc.set_deferred("scroll_vertical", pos)
	sc.get_v_scroll_bar().value_changed.connect(func(val: float) -> void:
		if not feed.positions.has("scroll"):
			feed.positions["scroll"] = {}
		feed.positions["scroll"][key] = int(val))
