extends RefCounted

# All regions point into the user's unmodified reference. The sample names and
# scores are deliberately outside the regions used for live data.
const SOURCE := preload("res://assets/release-september/results-reference.png")
const REGIONS := {
	"game_over": Rect2(45, 94, 853, 153),
	"your_name": Rect2(72, 404, 177, 33),
	"edit": Rect2(646, 446, 232, 97),
	"save": Rect2(63, 558, 816, 138),
	"rating": Rect2(48, 781, 588, 123),
	"refresh": Rect2(650, 791, 232, 102),
	"again": Rect2(65, 1396, 410, 143),
	"menu": Rect2(491, 1396, 388, 143),
	"points": Rect2(456, 272, 303, 99),
	"score_left": Rect2(96, 270, 70, 110),
	"score_right": Rect2(785, 270, 65, 110),
	"columns": Rect2(101, 936, 727, 40),
}

static func texture(key: String) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = SOURCE
	atlas.region = REGIONS[key]
	atlas.filter_clip = true
	return atlas

static func region(rect: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = SOURCE
	atlas.region = rect
	atlas.filter_clip = true
	return atlas
