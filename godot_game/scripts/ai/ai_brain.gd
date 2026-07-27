extends Node
class_name AIBrain

# AI Brain - Personality-Driven Decision Making System
# Uses trait scores to drive strategic choices

var civilization: Dictionary
var personality: Dictionary
var world_state: Dictionary
var memory: Dictionary
var decision_weights: Dictionary

func _ready() -> void:
	memory = {
		"threats": [],
		"allies": [],
		"resources_found": [],
		"failed_strategies": [],
		"successful_actions": []
	}

# Load civilization personality from JSON data
func initialize(civ_data: Dictionary) -> void:
	civilization = civ_data
	personality = civ_data.get("personality", {})
	decision_weights = load_decision_weights()
	print("AI Brain initialized for: ", civ_data.get("name", "Unknown"))

# Load decision weights based on personality traits
func load_decision_weights() -> Dictionary:
	var weights = {}
	var personalities_file = preload("res://data/personalities.json")
	
	if personalities_file:
		weights = personalities_file.get("personality_weights", {})
	
	return weights

# ==== CORE DECISION FUNCTIONS ====

# Decide whether to attack a neighboring unit/city
func should_attack_target(enemy_strength: float, our_strength: float, enemy_distance: float) -> bool:
	var aggression = personality.get("aggression", 0.5)
	var risk_tolerance = personality.get("risk_tolerance", 0.5)
	var defense_priority = personality.get("defense_priority", 0.5)
	
	# Calculate attack probability based on traits
	var strength_ratio = our_strength / max(enemy_strength, 0.1)
	var aggression_factor = aggression * risk_tolerance
	var threat_level = 1.0 / (1.0 + strength_ratio)  # Sigmoid-like threat assessment
	
	# Attack if we have advantage OR we're aggressive enough to take risks
	var attack_threshold = 0.6 - (aggression_factor * 0.3)
	var attack_score = (strength_ratio * 0.6) + (aggression_factor * 0.4)
	
	record_decision("attack_evaluation", {
		"target_distance": enemy_distance,
		"attack_score": attack_score,
		"threshold": attack_threshold,
		"decision": attack_score > attack_threshold
	})
	
	return attack_score > attack_threshold

# Decide whether to expand (settle new city)
func should_expand(available_tiles: int, current_cities: int, economic_pressure: float) -> bool:
	var expansionism = personality.get("expansionism", 0.5)
	var economic_focus = personality.get("economic_focus", 0.5)
	var risk_tolerance = personality.get("risk_tolerance", 0.5)
	
	# Expansion pressure increases with expansionism trait
	var expansion_desire = expansionism * risk_tolerance
	var resource_availability = min(available_tiles / 20.0, 1.0)  # Normalize to 0-1
	var economic_pressure_factor = 1.0 - (economic_pressure * 0.5)  # Less likely if economically strained
	
	var expand_score = (expansion_desire * 0.5) + (resource_availability * 0.3) + (economic_pressure_factor * 0.2)
	var expand_threshold = 0.45
	
	record_decision("expansion_evaluation", {
		"available_tiles": available_tiles,
		"expand_score": expand_score,
		"threshold": expand_threshold,
		"decision": expand_score > expand_threshold
	})
	
	return expand_score > expand_threshold

# Decide whether to research a specific technology
func choose_research_priority(available_techs: Array, current_resources: Dictionary) -> String:
	var tech_focus = personality.get("tech_focus", 0.5)
	var military_priority = personality.get("aggression", 0.5)
	var economic_focus = personality.get("economic_focus", 0.5)
	
	var best_tech = ""
	var best_score = 0.0
	
	for tech in available_techs:
		var tech_score = calculate_tech_value(tech, military_priority, economic_focus, tech_focus)
		
		if tech_score > best_score:
			best_score = tech_score
			best_tech = tech
	
	record_decision("tech_research_choice", {
		"chosen_tech": best_tech,
		"score": best_score,
		"available_count": available_techs.size()
	})
	
	return best_tech

# Calculate value of a technology for this AI
func calculate_tech_value(tech_name: String, military_priority: float, economic_priority: float, tech_focus: float) -> float:
	var tech_values = {
		"bronze_working": military_priority * 0.8,
		"iron_working": military_priority * 0.9,
		"military_tactics": military_priority * 1.0,
		"agriculture": economic_priority * 0.7,
		"currency": economic_priority * 1.0,
		"navigation": economic_priority * 0.8,
		"mathematics": tech_focus * 0.9,
		"astronomy": tech_focus * 1.0,
		"computers": tech_focus * 1.2,
		"masonry": personality.get("defense_priority", 0.5) * 0.9,
		"engineering": tech_focus * 0.8
	}
	
	var base_value = tech_values.get(tech_name, 0.5)
	var research_bonus = tech_focus * 0.3  # Those who focus on tech get bonus
	
	return base_value + research_bonus

# Decide diplomatic stance toward another civilization
func evaluate_diplomatic_stance(other_civ: Dictionary, relations: float, military_balance: float) -> String:
	var diplomatic_trust = personality.get("diplomatic_trust", 0.5)
	var aggression = personality.get("aggression", 0.5)
	var economic_focus = personality.get("economic_focus", 0.5)
	
	# Relations: -1.0 (enemy) to 1.0 (ally)
	# Military balance: our_strength / (our_strength + their_strength)
	# Results in: "ally", "neutral", "hostile"
	
	var trust_factor = diplomatic_trust * relations
	var military_confidence = military_balance - 0.5  # -0.5 to 0.5
	var aggression_hostility = aggression * 0.4
	
	var stance_score = trust_factor + military_confidence - aggression_hostility
	
	var stance = "neutral"
	if stance_score > 0.3:
		stance = "ally"
	elif stance_score < -0.3:
		stance = "hostile"
	
	record_decision("diplomatic_stance", {
		"target_civ": other_civ.get("name", "Unknown"),
		"stance": stance,
		"score": stance_score,
		"relations": relations
	})
	
	return stance

# Decide whether to declare war
func should_declare_war(target_civ: Dictionary, current_tension: float, military_advantage: float) -> bool:
	var aggression = personality.get("aggression", 0.5)
	var risk_tolerance = personality.get("risk_tolerance", 0.5)
	var defense_priority = personality.get("defense_priority", 0.5)
	
	var war_desire = aggression * risk_tolerance
	var tension_factor = min(current_tension / 100.0, 1.0)
	var military_factor = max(military_advantage - 0.3, 0.0)  # Need at least slight advantage
	
	var war_score = (war_desire * 0.5) + (tension_factor * 0.3) + (military_factor * 0.2)
	var war_threshold = 0.55  # Generally requires >55% war score
	
	record_decision("war_declaration", {
		"target": target_civ.get("name", "Unknown"),
		"war_score": war_score,
		"threshold": war_threshold,
		"decision": war_score > war_threshold
	})
	
	return war_score > war_threshold

# ==== STRATEGY EVALUATION ====

# Get primary victory condition for this civ
func get_victory_strategy() -> String:
	var strategy = civilization.get("strategy", {}).get("primary_victory", "domination")
	return strategy

# Evaluate which victory path we're closest to
func evaluate_victory_progress(game_state: Dictionary) -> Dictionary:
	var progress = {
		"domination": evaluate_domination_progress(game_state),
		"scientific": evaluate_scientific_progress(game_state),
		"cultural": evaluate_cultural_progress(game_state),
		"diplomatic": evaluate_diplomatic_progress(game_state),
		"economic": evaluate_economic_progress(game_state)
	}
	return progress

func evaluate_domination_progress(game_state: Dictionary) -> float:
	var our_military = game_state.get("our_military_strength", 0)
	var enemy_military = game_state.get("enemy_military_strength", 1)
	var our_cities = game_state.get("our_cities", 0)
	var total_cities = game_state.get("total_cities", 1)
	
	var military_advantage = our_military / max(enemy_military, 1)
	var city_control = float(our_cities) / total_cities
	
	return (military_advantage * 0.6 + city_control * 0.4) / 2.0

func evaluate_scientific_progress(game_state: Dictionary) -> float:
	var our_science = game_state.get("our_science_output", 0)
	var enemy_science = game_state.get("enemy_science_output", 1)
	var techs_researched = game_state.get("our_techs_researched", 0)
	var total_techs = game_state.get("total_techs", 1)
	
	var science_advantage = our_science / max(enemy_science, 1)
	var tech_progress = float(techs_researched) / total_techs
	
	return (science_advantage * 0.4 + tech_progress * 0.6) / 2.0

func evaluate_cultural_progress(game_state: Dictionary) -> float:
	var our_culture = game_state.get("our_culture_output", 0)
	var enemy_culture = game_state.get("enemy_culture_output", 1)
	var our_wonders = game_state.get("our_wonders", 0)
	
	var culture_advantage = our_culture / max(enemy_culture, 1)
	var wonder_count = min(our_wonders / 5.0, 1.0)
	
	return (culture_advantage * 0.6 + wonder_count * 0.4) / 2.0

func evaluate_diplomatic_progress(game_state: Dictionary) -> float:
	var allies = game_state.get("our_allies", 0)
	var total_civs = game_state.get("total_civs", 1)
	var diplomatic_favor = game_state.get("our_diplomatic_favor", 0)
	
	var alliance_score = float(allies) / max(total_civs - 1, 1)
	var favor_score = min(diplomatic_favor / 100.0, 1.0)
	
	return (alliance_score * 0.5 + favor_score * 0.5) / 2.0

func evaluate_economic_progress(game_state: Dictionary) -> float:
	var our_gold = game_state.get("our_gold", 0)
	var enemy_gold = game_state.get("enemy_gold", 1)
	var our_trade_routes = game_state.get("our_trade_routes", 0)
	
	var gold_advantage = our_gold / max(enemy_gold, 1)
	var trade_score = min(our_trade_routes / 10.0, 1.0)
	
	return (gold_advantage * 0.5 + trade_score * 0.5) / 2.0

# ==== PERSONALITY MODIFIERS ====

# Adjust AI behavior based on personality in real-time
func apply_personality_modifier(base_decision: float, decision_type: String) -> float:
	var weight = decision_weights.get(decision_type, {})
	var modifier = 0.0
	
	for trait_name in personality.keys():
		var trait_value = personality[trait_name]
		var trait_weight = weight.get(trait_name, 0.0)
		modifier += trait_value * trait_weight
	
	return base_decision + (modifier * 0.2)  # Cap personality influence at 20%

# Get personality description for debugging/display
func get_personality_string() -> String:
	var desc = "%s Personality:\n" % civilization.get("name", "Unknown")
	for trait_name in personality.keys():
		var value = personality[trait_name]
		var bar = "█" * int(value * 10) + "░" * (10 - int(value * 10))
		desc += "%s: [%s] %.1f\n" % [trait_name.capitalize(), bar, value]
	return desc

# ==== MEMORY & LEARNING ====

# Record a decision for learning/debugging
func record_decision(decision_type: String, details: Dictionary) -> void:
	if not memory.has("decisions"):
		memory["decisions"] = []
	
	memory["decisions"].append({
		"type": decision_type,
		"timestamp": Time.get_ticks_msec(),
		"details": details
	})
	
	# Keep memory size reasonable (last 100 decisions)
	if memory["decisions"].size() > 100:
		memory["decisions"].pop_front()

# Learn from outcomes - adjust memory based on success/failure
func record_outcome(decision_type: String, success: bool) -> void:
	if success:
		if "successful_actions" not in memory:
			memory["successful_actions"] = []
		memory["successful_actions"].append(decision_type)
	else:
		if "failed_strategies" not in memory:
			memory["failed_strategies"] = []
		memory["failed_strategies"].append(decision_type)

# Get decision history for analysis
func get_decision_history(filter_type: String = "") -> Array:
	if not memory.has("decisions"):
		return []
	
	if filter_type.is_empty():
		return memory["decisions"]
	
	return memory["decisions"].filter(func(d): return d["type"] == filter_type)

# ==== DEBUG OUTPUT ====

func print_ai_state() -> void:
	print("\n=== AI STATE ===")
	print(get_personality_string())
	print("\nRecent Decisions:")
	var recent = memory.get("decisions", [])
	for decision in recent.slice(-5):  # Last 5 decisions
		print("  - %s: %s" % [decision["type"], decision["details"]])
	print("================\n")
