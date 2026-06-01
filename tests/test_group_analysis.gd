extends GutTest

func _b() -> BoardState:
	return BoardState.empty()

func test_group_at_empty_point_is_empty_array() -> void:
	assert_eq(GroupAnalysis.group_at(_b(), 4, 4), [])

func test_group_at_single_stone() -> void:
	var s := _b().with_point(4, 4, BoardState.Point.BLACK)
	assert_eq(GroupAnalysis.group_at(s, 4, 4), [Vector2i(4, 4)])

func test_group_at_connected_line_of_three() -> void:
	var s := _b()
	s = s.with_point(0, 0, BoardState.Point.BLACK)
	s = s.with_point(1, 0, BoardState.Point.BLACK)
	s = s.with_point(2, 0, BoardState.Point.BLACK)
	var group := GroupAnalysis.group_at(s, 0, 0)
	assert_eq(group.size(), 3)
	assert_true(group.has(Vector2i(0, 0)))
	assert_true(group.has(Vector2i(1, 0)))
	assert_true(group.has(Vector2i(2, 0)))

func test_group_at_ignores_diagonal_and_other_color() -> void:
	var s := _b()
	s = s.with_point(0, 0, BoardState.Point.BLACK)
	s = s.with_point(1, 1, BoardState.Point.BLACK) # diagonal — NOT connected
	s = s.with_point(1, 0, BoardState.Point.WHITE) # adjacent but other color
	assert_eq(GroupAnalysis.group_at(s, 0, 0), [Vector2i(0, 0)])

func test_liberties_single_stone_center_is_four() -> void:
	var s := _b().with_point(4, 4, BoardState.Point.BLACK)
	assert_eq(GroupAnalysis.count_liberties(s, GroupAnalysis.group_at(s, 4, 4)), 4)

func test_liberties_single_stone_corner_is_two() -> void:
	var s := _b().with_point(0, 0, BoardState.Point.BLACK)
	assert_eq(GroupAnalysis.count_liberties(s, GroupAnalysis.group_at(s, 0, 0)), 2)

func test_liberties_reduced_by_adjacent_enemy() -> void:
	var s := _b()
	s = s.with_point(0, 0, BoardState.Point.BLACK)
	s = s.with_point(1, 0, BoardState.Point.WHITE) # takes one of black's two corner liberties
	assert_eq(GroupAnalysis.count_liberties(s, GroupAnalysis.group_at(s, 0, 0)), 1)

func test_liberties_are_deduped_across_group() -> void:
	var s := _b()
	s = s.with_point(0, 0, BoardState.Point.BLACK)
	s = s.with_point(0, 1, BoardState.Point.BLACK)
	# Liberties: (1,0), (1,1), (0,2) = 3 distinct empty neighbors.
	assert_eq(GroupAnalysis.count_liberties(s, GroupAnalysis.group_at(s, 0, 0)), 3)
