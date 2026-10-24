"""Black-box IPC and source-policy checks. Uses loopback addresses, never a receiver.

Usage: python tests/engine_safety.py path/to/airflash-engine.exe
This does not establish WASAPI capture or HomePod playback.
"""

import json
import pathlib
import subprocess
import sys
import unittest


ENGINE = pathlib.Path(sys.argv.pop(1)).resolve() if len(sys.argv) > 1 else None


def request(command, params=None, version=1):
    return json.dumps({"version": version, "id": "policy-test", "session_id": "no-hardware", "command": command, "params": params})


def start_options(endpoint):
    return {"peers": [{"host": "127.0.0.1", "port": 9}], "source": "loopback", "capture_endpoint": endpoint,
            "duration_ms": 0, "latency_ms": 200, "gain": 0.01}


@unittest.skipUnless(ENGINE is not None, "provide a source-built engine path")
class EngineSafety(unittest.TestCase):
    def run_engine(self, lines):
        result = subprocess.run([str(ENGINE)], input="\n".join(lines) + "\n", text=True,
                                capture_output=True, timeout=10, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        return [json.loads(line) for line in result.stdout.splitlines() if line.strip()]

    def test_missing_source_is_rejected_before_connect(self):
        for endpoint in (None, "", "   "):
            with self.subTest(endpoint=endpoint):
                events = self.run_engine([request("start", start_options(endpoint))])
                self.assertEqual(len(events), 1, events)
                self.assertEqual(events[0]["event"], "error", events)
                self.assertIn("endpoint", events[0].get("message", "").lower(), events)
                self.assertNotIn("connect 127.0.0.1", events[0].get("message", ""), events)

    def test_multiple_receivers_are_rejected_before_connect(self):
        options = start_options("synthetic-missing-endpoint")
        options["peers"].append({"host": "127.0.0.2", "port": 9})
        events = self.run_engine([request("start", options)])
        self.assertEqual(len(events), 1, events)
        self.assertEqual(events[0]["event"], "error", events)
        self.assertRegex(events[0].get("message", "").lower(), r"one|single")
        self.assertNotIn("connect 127.0.0.1", events[0].get("message", ""), events)

    def test_oversized_command_does_not_poison_next_request(self):
        events = self.run_engine(["x" * 65537, request("hello")])
        self.assertEqual([event["event"] for event in events], ["error", "hello"])
        self.assertIn("64KiB", events[0].get("message", ""))
        self.assertEqual(events[1]["session_id"], "no-hardware")

    def test_malformed_command_does_not_poison_next_request(self):
        events = self.run_engine(["{", request("hello")])
        self.assertEqual([event["event"] for event in events], ["error", "hello"])

    def test_unsupported_version_is_rejected(self):
        events = self.run_engine([request("hello", version=2)])
        self.assertEqual(len(events), 1, events)
        self.assertEqual(events[0]["event"], "error")
        self.assertIn("version", events[0].get("message", ""))


if __name__ == "__main__":
    if ENGINE is None or not ENGINE.is_file():
        sys.exit("Pass the path to the source-built engine executable; no checks ran.")
    unittest.main()
