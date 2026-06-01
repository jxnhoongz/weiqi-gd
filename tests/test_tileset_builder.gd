extends GutTest

func test_build_creates_atlas_with_12_tiles() -> void:
	var texture: Texture2D = load("res://assets/themes/kaya/go-board.png")
	assert_not_null(texture, "go-board.png should load")
	var ts := TilesetBuilder.build(texture)
	assert_eq(ts.tile_size, Vector2i(32, 32))
	var source := ts.get_source(TilesetBuilder.SOURCE_ID) as TileSetAtlasSource
	assert_not_null(source, "atlas source should exist at SOURCE_ID")
	assert_eq(source.get_tiles_count(), 12, "3 cols x 4 rows = 12 tiles")
