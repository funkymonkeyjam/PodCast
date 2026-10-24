"""Collect pinned Windows Rust dependency and toolchain notices without compiling."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import urlsplit, urlunsplit


TARGET = "x86_64-pc-windows-msvc"
NOTICE_NAME = re.compile(r"^(licen[cs]e|copying|copyright|notice|unlicense)(?:$|[._-])", re.I)
SUPPLEMENTS = Path(__file__).resolve().parents[1] / "licenses" / "native" / "supplements.json"


def source_reference(source):
    if not source:
        return "local project"
    kind, separator, address = source.partition("+")
    parsed = urlsplit(address)
    if not separator or parsed.scheme not in ("https", "http", "ssh", "git"):
        raise ValueError("unsupported dependency source reference")
    # Source URLs may contain credentials or access-token query parameters.
    host = parsed.hostname or ""
    if parsed.port:
        host += f":{parsed.port}"
    revision = parsed.fragment if re.fullmatch(r"[0-9a-fA-F]{40,64}", parsed.fragment) else ""
    return kind + "+" + urlunsplit((parsed.scheme, host, parsed.path, "", revision))


def notice_files(root, license_file=None):
    files = {path for path in root.iterdir() if path.is_file() and NOTICE_NAME.match(path.name)}
    for directory in ("licenses", "LICENSES", "license"):
        folder = root / directory
        if folder.is_dir():
            files.update(path for path in folder.rglob("*") if path.is_file())
    if license_file:
        declared = root / license_file
        if not declared.is_file():
            raise ValueError("declared license_file is unavailable")
        files.add(declared)
    return sorted(files, key=lambda path: (path.name.casefold(), path.as_posix()))


def append_texts(lines, files, owner):
    if not files:
        raise ValueError(f"missing license/notice texts for {owner}")
    for path in files:
        try:
            text = path.read_text(encoding="utf-8-sig").strip()
        except (OSError, UnicodeError) as error:
            raise ValueError(f"cannot read notice {path.name} for {owner}") from error
        if not text:
            raise ValueError(f"empty notice {path.name} for {owner}")
        lines.extend((f"--- {path.name} ---", text, ""))


def supplemental_notice(package, manifest):
    entries = json.loads(manifest.read_text(encoding="utf-8"))
    matches = [entry for entry in entries
               if (entry["name"], entry["version"]) == (package["name"], package["version"])]
    if len(matches) != 1:
        raise ValueError(f'missing unique license supplement for {package["name"]} {package["version"]}')
    entry = matches[0]
    if (entry["license"], entry["source"]) != (package.get("license"), package.get("source")):
        raise ValueError(f'license supplement identity mismatch for {package["name"]} {package["version"]}')
    path = (manifest.parent / entry["file"]).resolve()
    if not path.is_relative_to(manifest.parent.resolve()):
        raise ValueError("license supplement must remain inside its manifest directory")
    # Git checkouts may use CRLF; hashes identify the upstream UTF-8/LF text.
    digest = hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
    if digest != entry["sha256"]:
        raise ValueError(f'license supplement SHA-256 mismatch for {package["name"]} {package["version"]}')
    provenance = [f'Supplement: {entry["provenance"]}', f'Supplement SHA-256 (UTF-8/LF): {digest}']
    provenance.extend(f"Source text/declaration: {url}" for url in entry["urls"])
    return path, provenance


def render_notices(metadata, sysroot, rustc_version, supplement_manifest=SUPPLEMENTS):
    lines = [
        "PodCast native Rust notices", "",
        f"Target: {TARGET}", f"Toolchain: {rustc_version}",
        "Inventory: all packages reported by locked, offline cargo metadata.",
        "This is a superset including development/build dependencies, not a claim that every package is linked.",
        "Local/cache paths are omitted. SPDX expressions are the package authors' declarations.", "",
    ]
    packages = sorted(metadata["packages"], key=lambda item: (item["name"], item["version"], item.get("source") or ""))
    for package in packages:
        owner = f'{package["name"]} {package["version"]}'
        lines.extend((
            f"=== {owner} ===",
            f'SPDX: {package.get("license") or "not declared; see bundled text"}',
            f'Source: {source_reference(package.get("source"))}', "",
        ))
        root = Path(package["manifest_path"]).parent
        try:
            files = notice_files(root, package.get("license_file"))
        except (OSError, ValueError) as error:
            raise ValueError(f"unavailable license/notice texts for {owner}") from error
        if not package.get("license_file") and not any(
            not re.match(r"^(notice|copyright)(?:$|[._-])", path.name, re.I) for path in files
        ):
            try:
                supplement, provenance = supplemental_notice(package, Path(supplement_manifest))
            except (OSError, ValueError) as error:
                raise ValueError(f"missing license/notice texts for {owner}; attribution alone is insufficient; {error}") from error
            lines.extend(provenance + [""])
            files.append(supplement)
        append_texts(lines, files, owner)
    lines.extend(("=== Rust toolchain / standard library notices ===", ""))
    docs = Path(sysroot) / "share" / "doc" / "rust"
    files = notice_files(docs) if docs.is_dir() else []
    if not any(path.name.casefold().startswith("copyright") for path in files):
        raise ValueError("missing Rust toolchain COPYRIGHT notice; install rust-docs or supply the complete toolchain notices")
    if not any(path.name.casefold().startswith(("license", "copying"))
               or path.relative_to(docs).parts[0].casefold() in ("license", "licenses") for path in files):
        raise ValueError("missing Rust toolchain license texts; install rust-docs or supply the complete toolchain notices")
    append_texts(lines, files, "Rust toolchain")
    return "\n".join(lines)


def command_output(command):
    try:
        return subprocess.run(command, capture_output=True, text=True, encoding="utf-8", check=True).stdout
    except (OSError, subprocess.CalledProcessError) as error:
        raise ValueError(f"{Path(command[0]).name} command failed; no notices generated") from error


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cargo", default="cargo")
    parser.add_argument("--rustc", default="rustc")
    parser.add_argument("--supplemental-notices", type=Path, default=SUPPLEMENTS)
    args = parser.parse_args()
    artifacts = Path(__file__).resolve().parents[1] / "artifacts"
    output = args.output.resolve()
    if not output.is_relative_to(artifacts):
        parser.error("--output must be inside this repository's ignored artifacts directory")
    metadata = json.loads(command_output([
        args.cargo, "metadata", "--format-version", "1", "--manifest-path", str(args.manifest),
        "--locked", "--offline", "--filter-platform", TARGET,
    ]))
    sysroot = command_output([args.rustc, "--print", "sysroot"]).strip()
    version = command_output([args.rustc, "--version"]).strip()
    notices = render_notices(metadata, sysroot, version, args.supplemental_notices)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(notices, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError) as error:
        sys.exit(f"Notice collection failed: {error}")
