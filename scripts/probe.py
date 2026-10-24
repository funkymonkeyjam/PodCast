"""Finite native synthetic-tone qualification; never captures local audio."""
import argparse
import asyncio
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src" / "AirFlash"))
from scripts.native_probe import run_probe


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", required=True)
    parser.add_argument("--engine", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--timing", choices=("ptp", "ntp"), default="ptp")
    parser.add_argument("--signal-peak", type=float, default=.05)
    args = parser.parse_args()
    raise SystemExit(asyncio.run(run_probe(
        [args.host], 5, .1, timing=args.timing, report_path=args.report,
        signal_peak=args.signal_peak, executable=args.engine,
    )))
