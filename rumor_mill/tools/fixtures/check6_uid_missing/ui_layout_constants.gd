# Fixture: SPA-1677 reproduction — class_name without .uid file.
# This script declares a class_name but has NO corresponding .gd.uid file.
# Check 6 should flag this as an error.
class_name UILayoutConstants

const MARGIN_LEFT := 16
const MARGIN_TOP := 8
