#!/usr/bin/env python3
"""Cross-platform development entry point for Sim Station."""

from __future__ import annotations

import argparse
import importlib.metadata
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tomllib
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
MINIMUM_PYTHON = (3, 11)
IGNORED_AUDIT_PARTS = {
    ".git",
    ".cache",
    "__pycache__",
    "assets",
    "build",
    "dist",
}
LFS_POINTER_PREFIX = b"version https://git-lfs.github.com/spec/v1"
MARKDOWN_LINK = re.compile(r"!?\[[^\]]*\]\(([^)\n]+)\)")


def run(
    command: list[str],
    *,
    check: bool = True,
    capture: bool = False,
) -> subprocess.CompletedProcess[str]:
    # Command traces belong on stderr so JSON-producing subcommands keep stdout
    # machine-readable when they delegate to Lua or another helper.
    print("+", " ".join(command), flush=True, file=sys.stderr)
    result = subprocess.run(
        command,
        cwd=ROOT,
        check=False,
        text=True,
        capture_output=capture,
    )
    if capture:
        if result.stdout:
            print(result.stdout, end="")
        if result.stderr:
            print(result.stderr, end="", file=sys.stderr)
    if check and result.returncode:
        raise SystemExit(result.returncode)
    return result


def find_executable(*names: str) -> str | None:
    for name in names:
        found = shutil.which(name)
        if found:
            return found
    return None


def executable(*names: str) -> str:
    found = find_executable(*names)
    if found:
        return found
    print(f"missing required executable: {' or '.join(names)}", file=sys.stderr)
    raise SystemExit(2)


def probe(command: list[str]) -> tuple[bool, str]:
    try:
        result = subprocess.run(
            command,
            cwd=ROOT,
            check=False,
            text=True,
            capture_output=True,
            timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        return False, str(error)
    output = (result.stdout or result.stderr).strip().splitlines()
    summary = output[0] if output else f"exit {result.returncode}"
    return result.returncode == 0, summary


def command_run(args: argparse.Namespace) -> int:
    command = [executable("love"), str(ROOT)]
    if args.scenario:
        command.append(f"--scenario={args.scenario}")
    return run(command).returncode


def command_test(_: argparse.Namespace) -> int:
    lua_result = run(
        [executable("luajit", "lua", "lua5.1", "lua51"), "tests/run.lua"]
    )
    if lua_result.returncode:
        return lua_result.returncode
    return run(
        [
            sys.executable,
            "-m",
            "unittest",
            "-v",
            "tests.test_map_import",
            "tests.test_dm_appearances",
            "tests.test_mods",
        ]
    ).returncode


def is_ignored_audit_path(path: Path) -> bool:
    try:
        relative = path.relative_to(ROOT)
    except ValueError:
        return True
    return any(part in IGNORED_AUDIT_PARTS for part in relative.parts)


def audit_structured_files() -> None:
    for manifest in sorted(ROOT.rglob("*.json")):
        if is_ignored_audit_path(manifest):
            continue
        with manifest.open("r", encoding="utf-8") as handle:
            json.load(handle)
        print("json ok", manifest.relative_to(ROOT))

    for manifest in sorted(ROOT.rglob("*.toml")):
        if is_ignored_audit_path(manifest):
            continue
        with manifest.open("rb") as handle:
            tomllib.load(handle)
        print("toml ok", manifest.relative_to(ROOT))


def audit_core_boundary() -> None:
    violations: list[str] = []
    love_reference = re.compile(r"\blove\s*[\.:]")
    for source in sorted((ROOT / "src" / "core").glob("**/*.lua")):
        for line_number, line in enumerate(
            source.read_text(encoding="utf-8").splitlines(),
            1,
        ):
            if love_reference.search(line):
                violations.append(
                    f"{source.relative_to(ROOT)}:{line_number}: {line.strip()}"
                )
    if violations:
        raise SystemExit(
            "src/core must remain independent from LÖVE:\n" + "\n".join(violations)
        )
    print("core boundary ok")


def audit_markdown_links() -> None:
    failures: list[str] = []
    documents = [ROOT / "README.md", ROOT / "AGENTS.md"]
    documents.extend(sorted((ROOT / "docs").rglob("*.md")))
    documents.extend(sorted((ROOT / "tools").glob("*.md")))
    for document in documents:
        if not document.is_file():
            continue
        source = document.read_text(encoding="utf-8")
        for match in MARKDOWN_LINK.finditer(source):
            target = match.group(1).strip()
            if target.startswith("<") and target.endswith(">"):
                target = target[1:-1]
            # Remove an optional Markdown title. Project-local paths do not
            # contain spaces; angle brackets cover the exceptional case.
            if " " in target and not target.startswith(("http://", "https://")):
                target = target.split(" ", 1)[0]
            if (
                not target
                or target.startswith("#")
                or re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target)
            ):
                continue
            path_text = unquote(target.split("#", 1)[0])
            if not path_text:
                continue
            destination = (
                ROOT / path_text.lstrip("/")
                if target.startswith("/")
                else document.parent / path_text
            )
            if not destination.exists():
                line = source.count("\n", 0, match.start()) + 1
                failures.append(
                    f"{document.relative_to(ROOT)}:{line}: "
                    f"missing link target {target}"
                )
    if failures:
        raise SystemExit("broken local Markdown links:\n" + "\n".join(failures))
    print(f"markdown links ok ({len(documents)} documents)")


def audit_workflow_pins() -> None:
    lock_path = ROOT / "tools" / "toolchain.json"
    lock = json.loads(lock_path.read_text(encoding="utf-8"))
    expected_actions = lock["github_actions"]
    seen: set[str] = set()
    failures: list[str] = []
    use_pattern = re.compile(r"^\s*uses:\s*([^@\s]+)@([^\s#]+)(?:\s+#\s*(\S+))?\s*$")
    workflows = sorted((ROOT / ".github" / "workflows").glob("*.yml"))
    for workflow in workflows:
        for line_number, line in enumerate(
            workflow.read_text(encoding="utf-8").splitlines(),
            1,
        ):
            match = use_pattern.match(line)
            if not match:
                continue
            action, revision, tag = match.groups()
            seen.add(action)
            if not re.fullmatch(r"[0-9a-f]{40}", revision):
                failures.append(
                    f"{workflow.relative_to(ROOT)}:{line_number}: "
                    f"{action} is not pinned to a 40-character revision"
                )
                continue
            expected = expected_actions.get(action)
            if not expected:
                failures.append(
                    f"{workflow.relative_to(ROOT)}:{line_number}: "
                    f"{action} is absent from tools/toolchain.json"
                )
                continue
            if revision != expected["revision"] or tag != expected["tag"]:
                failures.append(
                    f"{workflow.relative_to(ROOT)}:{line_number}: "
                    f"{action} does not match its toolchain lock"
                )
    unused = sorted(set(expected_actions) - seen)
    if unused:
        failures.append(
            "tools/toolchain.json has unused action pins: " + ", ".join(unused)
        )
    combined_workflows = "\n".join(
        workflow.read_text(encoding="utf-8") for workflow in workflows
    )
    if f'python-version: "{lock["ci"]["python"]}"' not in combined_workflows:
        failures.append("workflow Python does not match tools/toolchain.json")
    lua_versions = lock["ci"]["lua"]
    if isinstance(lua_versions, str):
        lua_versions = [lua_versions]
    for lua_version in lua_versions:
        literal_version = f'luaVersion: "{lua_version}"'
        expression_version = "luaVersion: ${{ matrix.lua_version }}"
        matrix_values = {
            f"lua_version: {lua_version}",
            f'lua_version: "{lua_version}"',
        }
        if literal_version not in combined_workflows and not (
            expression_version in combined_workflows
            and any(value in combined_workflows for value in matrix_values)
        ):
            failures.append(
                f"workflow Lua {lua_version} does not match tools/toolchain.json"
            )
    for runner in lock["ci"].get("runners", []):
        if runner not in combined_workflows:
            failures.append(
                f"workflow runner {runner} does not match tools/toolchain.json"
            )
    if failures:
        raise SystemExit("workflow/toolchain audit failed:\n" + "\n".join(failures))
    print(f"workflow pins ok ({len(workflows)} workflows)")


def audit_lfs_attributes() -> None:
    attributes = (ROOT / ".gitattributes").read_text(encoding="utf-8")
    failures = []
    for extension in ("dmi", "png", "ogg", "wav", "xm", "mod", "s3m"):
        pattern = re.compile(
            rf"^\*\.{re.escape(extension)}\s+.*\bfilter=lfs\b",
            re.MULTILINE,
        )
        if not pattern.search(attributes):
            failures.append(f"*.{extension}")
    if failures:
        raise SystemExit("Git LFS attributes missing for: " + ", ".join(failures))
    print("git lfs attributes ok")


def payload_counts(root: Path, suffix: str) -> tuple[int, int]:
    actual = 0
    pointers = 0
    if not root.exists():
        return actual, pointers
    for path in root.rglob(f"*{suffix}"):
        try:
            with path.open("rb") as handle:
                beginning = handle.read(128)
        except OSError:
            continue
        if beginning.startswith(LFS_POINTER_PREFIX):
            pointers += 1
        else:
            actual += 1
    return actual, pointers


def media_payload_state() -> tuple[bool, str]:
    graphics_root = ROOT / "assets" / "runtime" / "goon" / "graphics"
    audio_root = ROOT / "assets" / "runtime" / "goon" / "audio"
    catalogs = (graphics_root / "atlas.json").is_file() and (
        audio_root / "audio.json"
    ).is_file()
    if not catalogs:
        return False, "generated media catalogs are absent"
    graphics, graphics_pointers = payload_counts(graphics_root, ".png")
    audio, audio_pointers = payload_counts(audio_root, ".ogg")
    if graphics_pointers or audio_pointers:
        return (
            False,
            "media checkout contains "
            f"{graphics_pointers + audio_pointers} Git LFS pointers",
        )
    if graphics == 0:
        return False, "graphics payloads are absent or Git LFS pointers"
    if audio == 0:
        return False, "audio payloads are absent or Git LFS pointers"
    return (
        True,
        f"generated media is hydrated ({graphics} atlas pages, {audio} audio files)",
    )


def audit_mods() -> None:
    manifests = sorted((ROOT / "mods").glob("**/mod.toml"))
    for manifest in manifests:
        run(
            [
                sys.executable,
                "tools/mods.py",
                "validate",
                str(manifest.parent.relative_to(ROOT)),
            ]
        )
    print(f"mods ok ({len(manifests)} packs)")


def command_audit(args: argparse.Namespace) -> int:
    command_test(argparse.Namespace())
    run([sys.executable, "-m", "compileall", "-q", "tools"])
    audit_structured_files()
    audit_core_boundary()
    audit_markdown_links()
    audit_workflow_pins()
    audit_lfs_attributes()
    audit_mods()

    asset_mode = getattr(args, "assets", "auto")
    hydrated, media_message = media_payload_state()
    if asset_mode == "required" or (asset_mode == "auto" and hydrated):
        run([sys.executable, "tools/assets.py", "audit"])
    elif asset_mode == "auto":
        print(f"asset audit skipped: {media_message}")
    else:
        print("asset audit skipped: explicitly disabled")

    git = find_executable("git")
    if git and (ROOT / ".git").exists():
        run([git, "diff", "--check"])
    else:
        print("git diff check skipped: not a Git worktree")
    print("audit passed")
    return 0


def check_record(
    identifier: str,
    status: str,
    message: str,
    *,
    required: bool,
    path: str | None = None,
    version: str | None = None,
) -> dict[str, object]:
    return {
        "id": identifier,
        "status": status,
        "required": required,
        "message": message,
        "path": path,
        "version": version,
    }


def build_doctor_report(requirements: set[str]) -> dict[str, object]:
    expanded = set(requirements)
    if "full" in expanded:
        expanded.update({"runtime", "assets", "luajit"})
    if "runtime" in expanded:
        expanded.add("love")
    if "assets" in expanded:
        expanded.update({"git-lfs", "ffmpeg", "ffprobe", "pillow", "media"})

    checks: list[dict[str, object]] = []
    python_required = True
    python_ok = sys.version_info >= MINIMUM_PYTHON
    checks.append(
        check_record(
            "python",
            "pass" if python_ok else "fail",
            (
                "supported Python runtime"
                if python_ok
                else "Python 3.11 or newer is required"
            ),
            required=python_required,
            path=sys.executable,
            version=platform.python_version(),
        )
    )

    lua_path = find_executable("luajit", "lua", "lua5.1", "lua51")
    lua_required = True
    lua_ok = False
    lua_version = None
    lua_message = "LuaJIT or a compatible Lua interpreter is missing"
    if lua_path:
        lua_ok, lua_version = probe(
            [
                lua_path,
                "-e",
                ("io.write(_VERSION); " 'if jit then io.write(" / ", jit.version) end'),
            ]
        )
        lua_message = (
            "headless Lua runtime is available"
            if lua_ok
            else "Lua runtime could not execute a probe"
        )
    checks.append(
        check_record(
            "lua",
            "pass" if lua_ok else "fail",
            lua_message,
            required=lua_required,
            path=lua_path,
            version=lua_version,
        )
    )

    luajit_required = "luajit" in expanded
    is_luajit = bool(lua_ok and lua_version and "LuaJIT" in lua_version)
    checks.append(
        check_record(
            "luajit",
            ("pass" if is_luajit else ("fail" if luajit_required else "warn")),
            (
                "LuaJIT runtime detected"
                if is_luajit
                else "plain Lua is usable for tests, but release CI uses LuaJIT"
            ),
            required=luajit_required,
            path=lua_path,
            version=lua_version,
        )
    )

    tool_specs = [
        ("love", ("love",), ["--version"], "love" in expanded),
        ("git-lfs", ("git-lfs",), ["version"], "git-lfs" in expanded),
        ("ffmpeg", ("ffmpeg",), ["-version"], "ffmpeg" in expanded),
        ("ffprobe", ("ffprobe",), ["-version"], "ffprobe" in expanded),
    ]
    for identifier, names, version_args, required in tool_specs:
        path = find_executable(*names)
        ok = False
        version = None
        if path:
            ok, version = probe([path, *version_args])
        supported = ok
        compatibility_message = None
        if identifier == "love" and ok and version:
            supported = bool(re.search(r"\bLOVE 11\.5\b", version))
            if not supported:
                compatibility_message = "LÖVE 11.5 is required by conf.lua"
        checks.append(
            check_record(
                identifier,
                "pass" if supported else ("fail" if required else "warn"),
                (
                    compatibility_message
                    or (
                        f"{identifier} is available"
                        if ok
                        else f"{identifier} is not available"
                    )
                ),
                required=required,
                path=path,
                version=version,
            )
        )

    pillow_required = "pillow" in expanded
    try:
        pillow_version = importlib.metadata.version("Pillow")
    except importlib.metadata.PackageNotFoundError:
        pillow_version = None
    checks.append(
        check_record(
            "pillow",
            ("pass" if pillow_version else ("fail" if pillow_required else "warn")),
            (
                "Pillow is available"
                if pillow_version
                else "Pillow is not installed for this Python"
            ),
            required=pillow_required,
            path=None,
            version=pillow_version,
        )
    )

    media_required = "media" in expanded
    hydrated, media_message = media_payload_state()
    checks.append(
        check_record(
            "media",
            "pass" if hydrated else ("fail" if media_required else "warn"),
            media_message,
            required=media_required,
        )
    )

    failures = [
        check for check in checks if check["required"] and check["status"] != "pass"
    ]
    return {
        "schema_version": 1,
        "status": "pass" if not failures else "fail",
        "project_root": str(ROOT),
        "platform": {
            "system": platform.system(),
            "release": platform.release(),
            "machine": platform.machine(),
        },
        "checks": checks,
        "summary": {
            "passed": sum(check["status"] == "pass" for check in checks),
            "warnings": sum(check["status"] == "warn" for check in checks),
            "failures": len(failures),
        },
    }


def print_doctor_report(report: dict[str, object], output_format: str) -> None:
    if output_format == "json":
        print(json.dumps(report, indent=2, sort_keys=True))
        return
    for check in report["checks"]:
        marker = {
            "pass": "ok",
            "warn": "warning",
            "fail": "missing",
        }[check["status"]]
        requirement = "required" if check["required"] else "optional"
        details = check["version"] or check["path"] or check["message"]
        print(f"{marker:7} {check['id']:9} ({requirement}) {details}")
    summary = report["summary"]
    print(
        f"doctor {report['status']}: {summary['passed']} passed, "
        f"{summary['warnings']} warnings, {summary['failures']} failures"
    )


def command_doctor(args: argparse.Namespace) -> int:
    report = build_doctor_report(set(args.require or []))
    print_doctor_report(report, args.format)
    return 0 if report["status"] == "pass" else 2


def command_info(_: argparse.Namespace) -> int:
    return command_doctor(argparse.Namespace(require=[], format="json"))


def add_benchmark_arguments(
    parser: argparse.ArgumentParser,
    *,
    include_scenario: bool = True,
) -> None:
    if include_scenario:
        parser.add_argument(
            "scenario",
            nargs="?",
            default="ci",
            choices=sorted(SCENARIO_NAMES),
        )
    parser.add_argument("--seed", type=int, default=1337)
    parser.add_argument("--ticks", type=int)
    parser.add_argument("--shifts", type=int)
    parser.add_argument("--width", type=int)
    parser.add_argument("--height", type=int)
    parser.add_argument("--crew", type=int)
    parser.add_argument("--checkpoint-every", type=int)
    parser.add_argument("--warmup-ticks", type=int)
    parser.add_argument("--min-tps", type=float)
    parser.add_argument("--max-p95-ms", type=float)
    parser.add_argument(
        "--golden",
        choices=("auto", "required", "skip"),
        default="auto",
        help="check matching baselines; 'required' fails if none matches",
    )
    parser.add_argument("--output", help="also write the JSON report to this path")


SCENARIO_NAMES = {
    "smoke",
    "ci",
    "nominal-100",
    "disaster-100",
    "soak",
}


def command_benchmark(args: argparse.Namespace) -> int:
    lua = executable("luajit", "lua", "lua5.1", "lua51")
    command = [
        lua,
        "tools/benchmark.lua",
        "--scenario",
        args.scenario,
        "--seed",
        str(args.seed),
    ]
    option_names = {
        "ticks": "--ticks",
        "shifts": "--shifts",
        "width": "--width",
        "height": "--height",
        "crew": "--crew",
        "checkpoint_every": "--checkpoint-every",
        "warmup_ticks": "--warmup-ticks",
        "min_tps": "--min-tps",
        "max_p95_ms": "--max-p95-ms",
    }
    for attribute, flag in option_names.items():
        value = getattr(args, attribute, None)
        if value is not None:
            command.extend([flag, str(value)])

    shape_overridden = (
        any(
            getattr(args, name, None) is not None
            for name in (
                "ticks",
                "shifts",
                "width",
                "height",
                "crew",
                "checkpoint_every",
            )
        )
        or args.seed != 1337
    )
    require_golden = args.golden == "required" or (
        args.golden == "auto"
        and args.scenario in {"smoke", "ci"}
        and not shape_overridden
    )
    if require_golden:
        command.append("--require-golden")
    if args.golden == "skip":
        # An empty path prevents an incidental matching local baseline.
        command.extend(["--baseline", "tests/fixtures/no-baselines.json"])
    if args.output:
        output = Path(args.output)
        absolute_output = output if output.is_absolute() else ROOT / output
        absolute_output.parent.mkdir(parents=True, exist_ok=True)
        command.extend(["--output", str(absolute_output)])
    return run(command).returncode


def command_soak(args: argparse.Namespace) -> int:
    args.scenario = "soak"
    return command_benchmark(args)


def command_ci(_: argparse.Namespace) -> int:
    doctor_result = command_doctor(
        argparse.Namespace(require=["luajit"], format="text")
    )
    if doctor_result:
        return doctor_result
    command_audit(argparse.Namespace(assets="auto"))
    return command_benchmark(
        argparse.Namespace(
            scenario="ci",
            seed=1337,
            ticks=None,
            shifts=None,
            width=None,
            height=None,
            crew=None,
            checkpoint_every=None,
            warmup_ticks=None,
            min_tps=None,
            max_p95_ms=None,
            golden="required",
            output=None,
        )
    )


def command_mod(args: argparse.Namespace) -> int:
    command = [sys.executable, "tools/mods.py", args.mod_command, args.path]
    if args.mod_command == "package" and args.output:
        command.extend(["--output", args.output])
    return run(command).returncode


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    run_parser = subparsers.add_parser("run", help="start Sim Station in LÖVE")
    run_parser.add_argument(
        "--scenario",
        help="launch a loaded scenario by namespaced content ID",
    )
    run_parser.set_defaults(callback=command_run)

    test_parser = subparsers.add_parser(
        "test",
        help="run deterministic simulation and map-import tests",
    )
    test_parser.set_defaults(callback=command_test)

    audit_parser = subparsers.add_parser(
        "audit",
        help="run the mandatory fast handoff checks",
    )
    audit_parser.add_argument(
        "--assets",
        choices=("auto", "required", "skip"),
        default="auto",
        help="auto audits hydrated media and skips LFS-only checkouts",
    )
    audit_parser.set_defaults(callback=command_audit)

    doctor_parser = subparsers.add_parser(
        "doctor",
        help="diagnose the local toolchain without modifying it",
    )
    doctor_parser.add_argument(
        "--format",
        choices=("text", "json"),
        default="text",
    )
    doctor_parser.add_argument(
        "--require",
        action="append",
        choices=(
            "luajit",
            "love",
            "git-lfs",
            "ffmpeg",
            "ffprobe",
            "pillow",
            "media",
            "runtime",
            "assets",
            "full",
        ),
        help="promote an optional capability (or capability group) to required",
    )
    doctor_parser.set_defaults(callback=command_doctor)

    info_parser = subparsers.add_parser(
        "info",
        help="backward-compatible JSON alias for doctor",
    )
    info_parser.set_defaults(callback=command_info)

    benchmark_parser = subparsers.add_parser(
        "benchmark",
        help="run a deterministic headless benchmark",
    )
    add_benchmark_arguments(benchmark_parser)
    benchmark_parser.set_defaults(callback=command_benchmark)

    soak_parser = subparsers.add_parser(
        "soak",
        help="run one or more complete simulated shifts headlessly",
    )
    add_benchmark_arguments(soak_parser, include_scenario=False)
    soak_parser.set_defaults(scenario="soak", callback=command_soak)

    ci_parser = subparsers.add_parser(
        "ci",
        help="run the same fast gate used by continuous integration",
    )
    ci_parser.set_defaults(callback=command_ci)

    mod = subparsers.add_parser("mod", help="validate, test, or package a mod")
    mod_commands = mod.add_subparsers(dest="mod_command", required=True)
    for name in ("validate", "test", "package"):
        child = mod_commands.add_parser(name)
        child.add_argument("path")
        if name == "package":
            child.add_argument("--output")
        child.set_defaults(callback=command_mod)
    return parser


def main() -> None:
    os.chdir(ROOT)
    args = build_parser().parse_args()
    result = args.callback(args)
    raise SystemExit(result or 0)


if __name__ == "__main__":
    main()
