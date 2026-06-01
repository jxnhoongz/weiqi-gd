extends GutTest

func test_empty_board_is_all_empty() -> void:
	var b := BoardState.empty()
	for y in BoardState.SIZE:
		for x in BoardState.SIZE:
			assert_eq(b.get_point(x, y), BoardState.Point.EMPTY)

func test_with_point_sets_color() -> void:
	var b := BoardState.empty().with_point(2, 3, BoardState.Point.BLACK)
	assert_eq(b.get_point(2, 3), BoardState.Point.BLACK)

func test_with_point_does_not_mutate_original() -> void:
	var original := BoardState.empty()
	var _updated := original.with_point(2, 3, BoardState.Point.BLACK)
	assert_eq(original.get_point(2, 3), BoardState.Point.EMPTY,
		"with_point must return a new state and leave the original unchanged")

func test_is_empty() -> void:
	var b := BoardState.empty().with_point(0, 0, BoardState.Point.WHITE)
	assert_false(b.is_empty(0, 0))
	assert_true(b.is_empty(1, 1))

func test_in_bounds() -> void:
	var b := BoardState.empty()
	assert_true(b.in_bounds(0, 0))
	assert_true(b.in_bounds(8, 8))
	assert_false(b.in_bounds(9, 0))
	assert_false(b.in_bounds(-1, 0))
	assert_false(b.in_bounds(0, 9))
