program DelphiCompiler;

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.SysUtils,
  System.Diagnostics,
  Compilar.Types in 'Compilar.Types.pas',
  Compilar.Args in 'Compilar.Args.pas',
  Compilar.Config in 'Compilar.Config.pas',
  Compilar.PathUtils in 'Compilar.PathUtils.pas',
  Compilar.MSBuild in 'Compilar.MSBuild.pas',
  Compilar.Parser in 'Compilar.Parser.pas',
  Compilar.Lookup in 'Compilar.Lookup.pas',
  Compilar.Context in 'Compilar.Context.pas',
  Compilar.ProjectInfo in 'Compilar.ProjectInfo.pas',
  Compilar.Output in 'Compilar.Output.pas',
  Compilar.BuildEvents in 'Compilar.BuildEvents.pas';

  procedure WriteStdout(const S: string);
  var
    Bytes: TBytes;
    Handle: THandle;
    Written: DWORD;
  begin
    Handle := GetStdHandle(STD_OUTPUT_HANDLE);
    Bytes := TEncoding.UTF8.GetBytes(S + sLineBreak);
    WriteFile(Handle, Bytes[0], Length(Bytes), Written, nil);
  end;

  procedure WriteStderr(const S: string);
  var
    Bytes: TBytes;
    Handle: THandle;
    Written: DWORD;
  begin
    Handle := GetStdHandle(STD_ERROR_HANDLE);
    Bytes := TEncoding.UTF8.GetBytes(S + sLineBreak);
    WriteFile(Handle, Bytes[0], Length(Bytes), Written, nil);
  end;

var
  Args: TCompilerArgs;
  ParseError: string;
  MSBuildOutput: string;
  MSBuildExitCode: Integer;
  Issues: TArray<TCompileIssue>;
  Result: TCompileResult;
  Truncated: Boolean;
  TotalIssuesFound: Integer;
  SW: TStopwatch;
  CompileStartTime: TDateTime;
  OutputWinPath: string;
  OutputFileTime: TDateTime;
  LPreBuildCmd: string;
  LPostBuildCmd: string;
  LProjectDir: string;
  LEventResult: TBuildEventInfo;
begin

  try
    // 1. Parse command line arguments
    if not TArgsParser.Parse(Args, ParseError) then
    begin
      WriteStdout(TJSONOutput.Invalid(ParseError));
      ExitCode := 0;
      Exit;
    end;

    // 2. Initialize config (env file, env vars, auto-detection)
    InitConfig(Args.ProjectPathWin, Args.WSLMode);

    // 2b. Parse and run pre-build event
    LProjectDir := ExtractFilePath(Args.ProjectPathWin);
    LPreBuildCmd := TBuildEvents.GetPreBuildEvent(
      Args.ProjectPathWin, Args.ConfigStr, Args.PlatformStr);
    LPostBuildCmd := TBuildEvents.GetPostBuildEvent(
      Args.ProjectPathWin, Args.ConfigStr, Args.PlatformStr);

    if not LPreBuildCmd.IsEmpty then
    begin
      LEventResult := TBuildEvents.Execute(LPreBuildCmd, LProjectDir);
      if not LEventResult.Success then
      begin
        WriteStdout(TJSONOutput.BuildEventError('prebuild', Args, LEventResult));
        ExitCode := 0;
        Exit;
      end;
    end;

    // 3. Run MSBuild (with timing)
    CompileStartTime := Now;
    SW := TStopwatch.StartNew;

    if not TMSBuildRunner.Execute(Args, MSBuildOutput, MSBuildExitCode) then
    begin
      WriteStdout(TJSONOutput.InternalError('MSBuild execution failed'));
      ExitCode := 0;
      Exit;
    end;

    SW.Stop;

    // 3b. Echo raw output if requested
    if Args.RawOutput then
    begin
      WriteStderr('--- MSBuild Raw Output (ExitCode=' + IntToStr(MSBuildExitCode) + ', Len=' + IntToStr(Length(MSBuildOutput)) + ') ---');
      WriteStderr(MSBuildOutput);
      WriteStderr('--- End Raw Output ---');
    end;

    // 4. Parse MSBuild output (with truncation tracking)
    Issues := TOutputParser.Parse(MSBuildOutput, Args.MaxErrors, Truncated, TotalIssuesFound);

    // 5. Enrich issues with context and lookup
    TContextEnricher.AddSourceContext(Issues, Args.ContextLines);
    TLookupEnricher.AddLookup(Issues);

    // 6. Build result
    Result := TCompileResult.Create(Args, Issues, MSBuildExitCode, Truncated, TotalIssuesFound);
    Result.ProjectPath := TPathUtils.NormalizeForOutput(Args.ProjectPathWin);
    Result.TimeMs := SW.ElapsedMilliseconds;

    // 7. Resolve output binary path (MSBuild output is authoritative, dproj is fallback)
    Result.OutputPath := TProjectInfo.GetOutputFromMSBuild(MSBuildOutput, Args);
    if Result.OutputPath = '' then
      Result.OutputPath := TProjectInfo.GetOutputPath(Args);

    // 7b. Verify output was actually produced by this compilation (not a stale file)
    if Result.OutputPath <> '' then
    begin
      OutputWinPath := TPathUtils.NormalizeToWindows(Result.OutputPath);
      if FileAge(OutputWinPath, OutputFileTime) then
      begin
        if OutputFileTime < CompileStartTime then
        begin
          Result.OutputStale := True;
          Result.OutputMessage := 'Compilation succeeded but the output file was NOT updated (locked by another process). Restart the application and recompile.';
          // Override status: compilation was fine, the problem is the locked output
          if Result.ErrorCount = 0 then
            Result.Status := 'output_locked';
        end;
      end;
    end;

    // 7c. Store PreBuild event info
    if not LPreBuildCmd.IsEmpty then
      Result.PreBuildEvent := LEventResult;

    // 7d. Run PostBuild event (only if compilation succeeded)
    if (not LPostBuildCmd.IsEmpty) and (Result.ErrorCount = 0) then
    begin
      LEventResult := TBuildEvents.Execute(LPostBuildCmd, LProjectDir);
      Result.PostBuildEvent := LEventResult;
    end;

    // 8. Output JSON
    WriteStdout(TJSONOutput.Generate(Result));
    ExitCode := 0;

  except
    on E: Exception do
    begin
      WriteStdout(TJSONOutput.InternalError(E.Message));
      ExitCode := 0;
    end;
  end;
end.
