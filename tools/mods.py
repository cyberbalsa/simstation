#!/usr/bin/env python3
"""Validate and reproducibly package Sim Station folder/ZIP mods."""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import struct
import sys
import tomllib
import unicodedata
import zipfile


ROOT = Path(__file__).resolve().parents[1]
PACK_ID = re.compile(r"^[a-z0-9][a-z0-9-]*(?:\.[a-z0-9][a-z0-9-]*)+$")
SEMVER = re.compile(
    r"^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)"
    r"(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
)
CONTENT_ID = re.compile(
    r"^(?P<pack>[a-z0-9][a-z0-9-]*(?:\.[a-z0-9][a-z0-9-]*)+)"
    r":(?P<kind>[a-z][a-z0-9-]*)/(?P<name>[a-z0-9][a-z0-9/_-]*)$"
)
ROOT_KEYS = {
    "schema",
    "id",
    "version",
    "name",
    "description",
    "authors",
    "license",
    "homepage",
    "api",
    "class",
    "load_priority",
    "content",
    "localization",
    "atlas_indexes",
    "audio_manifests",
    "scenario_maps",
    "dependencies",
    "optional_dependencies",
    "conflicts",
    "load_after",
    "load_before",
    "replaces",
    "entrypoints",
    "state",
}
IGNORED_PARTS = {".git", ".cache", "__pycache__"}
IGNORED_FILES = {".DS_Store", "Thumbs.db"}
NATIVE_EXTENSIONS = {
    ".dll",
    ".dylib",
    ".exe",
    ".so",
    ".bat",
    ".cmd",
    ".com",
    ".ps1",
}
NESTED_ARCHIVE_EXTENSIONS = {".simmod", ".zip"}
DECLARED_ROOTS = {
    "content",
    "locales",
    "graphics",
    "audio",
    "generated",
    "lua",
    "maps",
    "scenarios",
    "tests",
}
MAX_ENTRIES = 20_000
MAX_PATH_BYTES = 240
MAX_ENTRY_SIZE = 512 * 1024 * 1024
MAX_TOTAL_SIZE = 2 * 1024 * 1024 * 1024
MAX_RATIO = 200


class ModError(ValueError):
    pass


def normalize_path(value: str) -> str:
    if "\0" in value or "\\" in value:
        raise ModError(f"unsafe package path: {value!r}")
    path = PurePosixPath(value)
    if path.is_absolute() or not value or value.endswith("/"):
        raise ModError(f"unsafe package path: {value!r}")
    if any(part in {"", ".", ".."} for part in path.parts):
        raise ModError(f"unsafe package path: {value!r}")
    if path.parts[0].endswith(":"):
        raise ModError(f"drive-prefixed package path: {value!r}")
    if len(value.encode("utf-8")) > MAX_PATH_BYTES:
        raise ModError(f"package path exceeds {MAX_PATH_BYTES} bytes: {value!r}")
    return path.as_posix()


def canonical_name(value: str) -> str:
    return unicodedata.normalize("NFC", value).lower()


def folder_files(folder: Path) -> list[tuple[str, bytes]]:
    result: list[tuple[str, bytes]] = []
    for path in sorted(folder.rglob("*")):
        if path.is_dir():
            continue
        relative = path.relative_to(folder).as_posix()
        if any(part in IGNORED_PARTS for part in PurePosixPath(relative).parts):
            continue
        if path.name in IGNORED_FILES:
            continue
        normalized = normalize_path(relative)
        if path.is_symlink():
            raise ModError(f"symlink is not allowed: {relative}")
        result.append((normalized, path.read_bytes()))
    return result


def archive_files(archive: Path) -> list[tuple[str, bytes]]:
    result: list[tuple[str, bytes]] = []
    seen: set[str] = set()
    total = 0
    with zipfile.ZipFile(archive) as package:
        entries = package.infolist()
        if len(entries) > MAX_ENTRIES:
            raise ModError(f"archive contains more than {MAX_ENTRIES} entries")
        for info in entries:
            if info.is_dir():
                continue
            name = normalize_path(info.filename)
            folded = canonical_name(name)
            if folded in seen:
                raise ModError(f"duplicate/case-colliding archive path: {name}")
            seen.add(folded)
            unix_mode = (info.external_attr >> 16) & 0o170000
            if unix_mode == 0o120000:
                raise ModError(f"archive symlink is not allowed: {name}")
            if unix_mode not in {0, 0o100000}:
                raise ModError(f"non-regular archive entry is not allowed: {name}")
            if info.flag_bits & 0x1:
                raise ModError(f"encrypted archive entry is not allowed: {name}")
            if info.file_size > MAX_ENTRY_SIZE:
                raise ModError(f"archive entry is too large: {name}")
            total += info.file_size
            if total > MAX_TOTAL_SIZE:
                raise ModError("archive expands beyond the 2 GiB package limit")
            if info.compress_size == 0:
                if info.file_size > 0:
                    raise ModError(f"archive entry has invalid compression size: {name}")
            elif info.file_size / info.compress_size > MAX_RATIO:
                raise ModError(f"archive entry exceeds compression ratio limit: {name}")
            data = package.read(info)
            if len(data) != info.file_size:
                raise ModError(f"archive entry length mismatch: {name}")
            result.append((name, data))
    return sorted(result)


def parse_manifest(files: dict[str, bytes]) -> dict:
    raw = files.get("mod.toml")
    if raw is None:
        raise ModError("mod.toml must exist at the package root")
    if len(raw) > 1024 * 1024:
        raise ModError("mod.toml exceeds 1 MiB")
    try:
        manifest = tomllib.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, tomllib.TOMLDecodeError) as error:
        raise ModError(f"invalid mod.toml: {error}") from error
    unknown = sorted(set(manifest) - ROOT_KEYS)
    if unknown:
        raise ModError(f"unknown manifest keys: {', '.join(unknown)}")
    if manifest.get("schema") != 1:
        raise ModError("manifest schema must be 1")
    pack_id = manifest.get("id")
    if not isinstance(pack_id, str) or not PACK_ID.fullmatch(pack_id):
        raise ModError("manifest id must be a lower-case reverse-DNS ID")
    version = manifest.get("version")
    if not isinstance(version, str) or not SEMVER.fullmatch(version):
        raise ModError("manifest version must be strict SemVer 2.0")
    if manifest.get("class") not in {"data", "code"}:
        raise ModError("manifest class must be 'data' or 'code'")
    if not isinstance(manifest.get("name"), str) or not manifest["name"]:
        raise ModError("manifest name is required")
    if not isinstance(manifest.get("authors"), list) or not manifest["authors"]:
        raise ModError("manifest authors must be a non-empty array")
    if not isinstance(manifest.get("license"), str) or not manifest["license"]:
        raise ModError("manifest license is required")
    priority = manifest.get("load_priority", 0)
    if not isinstance(priority, int) or not -1000 <= priority <= 1000:
        raise ModError("load_priority must be an integer from -1000 through 1000")
    for field in ("dependencies", "optional_dependencies", "conflicts"):
        for index, record in enumerate(manifest.get(field, []), 1):
            if not isinstance(record, dict) or set(record) - {"id", "version"}:
                raise ModError(f"{field}[{index}] must contain only id/version")
            if not PACK_ID.fullmatch(str(record.get("id", ""))):
                raise ModError(f"{field}[{index}] has an invalid ID")
            if not isinstance(record.get("version"), str):
                raise ModError(f"{field}[{index}] version is required")
    if manifest["class"] == "code" and not manifest.get("entrypoints"):
        raise ModError("code packs require at least one entrypoint")
    for field in (
        "content",
        "localization",
        "atlas_indexes",
        "audio_manifests",
        "scenario_maps",
        "entrypoints",
    ):
        values = manifest.get(field, [])
        if not isinstance(values, list) or not all(
            isinstance(value, str) for value in values
        ):
            raise ModError(f"{field} must be an array of paths")
        for value in values:
            normalize_path(value.replace("*", "x").replace("?", "x"))
    for field in ("load_after", "load_before", "replaces"):
        values = manifest.get(field, [])
        if not isinstance(values, list) or not all(
            isinstance(value, str) for value in values
        ):
            raise ModError(f"{field} must be an array of strings")
    for path in manifest.get("entrypoints", []):
        if path not in files:
            raise ModError(f"entrypoint does not exist: {path}")
    return manifest


def glob_matches(pattern: str, names: list[str]) -> list[str]:
    normalize_path(pattern.replace("*", "x"))
    # pathlib's recursive matcher and fnmatch differ around **. Accept both,
    # then canonicalize ordering for identical folder/ZIP results.
    return sorted(
        name
        for name in names
        if fnmatch.fnmatchcase(name, pattern)
        or PurePosixPath(name).match(pattern)
    )


def validate_content(manifest: dict, files: dict[str, bytes]) -> dict:
    names = sorted(files)
    selected: list[str] = []
    definitions = 0
    seen_ids: set[str] = set()
    declared_replacements = set(manifest.get("replaces", []))
    for pattern in manifest.get("content", []):
        if not isinstance(pattern, str):
            raise ModError("content patterns must be strings")
        matches = glob_matches(pattern, names)
        if not matches:
            raise ModError(f"content pattern matched no files: {pattern}")
        selected.extend(matches)
    for path in sorted(set(selected)):
        if not path.endswith(".json"):
            raise ModError(f"content file must be JSON: {path}")
        try:
            document = json.loads(files[path])
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise ModError(f"invalid JSON in {path}: {error}") from error
        values = document.get("definitions") if isinstance(document, dict) else document
        if not isinstance(values, list):
            raise ModError(f"{path}: definitions must be an array")
        for index, definition in enumerate(values):
            if not isinstance(definition, dict):
                raise ModError(f"{path}/definitions/{index}: expected object")
            content_id = definition.get("id")
            match = CONTENT_ID.fullmatch(str(content_id or ""))
            if not match:
                raise ModError(f"{path}/definitions/{index}: invalid content ID")
            if content_id in seen_ids:
                raise ModError(f"duplicate content ID inside pack: {content_id}")
            seen_ids.add(content_id)
            replacement = definition.get("replaces")
            if match.group("pack") != manifest["id"] and not replacement:
                raise ModError(f"new ID is outside pack namespace: {content_id}")
            if definition.get("kind", match.group("kind")) != match.group("kind"):
                raise ModError(f"kind does not match content ID: {content_id}")
            if replacement:
                if replacement != content_id or replacement not in declared_replacements:
                    raise ModError(f"undeclared or mismatched replacement: {content_id}")
            definitions += 1
    return {
        "content_files": sorted(set(selected)),
        "definition_count": definitions,
        "content_ids": sorted(seen_ids),
    }


def validate_path(path: Path) -> dict:
    if path.is_dir():
        records = folder_files(path)
        representation = "folder"
    elif path.is_file() and path.suffix == ".simmod":
        records = archive_files(path)
        representation = "simmod"
    else:
        raise ModError("mod path must be a folder or .simmod archive")
    if len(records) > MAX_ENTRIES:
        raise ModError(f"package contains more than {MAX_ENTRIES} files")
    folded: set[str] = set()
    total = 0
    files: dict[str, bytes] = {}
    for name, data in records:
        canonical = canonical_name(name)
        if canonical in folded:
            raise ModError(f"duplicate/case-colliding path: {name}")
        folded.add(canonical)
        total += len(data)
        if len(data) > MAX_ENTRY_SIZE or total > MAX_TOTAL_SIZE:
            raise ModError("package exceeds expansion limits")
        suffix = PurePosixPath(name).suffix.lower()
        if suffix in NATIVE_EXTENSIONS:
            raise ModError(f"native/executable file is not allowed: {name}")
        if suffix in NESTED_ARCHIVE_EXTENSIONS:
            raise ModError(f"nested archive is not allowed: {name}")
        files[name] = data
    manifest = parse_manifest(files)
    for name in files:
        first = PurePosixPath(name).parts[0]
        allowed_root_file = (
            name == "mod.toml"
            or first.startswith(("README", "LICENSE", "NOTICE", "CREDITS"))
        )
        if not allowed_root_file and first not in DECLARED_ROOTS:
            raise ModError(f"undeclared package root entry: {first}")
        if manifest["class"] == "data" and name.endswith(".lua"):
            raise ModError(f"data-only pack contains Lua code: {name}")
    content = validate_content(manifest, files)
    canonical = hashlib.sha256()
    for name, data in records:
        encoded = name.encode("utf-8")
        canonical.update(struct.pack("<Q", len(encoded)))
        canonical.update(encoded)
        canonical.update(struct.pack("<Q", len(data)))
        canonical.update(data)
    return {
        "ok": True,
        "path": str(path),
        "representation": representation,
        "id": manifest["id"],
        "version": manifest["version"],
        "class": manifest["class"],
        "file_count": len(files),
        "expanded_bytes": total,
        "tree_sha256": canonical.hexdigest(),
        **content,
    }


def package_folder(folder: Path, output: Path | None) -> tuple[Path, dict]:
    report = validate_path(folder)
    manifest = tomllib.loads((folder / "mod.toml").read_text(encoding="utf-8"))
    if output is None:
        output = (
            ROOT
            / "dist"
            / "mods"
            / f"{manifest['id']}-{manifest['version']}.simmod"
        )
    output.parent.mkdir(parents=True, exist_ok=True)
    records = folder_files(folder)
    with zipfile.ZipFile(
        output,
        "w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
        strict_timestamps=True,
    ) as archive:
        for name, data in records:
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data, compresslevel=9)
    archive_report = validate_path(output)
    archive_report["archive_sha256"] = hashlib.sha256(output.read_bytes()).hexdigest()
    archive_report["source_tree_sha256"] = report["tree_sha256"]
    return output, archive_report


def print_report(report: dict) -> None:
    print(json.dumps(report, indent=2, sort_keys=True))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    validate = commands.add_parser("validate")
    validate.add_argument("path", type=Path)
    package = commands.add_parser("package")
    package.add_argument("path", type=Path)
    package.add_argument("--output", type=Path)
    test = commands.add_parser("test")
    test.add_argument("path", type=Path)
    return parser


def main() -> None:
    args = build_parser().parse_args()
    try:
        if args.command == "validate":
            print_report(validate_path(args.path.resolve()))
        elif args.command == "package":
            output, report = package_folder(
                args.path.resolve(),
                args.output.resolve() if args.output else None,
            )
            report["output"] = str(output)
            print_report(report)
        elif args.command == "test":
            source = validate_path(args.path.resolve())
            output, packaged = package_folder(args.path.resolve(), None)
            if source["content_ids"] != packaged["content_ids"]:
                raise ModError("folder/archive registries differ")
            print_report({
                "ok": True,
                "folder": source,
                "archive": packaged,
                "temporary_output": str(output),
            })
    except (OSError, ModError, zipfile.BadZipFile) as error:
        print(f"mod error: {error}", file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
