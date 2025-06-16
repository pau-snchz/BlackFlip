extends Node

class_name AIPlayer

# Probability threshold for risky moves
const RISK_THRESHOLD = 0.7
# Score threshold to play conservatively
const CONSERVATIVE_THRESHOLD = 15  # Fixed typo in constant name

# Main decision function
func make_decision(ai_state: Dictionary, human_state: Dictionary, deck: Array) -> String:
	var depth = min(3, 5 - ai_state["flipped_count"])  # Limit depth to remaining cards
	var result = minimax(ai_state, human_state, deck, depth, true)
	var _score = result[0]  # Prefix with underscore to indicate intentional non-use
	var action = result[1]

	if action == "flip" and should_play_conservative(ai_state, human_state):
		return "stay"
	
	return action

# Minimax Algorithm
func minimax(ai_state: Dictionary, human_state: Dictionary, deck: Array, depth: int, maximizing_player: bool) -> Array:
	if depth == 0 or game_over(ai_state, human_state):
		return [evaluate_state(ai_state, human_state), ai_state["action"]]
	
	if maximizing_player:  # AI's turn
		var max_eval = -INF
		var best_action = "stay"
		
		# Evaluate flip action
		var flip_state = simulate_flip(ai_state.duplicate(true), human_state, deck)
		var flip_result = minimax(flip_state["ai"], flip_state["human"], flip_state["deck"], depth - 1, false)
		var flip_eval = flip_result[0]
		
		if flip_eval > max_eval:
			max_eval = flip_eval
			best_action = "flip"
		
		# Evaluate stay action
		var stay_state = {
			"ai": ai_state.duplicate(true),
			"human": human_state.duplicate(true),
			"deck": deck.duplicate()
		}
		stay_state["ai"]["action"] = "stay"
		var stay_result = minimax(stay_state["ai"], stay_state["human"], stay_state["deck"], depth - 1, false)
		var stay_eval = stay_result[0]
		
		if stay_eval > max_eval:
			max_eval = stay_eval
			best_action = "stay"
		
		return [max_eval, best_action]
	else:  # Human's turn (minimizing player)
		var min_eval = INF
		var best_action = "stay"
		
		# Evaluate flip action
		var flip_state = simulate_flip(human_state.duplicate(true), ai_state, deck)
		var flip_result = minimax(flip_state["human"], flip_state["ai"], flip_state["deck"], depth - 1, true)
		var flip_eval = flip_result[0]
		
		if flip_eval < min_eval:
			min_eval = flip_eval
			best_action = "flip"
		
		# Evaluate stay action
		var stay_state = {
			"ai": ai_state.duplicate(true),
			"human": human_state.duplicate(true),
			"deck": deck.duplicate()
		}
		stay_state["human"]["action"] = "stay"
		var stay_result = minimax(stay_state["human"], stay_state["ai"], stay_state["deck"], depth - 1, true)
		var stay_eval = stay_result[0]
		
		if stay_eval < min_eval:
			min_eval = stay_eval
			best_action = "stay"
		
		return [min_eval, best_action]

# Check if game is over for current state
func game_over(ai_state: Dictionary, human_state: Dictionary) -> bool:
	return ai_state["busted"] or human_state["busted"] or \
		(ai_state["action"] == "stay" and human_state["action"] == "stay")

# Evaluate the utility of a game state
func evaluate_state(ai_state: Dictionary, human_state: Dictionary) -> float:
	var ai_score = calculate_potential_score(ai_state)
	var human_score = calculate_potential_score(human_state)

	# Consider the probability of busting
	var bust_probability = calculate_bust_probability(ai_state)
	var score_diff = ai_score - human_score

	# Weight the score difference by bust probability
	return score_diff * (1.0 - bust_probability)

# Calculate potential score including bonuses
func calculate_potential_score(state: Dictionary) -> int:
	var score = state["current_score"]

	if state["flipped_count"] == 5 and not state["busted"]:
		score += 15  # 5 unique cards bonus

	if score == 21:
		score += 10  # Perfect 21 bonus

	return score

# Calculate probability of busting on next flip
func calculate_bust_probability(state: Dictionary) -> float:
	if state["busted"] or state["flipped_count"] >= 5:
		return 1.0

	# Check if deck exists in state, otherwise use empty array
	var deck = state.get("deck", [])
	var total_cards = state.get("deck_size", 0)
	var duplicate_cards = 0

	if total_cards == 0:
		return 1.0  # No cards left means 100% bust probability

	for value in state["flipped_values"]:
		# Count how many cards in deck would cause a bust
		duplicate_cards += count_cards_with_value(value, deck)

	return float(duplicate_cards) / float(total_cards)

# Helper function to count cards with specific value
func count_cards_with_value(value: int, deck: Array) -> int:
	var count = 0
	for card in deck:
		if card["value"] == value:
			count += 1
	return count

# Simulate a flip action
func simulate_flip(player_state: Dictionary, opponent_state: Dictionary, deck: Array) -> Dictionary:
	if deck.is_empty() or player_state["flipped_count"] >= 5:
		return {"ai": player_state, "human": opponent_state, "deck": deck}

	# Draw a card
	var drawn_card = deck.pop_back()
	var new_state = player_state.duplicate(true)

	# Check for bust
	if drawn_card["value"] in new_state["flipped_values"]:
		new_state["busted"] = true
		new_state["current_score"] = 0
	else:
		new_state["flipped_values"].append(drawn_card["value"])
		new_state["current_score"] += drawn_card["value"]
		new_state["flipped_count"] += 1

	new_state["action"] = "flip"
	return {"ai": new_state, "human": opponent_state, "deck": deck}

# Conservative play when AI is significantly ahead
func should_play_conservative(ai_state: Dictionary, human_state: Dictionary) -> bool:
	var ai_potential = calculate_potential_score(ai_state)
	var human_potential = calculate_potential_score(human_state)
	return (ai_potential - human_potential) > CONSERVATIVE_THRESHOLD
