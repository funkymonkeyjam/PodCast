import importlib.util
import hashlib
import json
from pathlib import Path
import tempfile
import unittest


spec = importlib.util.spec_from_file_location(
    "native_notices", Path(__file__).resolve().parents[1] / "scripts" / "collect-native-notices.py"
)
notices = importlib.util.module_from_spec(spec)
spec.loader.exec_module(notices)


class NativeNoticesTests(unittest.TestCase):
    def setUp(self):
        artifacts = Path(__file__).resolve().parents[1] / "artifacts"
        artifacts.mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix="native-notices-test-", dir=artifacts, ignore_cleanup_errors=True)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.sysroot = self.root / "toolchain"
        docs = self.sysroot / "share" / "doc" / "rust"
        docs.mkdir(parents=True)
        (docs / "COPYRIGHT.html").write_text("Rust copyright fixture", encoding="utf-8")
        (docs / "LICENSE-MIT").write_text("Rust MIT fixture", encoding="utf-8")

    def package(self, name, version="1.0.0", license_name="LICENSE-MIT"):
        root = self.root / f"{name}-{version}"
        root.mkdir()
        if license_name:
            (root / license_name).write_text(f"{name} actual license text", encoding="utf-8")
        return {
            "name": name, "version": version, "license": "MIT",
            "source": "registry+https://user:secret@example.test/index?token=secret",
            "manifest_path": str(root / "Cargo.toml"), "license_file": None,
        }

    def render(self, packages):
        return notices.render_notices({"packages": packages}, self.sysroot, "rustc fixture")

    def test_includes_actual_texts_inventory_notices_and_toolchain_without_cache_paths(self):
        package = self.package("rubato")
        root = Path(package["manifest_path"]).parent
        (root / "NOTICE").write_text("Required attribution fixture", encoding="utf-8")
        (root / "licenses").mkdir()
        (root / "licenses" / "Apache-2.0.txt").write_text("Apache fixture", encoding="utf-8")
        output = self.render([package])
        for expected in ("rubato 1.0.0", "SPDX: MIT", "rubato actual license text",
                         "Required attribution fixture", "Apache fixture", "Rust copyright fixture",
                         "Rust MIT fixture", "development/build dependencies"):
            self.assertIn(expected, output)
        self.assertNotIn(str(self.root), output)
        self.assertNotIn("secret", output)
        self.assertIn("registry+https://example.test/index", output)

    def test_fails_when_a_dependency_has_no_actual_notice(self):
        with self.assertRaisesRegex(ValueError, "missing license/notice texts for missing 1.0.0"):
            self.render([self.package("missing", license_name=None)])

    def test_attribution_only_does_not_substitute_for_license_text(self):
        with self.assertRaisesRegex(ValueError, "attribution alone is insufficient"):
            self.render([self.package("incomplete", license_name="NOTICE")])

    def test_declared_license_file_is_required_and_collected(self):
        package = self.package("local", license_name=None)
        package["source"] = None
        package["license_file"] = "../../LICENSE"
        with self.assertRaisesRegex(ValueError, "unavailable license/notice texts for local"):
            self.render([package])
        package["license_file"] = "legal.txt"
        (Path(package["manifest_path"]).parent / "legal.txt").write_text("Declared fixture", encoding="utf-8")
        self.assertIn("Declared fixture", self.render([package]))

    def test_order_is_reproducible(self):
        first, second = self.package("aaa"), self.package("zzz")
        self.assertEqual(self.render([first, second]), self.render([second, first]))

    def test_missing_toolchain_copyright_fails_explicitly(self):
        (self.sysroot / "share" / "doc" / "rust" / "COPYRIGHT.html").unlink()
        with self.assertRaisesRegex(ValueError, "missing Rust toolchain COPYRIGHT"):
            self.render([self.package("valid")])

    def test_toolchain_collects_spdx_named_license_directory(self):
        docs = self.sysroot / "share" / "doc" / "rust"
        (docs / "licenses").mkdir()
        (docs / "LICENSE-MIT").rename(docs / "licenses" / "MIT.txt")
        self.assertIn("Rust MIT fixture", self.render([self.package("valid")]))

    def test_supplement_requires_exact_identity_hash_and_preserves_provenance(self):
        package = self.package("supplemented", license_name=None)
        package["source"] = "registry+https://example.test/index"
        text = self.root / "LICENSE.txt"
        text.write_bytes(b"Verified upstream license\n")
        manifest = self.root / "supplements.json"
        entry = {
            "name": package["name"], "version": package["version"], "license": package["license"],
            "source": package["source"], "file": text.name,
            "sha256": hashlib.sha256(text.read_bytes()).hexdigest(),
            "provenance": "Exact pinned upstream fixture", "urls": ["https://example.test/pinned/LICENSE"],
        }
        manifest.write_text(json.dumps([entry]), encoding="utf-8")
        render = lambda: notices.render_notices({"packages": [package]}, self.sysroot, "rustc fixture", manifest)
        output = render()
        self.assertIn("Verified upstream license", output)
        self.assertIn("Exact pinned upstream fixture", output)
        self.assertIn(entry["urls"][0], output)
        text.write_bytes(b"Verified upstream license\r\n")
        self.assertIn("Verified upstream license", render())
        package["license"] = "Apache-2.0"
        with self.assertRaisesRegex(ValueError, "identity mismatch"):
            render()
        package["license"] = "MIT"
        text.write_bytes(b"Tampered license\n")
        with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
            render()
        package["version"] = "2.0.0"
        with self.assertRaisesRegex(ValueError, "missing unique license supplement"):
            render()


if __name__ == "__main__":
    unittest.main()
