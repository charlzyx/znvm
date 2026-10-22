#!/bin/bash
# Retired. This script took one `time` sample, included `source nvm.sh` only
# in the nvm timings, and called `znvm resolve`, which is not a znvm command.
# Those figures were not a fair comparison and are not published anymore.
#
# Run the measured comparison instead:
#   python3 benchmarks/measure.py --help
# The 2026-10-22 run is benchmarks/results/2026-10-22.json.
echo "benchmark_key_operations.sh is retired. Use: python3 benchmarks/measure.py --help" >&2
echo "Published run: benchmarks/results/2026-10-22.json" >&2
exit 1
