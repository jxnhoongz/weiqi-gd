extends GutTest

const BLACK := BoardState.Point.BLACK
const WHITE := BoardState.Point.WHITE

func test_no_move_on_full_board() -> void:
	var s := BoardState.empty()
	for y in BoardState.DEFAULT_SIZE:
		for x in BoardState.DEFAULT_SIZE:
			s = s.with_point(x, y, BLACK)
	assert_eq(HeuristicAI.choose_move(s, WHITE), HeuristicAI.NO_MOVE)

func test_returns_a_legal_move() -> void:
	var s := BoardState.empty()
	var mv := HeuristicAI.choose_move(s, BLACK)
	assert_ne(mv, HeuristicAI.NO_MOVE)
	assert_true(GoRules.place(s, mv.x, mv.y, BLACK)["ok"])

func test_takes_a_capture() -> void:
	# White (0,0) in atari (black at (1,0)); (0,1) captures it.
	var s := BoardState.empty()
	s = s.with_point(0, 0, WHITE)
	s = s.with_point(1, 0, BLACK)
	var mv := HeuristicAI.choose_move(s, BLACK)
	assert_eq(mv, Vector2i(0, 1))
	assert_eq(GoRules.place(s, mv.x, mv.y, BLACK)["captured"].size(), 1)

func test_avoids_self_atari() -> void:
	# White at (1,0). Black at (0,0) would have a single liberty (self-atari, no
	# capture). Many safe moves exist; the bot must not choose self-atari.
	var s := BoardState.empty().with_point(1, 0, WHITE)
	var mv := HeuristicAI.choose_move(s, BLACK)
	assert_ne(mv, Vector2i(0, 0), "should not play into self-atari")
	var rs: BoardState = GoRules.place(s, mv.x, mv.y, BLACK)["state"]
	var libs := GroupAnalysis.count_liberties(rs, GroupAnalysis.group_at(rs, mv.x, mv.y))
	assert_gt(libs, 1, "chosen move should leave own group with more than one liberty")

func test_saves_own_group_in_atari() -> void:
	# Black (4,4) is in atari (white at (3,4),(5,4),(4,3)); its only liberty is
	# (4,5). No white group is capturable, so the bot must extend to (4,5) to live.
	var s := BoardState.empty()
	s = s.with_point(4, 4, BLACK)
	s = s.with_point(3, 4, WHITE)
	s = s.with_point(5, 4, WHITE)
	s = s.with_point(4, 3, WHITE)
	var mv := HeuristicAI.choose_move(s, BLACK)
	assert_eq(mv, Vector2i(4, 5), "should extend to rescue the group in atari")
