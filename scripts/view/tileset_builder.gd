## Builds a TileSet from the go-board.png atlas (3 cols x 4 rows of 32x32 tiles)
## at runtime, so we never hand-author a fragile .tres resource.
class_name TilesetBuilder
extends RefCounted

const TILE_SIZE := Vector2i(32, 32)
const ATLAS_COLS := 3
const ATLAS_ROWS := 4
const SOURCE_ID := 0

static func build(texture: Texture2D) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = TILE_SIZE
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = TILE_SIZE
	for row in ATLAS_ROWS:
		for col in ATLAS_COLS:
			source.create_tile(Vector2i(col, row))
	ts.add_source(source, SOURCE_ID)
	return ts
