class_name ItemDb
extends RefCounted


static var _items: Dictionary = { }


static func items() -> Dictionary:
	if _items.is_empty():
		_items = {
			"bucket": {
				"name": Cfg.tr("Bucket"),
				"price": Cfg.PRICE_BUCKET,
				"blurb": Cfg.tr("Holds %d strands of hay.") % Cfg.BUCKET_CAPACITY,
				"unlock": "bucket",
			},
			"sand_shovel": {


				"name": Cfg.tr("Toy Shovel"),
				"price": Cfg.PRICE_SAND_SHOVEL,
				"blurb": Cfg.tr("A small shovel. Digs %d strands at a time.") % SandShovel.SCOOP_MAX,
				"unlock": "sand_shovel",
			},
			"wheelbarrow": {
				"name": Cfg.tr("Wheelbarrow"),
				"price": Cfg.PRICE_WHEELBARROW,
				"blurb": Cfg.tr("Holds %d strands of hay.") % Cfg.BARROW_CAPACITY,
				"unlock": "wheelbarrow",
			},


			"spade": {
				"name": Cfg.tr("Spade"),
				"price": Cfg.PRICE_SPADE,
				"blurb": Cfg.tr("Digs %d strands at a time.") % Cfg.SCOOP_MAX,
				"unlock": "spade",
			},
			"pitchfork": {
				"name": Cfg.tr("Pitchfork"),
				"price": Cfg.PRICE_PITCHFORK,
				"blurb": Cfg.tr("Lifts %d strands at a time.") % Pitchfork.SCOOP_MAX,
				"unlock": "pitchfork",
			},
			"broom": {
				"name": Cfg.tr("Broom"),
				"price": Cfg.PRICE_BROOM,
				"blurb": Cfg.tr("Pushes spilled hay along the floor."),
				"unlock": "broom",
			},


			"metal_detector": {
				"name": Cfg.tr("Metal Detector"),
				"price": Cfg.PRICE_METAL_DETECTOR,
				"blurb": Cfg.tr("Finds needles you cannot see. Shows how close, not which way."),
				"unlock": "metal_detector",
			},


			"yard_vac": {
				"name": Cfg.tr("Yard Vac"),
				"price": Cfg.PRICE_YARD_VAC,
				"blurb": Cfg.tr("Left click sucks up hay. Right click pours it out."),
				"unlock": "yard_vac",
			},


			"lighter": {
				"name": Cfg.tr("Lighter"),
				"price": Cfg.PRICE_LIGHTER,
				"blurb": Cfg.tr("Burns around %d strands. You can use it every %d seconds.") % [Cfg.LIGHTER_BURN_STRANDS, int(Cfg.LIGHTER_COOLDOWN)],
				"unlock": "lighter",
			},


			"hay_bale": {
				"name": Cfg.tr("Hay Bale"),
				"price": 0.0,
				"blurb": Cfg.tr("%d strands pressed into a bale. Worth %.1fx loose hay.") % [
					Cfg.COMPRESSOR_BALE_STRANDS, Cfg.COMPRESSOR_BALE_RATIO],
			},


			"foiled_bale": {
				"name": Cfg.tr("Wrapped Bale"),
				"price": 0.0,
				"blurb": Cfg.tr("A wrapped bale. Worth %.2fx a normal bale.") % Cfg.WRAPPER_FOILED_RATIO,
			},


			"eco_brick": {
				"name": Cfg.tr("Eco Brick"),
				"price": 0.0,


				"blurb": Cfg.tr("A fuel brick made from hay. Worth %.1fx the hay in it.") % Cfg.PELLETIZER_BRICK_RATIO,
			},


			"hay_pulp": {
				"name": Cfg.tr("Pulp Slab"),
				"price": 0.0,


				"blurb": Cfg.tr("Wet hay pulp. Worth %.1fx the hay in it. Used to make paper.") % Cfg.PULPER_PULP_RATIO,
			},


			"paper_roll": {
				"name": Cfg.tr("Paper Roll"),
				"price": 0.0,
				"blurb": Cfg.tr("A roll of paper made from pulp slabs. Worth %.2fx the slabs.") % Cfg.PAPER_ROLL_RATIO,
			},


			"feed_disc": {
				"name": Cfg.tr("Feed Disc"),
				"price": 0.0,
				"blurb": Cfg.tr("Hay and eco bricks pressed into a disc. Worth %.1fx the hay in it.") % Cfg.BRIQUETTE_DISC_RATIO,
			},


			"hay_wad": {
				"name": Cfg.tr("Hay Wad"),
				"price": 0.0,
				"blurb": Cfg.tr("A bundle of up to %d strands of hay.") % Cfg.WAD_MAX_STRANDS,
			},


			"hay_tuft": {
				"name": Cfg.tr("Hay Tuft"),
				"price": 0.0,
				"blurb": Cfg.tr("A small clump of up to %d strands of hay.") % Cfg.TUFT_MAX,
			},
		}
	return _items


static func invalidate() -> void:
	_items = { }


static func ids() -> Array:
	return items().keys()


static func has_item(id: String) -> bool:
	return items().has(id)


static func spec(id: String) -> Dictionary:
	return items().get(id, { })


static func display_name(id: String) -> String:
	var text:= str(spec(id).get("name", ""))
	return Cfg.tr(text) if text != "" else id


static func price(id: String) -> float:
	return spec(id).get("price", 0.0)


static func unlock_of(id: String) -> String:
	return str(spec(id).get("unlock", ""))


static func is_unlocked(id: String) -> bool:
	var node:= unlock_of(id)
	return node == "" or Tech.is_unlocked(node)


static func make(id: String) -> Carryable:
	var item: Carryable = null
	match id:
		"bucket":
			item = Bucket.new()
		"sand_shovel":
			item = SandShovel.new()
		"wheelbarrow":
			item = Wheelbarrow.new()
		"hay_bale":
			item = HayBale.new()
		"foiled_bale":
			item = FoiledBale.new()
		"hay_wad":
			item = HayWad.new()
		"hay_tuft":
			item = HayTuft.new()
		"eco_brick":
			item = EcoBrick.new()
		"hay_pulp":
			item = HayPulp.new()
		"paper_roll":
			item = PaperRoll.new()
		"feed_disc":
			item = FeedDisc.new()
		"spade", "pitchfork", "broom", "metal_detector", "yard_vac", "lighter":


			var t:= ToolProp.new()
			t.tool_id = id
			item = t
		_:
			push_warning("ItemDb: no such item '%s'" % id)
			return null
	item.item_id = id
	item.display_name = display_name(id)
	item.name = id
	return item
