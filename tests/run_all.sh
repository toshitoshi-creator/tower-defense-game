#!/usr/bin/env bash
# Runs every automated phase-1 check. Usage: GODOT=/path/to/godot4 tests/run_all.sh
set -u
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
fail=0

echo "== 1. import"
out=$("$GODOT" --headless --path . --import 2>&1)
echo "$out" | grep -E "ERROR|WARNING" && fail=1

echo "== 2. GDScript warnings (all default warnings promoted to errors)"
{
	echo "[debug]"
	for w in unassigned_variable unassigned_variable_op_assign unused_variable unused_local_constant \
		unused_private_class_variable unused_parameter unused_signal shadowed_variable \
		shadowed_variable_base_class shadowed_global_identifier unreachable_code unreachable_pattern \
		standalone_expression standalone_ternary incompatible_ternary static_called_on_instance \
		redundant_static_unload redundant_await assert_always_true assert_always_false integer_division \
		narrowing_conversion int_as_enum_without_cast int_as_enum_without_match \
		enum_variable_without_default empty_file deprecated_keyword confusable_identifier \
		confusable_local_declaration confusable_local_usage confusable_capture_reassignment \
		inference_on_variant native_method_override get_node_default_without_onready onready_with_export; do
		echo "gdscript/warnings/$w=2"
	done
} > override.cfg
for f in $(find scripts tests tools -name "*.gd"); do
	out=$("$GODOT" --headless --path . --check-only -s "res://$f" 2>&1 | grep -v -E "^Godot Engine|^$")
	if [ -n "$out" ]; then echo "-- $f"; echo "$out"; fail=1; fi
done
rm -f override.cfg

echo "== 3. unit/integration tests"
"$GODOT" --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd 2>&1 | tee /tmp/td_tests.log | grep -v "^Godot Engine"
grep -q "RESULT: .* 0 failed" /tmp/td_tests.log || fail=1
grep -E "SCRIPT ERROR|^ERROR|^WARNING" /tmp/td_tests.log && fail=1

echo "== 4. smoke runs: title screen (main scene), then a battle left running for 3 min of game time"
out=$("$GODOT" --headless --path . --fixed-fps 60 --quit-after 600 2>&1)
echo "$out" | grep -E "SCRIPT ERROR|ERROR|WARNING" && fail=1
out=$("$GODOT" --headless --path . --fixed-fps 60 --quit-after 10800 res://scenes/battle/battle.tscn 2>&1)
echo "$out" | grep -E "SCRIPT ERROR|ERROR|WARNING" && fail=1

if [ $fail -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "CHECKS FAILED"; fi
exit $fail
