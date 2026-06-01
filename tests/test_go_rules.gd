extends GutTest

const BLACK := BoardState.Point.BLACK
const WHITE := BoardState.Point.WHITE
const EMPTY := BoardState.Point.EMPTY

func _b() -> BoardState:
	return BoardState.empty()

func test_place_with_no_capture_sets_stone_and_empty_captures() -> void:
	var result := GoRules.place(_b(), 4, 4, BLACK)
	var state: BoardState = result["state"]
	assert_eq(state.get_point(4, 4), BLACK)
	assert_eq(result["captured"], [])

func test_place_does_not_mutate_input_state() -> void:
	var start := _b()
	var _r := GoRules.place(start, 4, 4, BLACK)
	assert_eq(start.get_point(4, 4), EMPTY, "input state must be unchanged")

func test_captures_single_stone_in_corner() -> void:
	# White at (0,0). Black already at (1,0). Black plays (0,1) -> white has 0 liberties.
	var s := _b()
	s = s.with_point(0, 0, WHITE)
	s = s.with_point(1, 0, BLACK)
	var result := GoRules.place(s, 0, 1, BLACK)
	var state: BoardState = result["state"]
	assert_eq(state.get_point(0, 0), EMPTY, "captured white stone is removed")
	assert_eq(state.get_point(0, 1), BLACK, "the placed black stone stays")
	assert_true(result["captured"].has(Vector2i(0, 0)))
	assert_eq(result["captured"].size(), 1)

func test_no_capture_when_group_still_has_a_liberty() -> void:
	# White at (0,0) with liberties (1,0) and (0,1). Black plays only (1,0).
	var s := _b().with_point(0, 0, WHITE)
	var result := GoRules.place(s, 1, 0, BLACK)
	var state: BoardState = result["state"]
	assert_eq(state.get_point(0, 0), WHITE, "white still has liberty (0,1), not captured")
	assert_eq(result["captured"], [])

func test_captures_a_multi_stone_group() -> void:
	# White group (0,0)+(1,0). Black at (2,0),(0,1) already; play last liberty (1,1).
	var s := _b()
	s = s.with_point(0, 0, WHITE)
	s = s.with_point(1, 0, WHITE)
	s = s.with_point(2, 0, BLACK)
	s = s.with_point(0, 1, BLACK)
	var result := GoRules.place(s, 1, 1, BLACK)
	var state: BoardState = result["state"]
	assert_eq(state.get_point(0, 0), EMPTY)
	assert_eq(state.get_point(1, 0), EMPTY)
	assert_eq(result["captured"].size(), 2)
	assert_true(result["captured"].has(Vector2i(0, 0)))
	assert_true(result["captured"].has(Vector2i(1, 0)))

func test_captures_two_separate_groups_with_one_move() -> void:
	# Two separate single white stones, each on their last liberty, both adjacent
	# to the move at (1,1): white at (1,0) and (0,1).
	var s := _b()
	s = s.with_point(1, 0, WHITE)
	s = s.with_point(0, 1, WHITE)
	s = s.with_point(0, 0, BLACK)
	s = s.with_point(2, 0, BLACK)
	s = s.with_point(0, 2, BLACK)
	var result := GoRules.place(s, 1, 1, BLACK)
	var state: BoardState = result["state"]
	assert_eq(state.get_point(1, 0), EMPTY)
	assert_eq(state.get_point(0, 1), EMPTY)
	assert_eq(result["captured"].size(), 2)

func test_suicide_is_illegal() -> void:
	var s := _b()
	s = s.with_point(0, 1, WHITE)
	s = s.with_point(2, 1, WHITE)
	s = s.with_point(1, 0, WHITE)
	s = s.with_point(1, 2, WHITE)
	var result := GoRules.place(s, 1, 1, BLACK)
	assert_false(result["ok"], "filling your own last liberty with no capture is suicide")
	assert_eq(result["reason"], "suicide")
	var state: BoardState = result["state"]
	assert_eq(state.get_point(1, 1), EMPTY)

func test_capturing_move_that_would_be_suicide_is_legal() -> void:
	# Black (0,0) is otherwise surrounded, but it captures White (1,0) first, gaining a liberty.
	var s := _b()
	s = s.with_point(1, 0, WHITE)
	s = s.with_point(0, 1, WHITE)
	s = s.with_point(2, 0, BLACK)
	s = s.with_point(1, 1, BLACK)
	var result := GoRules.place(s, 0, 0, BLACK)
	assert_true(result["ok"], "capturing frees a liberty, so not suicide")
	assert_true(result["captured"].has(Vector2i(1, 0)))

func test_ko_recapture_is_illegal_and_legal_without_ko_guard() -> void:
	# Canonical ko around point (2,1):
	#   col: 0 1 2 3
	# row0:  . B W .
	# row1:  B W . W
	# row2:  . B W .
	var a := _b()
	a = a.with_point(1, 0, BLACK)
	a = a.with_point(0, 1, BLACK)
	a = a.with_point(1, 2, BLACK)
	a = a.with_point(1, 1, WHITE)
	a = a.with_point(2, 0, WHITE)
	a = a.with_point(3, 1, WHITE)
	a = a.with_point(2, 2, WHITE)
	var black_move := GoRules.place(a, 2, 1, BLACK)
	assert_true(black_move["ok"])
	assert_true(black_move["captured"].has(Vector2i(1, 1)))
	var b: BoardState = black_move["state"]
	var no_guard := GoRules.place(b, 1, 1, WHITE)
	assert_true(no_guard["ok"])
	var with_guard := GoRules.place(b, 1, 1, WHITE, a)
	assert_false(with_guard["ok"], "immediate recapture recreates the prior position")
	assert_eq(with_guard["reason"], "ko")

func test_legal_move_reports_ok_true() -> void:
	var result := GoRules.place(_b(), 4, 4, BLACK)
	assert_true(result["ok"])
	assert_eq(result["reason"], "")

func test_captures_single_corner_stone_on_19x19() -> void:
	# White in the bottom-right corner (18,18) with black on one liberty (17,18);
	# black plays the other liberty (18,17) -> white has 0 liberties -> captured.
	var s := BoardState.empty(19)
	s = s.with_point(18, 18, WHITE)
	s = s.with_point(17, 18, BLACK)
	var result := GoRules.place(s, 18, 17, BLACK)
	assert_eq(result["captured"].size(), 1, "corner stone with both liberties filled must be captured")
	assert_eq(result["state"].get_point(18, 18), EMPTY)

func test_captures_two_stone_corner_group_on_19x19() -> void:
	# White corner group (18,18)+(18,17); its 3 liberties are (17,18),(17,17),(18,16).
	# Black fills two, then plays (18,16) -> both white stones captured.
	var s := BoardState.empty(19)
	s = s.with_point(18, 18, WHITE)
	s = s.with_point(18, 17, WHITE)
	s = s.with_point(17, 18, BLACK)
	s = s.with_point(17, 17, BLACK)
	var result := GoRules.place(s, 18, 16, BLACK)
	assert_eq(result["captured"].size(), 2, "both corner stones should die")
	assert_eq(result["state"].get_point(18, 18), EMPTY)
	assert_eq(result["state"].get_point(18, 17), EMPTY)

func test_captures_a_bottom_edge_group_on_19x19() -> void:
	# A 3-stone white group along the bottom edge of a 19x19 board, surrounded by
	# black on every liberty except (8,18); Black plays (8,18) -> all 3 captured.
	var s := BoardState.empty(19)
	s = s.with_point(5, 18, WHITE)
	s = s.with_point(6, 18, WHITE)
	s = s.with_point(7, 18, WHITE)
	s = s.with_point(4, 18, BLACK)
	s = s.with_point(5, 17, BLACK)
	s = s.with_point(6, 17, BLACK)
	s = s.with_point(7, 17, BLACK)
	var result := GoRules.place(s, 8, 18, BLACK)
	assert_eq(result["captured"].size(), 3, "the whole bottom-edge group should die at once")

func test_adjacent_white_with_its_own_liberty_survives() -> void:
	# A (5,18)-(6,18) white group, plus a SEPARATE white at (8,18). Capturing the
	# 2-stone group must NOT remove the separate stone (it still has liberties).
	var s := BoardState.empty(19)
	s = s.with_point(5, 18, WHITE)
	s = s.with_point(6, 18, WHITE)
	s = s.with_point(8, 18, WHITE)
	s = s.with_point(4, 18, BLACK)
	s = s.with_point(5, 17, BLACK)
	s = s.with_point(6, 17, BLACK)
	var result := GoRules.place(s, 7, 18, BLACK)
	assert_eq(result["captured"].size(), 2, "only the surrounded group dies")
	assert_eq(result["state"].get_point(8, 18), WHITE, "separate stone with a liberty survives")
