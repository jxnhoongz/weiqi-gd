extends GutTest

const BLACK := BoardState.Point.BLACK
const WHITE := BoardState.Point.WHITE

func test_returns_a_legal_move_on_empty_board() -> void:
	var s := BoardState.empty()
	var mv := MctsAI.choose_move(s, BLACK, 0, 0, null, 40)
	assert_ne(mv, MctsAI.NO_MOVE)
	assert_true(GoRules.place(s, mv.x, mv.y, BLACK)["ok"])

func test_no_move_when_board_is_full() -> void:
	var s := BoardState.empty()
	for y in BoardState.DEFAULT_SIZE:
		for x in BoardState.DEFAULT_SIZE:
			s = s.with_point(x, y, BLACK)
	assert_eq(MctsAI.choose_move(s, WHITE, 0, 0, null, 40), MctsAI.NO_MOVE)

func test_takes_the_immediate_winning_capture() -> void:
	# BOTH sides have 2 captures (each one away from winning). White (0,0) is in
	# atari (black at (1,0)); Black playing (0,1) captures it -> Black reaches 3
	# and wins immediately. That is the ONLY guaranteed win; any other Black move
	# hands White a chance to win first. MCTS must pick (0,1).
	var s := BoardState.empty()
	s = s.with_point(0, 0, WHITE)
	s = s.with_point(1, 0, BLACK)
	var mv := MctsAI.choose_move(s, BLACK, 2, 2, null, 600)
	assert_eq(mv, Vector2i(0, 1), "MCTS should grab the move that wins the game now")
