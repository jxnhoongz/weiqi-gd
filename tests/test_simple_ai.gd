extends GutTest

const BLACK := BoardState.Point.BLACK
const WHITE := BoardState.Point.WHITE

func test_no_move_when_board_is_full() -> void:
	var s := BoardState.empty()
	for y in BoardState.DEFAULT_SIZE:
		for x in BoardState.DEFAULT_SIZE:
			s = s.with_point(x, y, BLACK)
	assert_eq(SimpleAI.choose_move(s, WHITE), SimpleAI.NO_MOVE)

func test_chosen_move_is_always_legal() -> void:
	var s := BoardState.empty()
	var mv := SimpleAI.choose_move(s, BLACK)
	assert_ne(mv, SimpleAI.NO_MOVE)
	assert_true(GoRules.place(s, mv.x, mv.y, BLACK)["ok"])

func test_takes_an_available_capture() -> void:
	# White stone at (0,0) in atari (black at (1,0)); the capturing move is (0,1).
	var s := BoardState.empty()
	s = s.with_point(0, 0, WHITE)
	s = s.with_point(1, 0, BLACK)
	var mv := SimpleAI.choose_move(s, BLACK)
	assert_eq(mv, Vector2i(0, 1), "only capturing move")
	assert_eq(GoRules.place(s, mv.x, mv.y, BLACK)["captured"].size(), 1)

func test_prefers_the_larger_capture() -> void:
	# Option A: capture 1 white at (0,0) by playing (0,1).
	# Option B: capture a 2-stone white group at (4,4),(5,4) by playing (6,4).
	var s := BoardState.empty()
	s = s.with_point(0, 0, WHITE)
	s = s.with_point(1, 0, BLACK)
	s = s.with_point(4, 4, WHITE)
	s = s.with_point(5, 4, WHITE)
	s = s.with_point(3, 4, BLACK)
	s = s.with_point(4, 3, BLACK)
	s = s.with_point(4, 5, BLACK)
	s = s.with_point(5, 3, BLACK)
	s = s.with_point(5, 5, BLACK)
	var mv := SimpleAI.choose_move(s, BLACK)
	assert_eq(mv, Vector2i(6, 4), "should choose the move capturing 2, not 1")
	assert_eq(GoRules.place(s, mv.x, mv.y, BLACK)["captured"].size(), 2)
