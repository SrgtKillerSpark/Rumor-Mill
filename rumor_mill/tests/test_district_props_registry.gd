## test_district_props_registry.gd — Unit tests for DistrictPropsRegistry static
## data and accessor methods (SPA-1065).
##
## Covers:
##   • PROPS total count (14 entries across 5 districts)
##   • All entries have required keys: district, id, label, sprite, offset, z_index
##   • No duplicate prop ids
##   • props_for_district() — Noble Quarter has 3, Civic Heart has 2
##   • district_labels()    — returns 5 unique district labels
##
## Strategy: DistrictPropsRegistry is a pure-static class_name with no Node
## dependency. All tests call the preloaded script directly.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestDistrictPropsRegistry
extends RefCounted

const DPRScript := preload("res://scripts/district_props_registry.gd")


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── PROPS array ──
		"test_props_total_count",
		"test_all_props_have_required_keys",
		"test_no_duplicate_prop_ids",
		"test_all_z_indices_are_1",

		# ── props_for_district() ──
		"test_noble_quarter_has_three_props",
		"test_church_district_has_three_props",
		"test_civic_heart_has_two_props",
		"test_eastern_quarter_has_three_props",

		# ── district_labels() ──
		"test_district_labels_count",
		"test_district_labels_contains_expected_names",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			print("  FAIL  %s" % method_name)
			failed += 1

	print("\n  %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# PROPS array
# ══════════════════════════════════════════════════════════════════════════════

func test_props_total_count() -> bool:
	# 3 Noble + 3 Church + 3 Market + 2 Civic + 3 Eastern = 14
	return DPRScript.PROPS.size() == 14


func test_all_props_have_required_keys() -> bool:
	var required := ["district", "id", "label", "sprite", "offset", "z_index"]
	for prop: Dictionary in DPRScript.PROPS:
		for key in required:
			if not prop.has(key):
				return false
	return true


func test_no_duplicate_prop_ids() -> bool:
	var seen: Dictionary = {}
	for prop: Dictionary in DPRScript.PROPS:
		var pid: String = prop["id"]
		if pid in seen:
			return false
		seen[pid] = true
	return true


func test_all_z_indices_are_1() -> bool:
	for prop: Dictionary in DPRScript.PROPS:
		if prop["z_index"] != 1:
			return false
	return true


# ══════════════════════════════════════════════════════════════════════════════
# props_for_district()
# ══════════════════════════════════════════════════════════════════════════════

func test_noble_quarter_has_three_props() -> bool:
	return DPRScript.props_for_district("Noble Quarter").size() == 3


func test_church_district_has_three_props() -> bool:
	return DPRScript.props_for_district("Church District").size() == 3


func test_civic_heart_has_two_props() -> bool:
	return DPRScript.props_for_district("Civic Heart").size() == 2


func test_eastern_quarter_has_three_props() -> bool:
	return DPRScript.props_for_district("Eastern Quarter").size() == 3


# ══════════════════════════════════════════════════════════════════════════════
# district_labels()
# ══════════════════════════════════════════════════════════════════════════════

func test_district_labels_count() -> bool:
	return DPRScript.district_labels().size() == 5


func test_district_labels_contains_expected_names() -> bool:
	var labels := DPRScript.district_labels()
	return "Noble Quarter" in labels \
		and "Church District" in labels \
		and "Market Square" in labels \
		and "Civic Heart" in labels \
		and "Eastern Quarter" in labels
