# Changelog

## v1.5 - 2026-04-20

- Fix mixed-slash Windows path handling in argument parser (`Compilar.Args.pas`)
- Paths like `W:/folder/file.dproj` (forward slashes with drive letter) now normalize correctly: `ProjectPathWin` gets backslashes and `ProjectPath` derives from the fixed form
- Previously `IsWindowsPath` required `Path[3] = '\'`, so mixed-slash inputs fell through to the else branch and both paths were stored malformed

## v1.4 - 2026-03-13

- Add PreBuild/PostBuild event support (contributed by [ertang](https://en.delphipraxis.net/))
  - Parses `<PreBuildEvent>` and `<PostBuildEvent>` from `.dproj` PropertyGroups
  - Executes pre-build before MSBuild; aborts with `prebuild_error` status on failure
  - Executes post-build after MSBuild only if compilation succeeded
  - MSBuild native events suppressed via `/p:PreBuildEvent= /p:PostBuildEvent=` to avoid double execution
  - PropertyGroup condition matching with priority: Config+Platform > Config > Base+Platform > Base
  - Build event results included in JSON output (`pre_build_event`, `post_build_event` fields)
- New unit: `Compilar.BuildEvents.pas`
- Fixes applied during integration:
  - Initialize `TBuildEventInfo.Executed` to `False` in `TCompileResult.Create` (prevents garbage JSON for projects without build events)
  - Temp `.bat` cleanup in `finally` block (was leaked on `CreateProcess` failure)
  - Unique temp `.bat` filename using PID (prevents corruption under concurrent compilation)
  - Multi-line events joined with line breaks instead of `&&` (preserves MSBuild semantics)
  - Pre-build event output included in JSON (was silently dropped)

## v1.3 - 2026-03-04

- Fix Unicode/codepage failures when running under WSL
- MSBuild pipe output now uses explicit OEM→Unicode conversion (`MultiByteToWideChar` with `CP_OEMCP`) instead of implicit `AnsiString` cast that depended on process codepage
- Replace `WriteLn` with explicit UTF-8 `WriteFile` for stdout/stderr to avoid codepage mismatch exceptions
- Source context extraction now always uses UTF-8 encoding instead of ANSI (which fails under WSL)
- Escape non-ASCII characters in JSON output (`Ord(C) > 127`) to ensure valid JSON regardless of terminal encoding
- Broaden compiler message regex to accept any file extension (was limited to `.pas/.dpr/.dpk/.inc`)
- Add try-except around source context reading to gracefully skip files with encoding issues

## v1.2 - 2026-02-19

- Switch delphi-lookup integration from text parsing to JSON (`--json` flag)
- Replaces fragile regex parsing of verbose text format, which broke with delphi-lookup v1.3.0 compact default
- Now extracts `unit`, `file`, `type`, `line` directly from structured JSON fields

## v1.1 - 2026-02-18

- Add `output_locked` status when compilation succeeds but BPL/EXE is locked by another process
- Previously `status: "ok"` + `exit_code: 1` were contradictory signals; now `status: "output_locked"` disambiguates
- Preserve `OutputPath` in JSON when output is stale (was being cleared to empty)
- `OutputMessage` is now a record field instead of a hardcoded string

## v1.0 - 2026-02-16

- Initial release: Delphi compilation wrapper with JSON output
- MSBuild invocation with configurable Debug/Release and Win32/Win64
- Compiler output parsing (errors, warnings, hints)
- Source code context extraction around errors
- Symbol lookup integration for undeclared identifiers
- Output staleness detection
