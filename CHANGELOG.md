# Changelog

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
