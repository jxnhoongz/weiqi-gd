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
