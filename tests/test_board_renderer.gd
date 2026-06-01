extends GutTest

# The stone "slices" must point at the correct 32x32 cells of go-board.png:
# row 3 is [star, white, black] -> white at x=32, black at x=64, y=96.

func test_black_stone_region() -> void:
	assert_eq(BoardRenderer.stone_region(BoardState.Point.BLACK), Rect2(64, 96, 32, 32))

func test_white_stone_region() -> void:
	assert_eq(BoardRenderer.stone_region(BoardState.Point.WHITE), Rect2(32, 96, 32, 32))
