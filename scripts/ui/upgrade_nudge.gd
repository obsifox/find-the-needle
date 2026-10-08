class_name UpgradeNudge
extends Node


const SHOW_FOR:= 7.0

var player: Player
var hud: Hud


var _dry_seen:= -1
var _shed_seen:= -1


var _breath_owed:= false


var _full_seen:= -1
var _arms_owed:= false


const BREATH_OWED:= 120.0


func _process(_delta: float) -> void:
	if player == null or hud == null:
		return

	var dry:= player.spent_refusals + player.stamina.ran_dry + player.stamina.ran_low
	if _dry_seen >= 0 and dry > _dry_seen:
		_breath_owed = true
	_dry_seen = dry
	if _breath_owed:
		if _out_of_breath() or player.stamina.since_low() > BREATH_OWED:
			_breath_owed = false
	if player.carry != null:
		var full:= player.carry.arms_full
		if _full_seen >= 0 and full > _full_seen:
			_arms_owed = true
		_full_seen = full


		if _arms_owed:
			if _arms_full() or player.carry.since_full() > BREATH_OWED:
				_arms_owed = false
	var shed:= player.build.shed_refusals if player.build != null else 0
	if _shed_seen >= 0 and shed > _shed_seen:
		_out_of_room()
	_shed_seen = shed
	var hand:= player.hand
	if hand != null and hand.is_holding() and hand.is_full() and not hand.is_holding_needle():
		_hands_full()
	_rake_on_the_floor(_delta)


const FLOOR_LOADS:= 3
const FLOOR_REACH:= 1.8
const FLOOR_NUDGE:= "rake_floor"


const FLOOR_SHOW_FOR:= 12.0
var _floor_clock:= 0.0


func _rake_on_the_floor(delta: float) -> void:
	if not Cfg.teach_hints or Cfg.nudge_given(FLOOR_NUDGE):
		return
	_floor_clock -= delta
	if _floor_clock > 0.0:
		return
	_floor_clock = 1.0
	var tool:= player.build
	if tool == null or tool.builds == null:
		return
	var builds: BuildManager = tool.builds
	if builds.piston_rakes.is_empty() or builds.props == null:
		return
	for rake: PistonRake in builds.piston_rakes:
		if not is_instance_valid(rake):
			continue
		var spot:= rake.discharge_spot()
		var lying:= 0
		for item: Carryable in builds.props.items:
			var wad:= item as HayWad
			if wad == null or not is_instance_valid(wad):
				continue
			var at:= wad.global_position
			if Vector2(at.x - spot.x, at.z - spot.z).length() > FLOOR_REACH:
				continue
			if at.y > spot.y + 0.8 or wad.linear_velocity.length() > 0.3:
				continue
			lying += 1
		if lying >= FLOOR_LOADS:
			Cfg.give_nudge(FLOOR_NUDGE)
			hud.show_toast(Cfg.tr("Your rake is dropping hay on the floor. Put a conveyor or wheelbarrow there."), FLOOR_SHOW_FOR)
			return


func _hands_full() -> void:
	if not _may_name("hand_carry"):
		return


	if not MissionBook.reached("buy_toy_licence"):
		return
	if not bool(Tech.can_buy("hand_carry") ["ok"]):
		return
	_name("hand_carry",
		Cfg.tr("Hands full? Press {key:tech_tree} and buy {card:hand_carry}. You carry more hay on every trip."))


func _out_of_breath() -> bool:
	if not _may_name("strong_back"):
		return true

	if Tech.rank_of("second_wind") > 0:
		return true
	if not bool(Tech.can_buy("strong_back") ["ok"]):
		return false
	_name("strong_back",
		Cfg.tr("Out of breath? Press {key:tech_tree} and buy {card:strong_back}. It gives you more stamina."))
	return true


func _arms_full() -> bool:
	if not _may_name("arm_load"):
		return true
	if not bool(Tech.can_buy("arm_load") ["ok"]):
		return false
	_name("arm_load",
		Cfg.tr("Arms full? Press {key:tech_tree} and buy {card:arm_load}. You can carry one more bale on every trip."))
	return true


func _out_of_room() -> void:
	if not _may_name("yard_space"):
		return
	_name("yard_space",
		Cfg.tr("Out of room? Press {key:tech_tree} and buy {card:yard_space}. It makes the shed bigger."))


func _may_name(id: String) -> bool:
	return Cfg.teach_hints and not Cfg.nudge_given(id) and TechTree.has_id(id) and Tech.rank_of(id) == 0 and not Tech.off_site(id)


func _name(id: String, line: String) -> void:
	Cfg.give_nudge(id)
	hud.show_toast(GameTips.fill(line), SHOW_FOR)
	if player.tech_panel != null:
		player.tech_panel.set_nudge(id)
