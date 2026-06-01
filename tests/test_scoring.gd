extends GutTest

const BLACK := BoardState.Point.BLACK
const WHITE := BoardState.Point.WHITE

func test_empty_board_is_all_neutral() -> void:
	var s := BoardState.empty(9)
	var a := Scoring.area(s)
	assert_eq(a["black"], 0)
	assert_eq(a["white"], 0)
	assert_eq(a["neutral"], 81)

func test_single_stone_controls_the_whole_board() -> void:
	# One black stone: the entire empty region is bordered only by black, so it
	# is all black's area (illustrates the naive "surrounded by one colour" rule).
	var s := BoardState.empty(9).with_point(4, 4, BLACK)
	var a := Scoring.area(s)
	assert_eq(a["black"], 81, "1 stone + 80 surrounded empties")
	assert_eq(a["white"], 0)
	assert_eq(a["neutral"], 0)

func test_wall_splits_board_into_one_colour_territory() -> void:
	# 3x3: a black column down the middle. Both side columns are bordered only
	# by black -> all 9 points are black's area.
	var s := BoardState.empty(3)
	s = s.with_point(1, 0, BLACK)
	s = s.with_point(1, 1, BLACK)
	s = s.with_point(1, 2, BLACK)
	var a := Scoring.area(s)
	assert_eq(a["black"], 9)
	assert_eq(a["white"], 0)
	assert_eq(a["neutral"], 0)

func test_region_touching_both_colours_is_neutral() -> void:
	# 3x3: black left column, white right column, middle column empty and bordered
	# by BOTH colours -> neutral (dame).
	var s := BoardState.empty(3)
	for y in 3:
		s = s.with_point(0, y, BLACK)
		s = s.with_point(2, y, WHITE)
	var a := Scoring.area(s)
	assert_eq(a["black"], 3, "3 black stones, no exclusive territory")
	assert_eq(a["white"], 3)
	assert_eq(a["neutral"], 3, "the middle column borders both colours")

func test_winner_reports_higher_area_or_tie() -> void:
	assert_eq(Scoring.winner(BoardState.empty(9).with_point(4, 4, BLACK)), BLACK)
	var tie := BoardState.empty(3)
	for y in 3:
		tie = tie.with_point(0, y, BLACK)
		tie = tie.with_point(2, y, WHITE)
	assert_eq(Scoring.winner(tie), BoardState.Point.EMPTY, "equal area -> tie (EMPTY)")
