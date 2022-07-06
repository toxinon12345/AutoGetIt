UNIT RegexProxy;

interface USES
  Generics.Collections,
  RegularExpressions, RegularExpressionsCore,
  Dialogs, Windows, Forms,  SysUtils, Classes, RTTI,
  Diagnostics, Win.Registry, StrUtils, IOUtils;

  function ExecuteProcess( const FileName, Params: string; Folder: string;
  WaitUntilTerminated, WaitUntilIdle, RunMinimized: boolean;    var ErrorCode: integer): boolean;
  procedure   DebugPrint( fmtString: String;   const Args: array of Const );
  function    range( Start: integer = 0; Stop: integer = 1; Step: integer = 1 ): TArray<Integer>;

TYPE
    TRegexGroupPath = record
      FKeys : TArray<string>;
      FVals : TArray<TGroup>;
    end;

   TreFlag = TRegExOption;
   //=====================
   TMyRegexProxy = record
    reEngine: TRegEx;
    rePattern: String;    reFlags: TRegexOptions;
    reSubject: String;
    //=====================
    RegexGroupPath : TRegexGroupPath ;

    currentMatch: TMatch ;
    currentGroup: TGroup ;

    constructor Open( pattern: String; flags: TRegexOptions );
    procedure ResolveMatches(SubjectString: String; GlobalSticky: integer = 2 );
  end;

   //=========================================================================================================

VAR
  MyRegexProxy1: TMyRegexProxy;

IMPLEMENTATION

function    range( Start: integer = 0; Stop: integer = 1; Step: integer = 1 ): TArray<Integer>;
begin
   var I, J, K : Integer;        var scala := Abs(Start - Stop) ;
   var Flag01 := (Start < Stop) AND (Step > 0) ;
   var Flag02 := (Start > Stop) AND (Step < 0) ;

  if      Flag01    then   begin    I := 0;  J := Scala-1;    K := 0;  end
  else if Flag02    then   begin    I := 0;  J := Scala-1;    K := 0;   end
  else                                             begin Exit end;

  While True do begin
      if not ( K in [I..J] ) then Break ;
    if (Flag01 = true) then begin      Result := Result + [Start + K];    end;
    if (Flag02 = true) then begin      Result := Result + [Start - K];    end;
      Inc(K, Abs(Step));
  End;
end;
//=================================================================================
constructor TMyRegexProxy.Open( pattern: String; flags: TRegexOptions );
begin
  self.reFlags := flags;    self.rePattern := pattern;
  self.reEngine := TRegEx.Create( self.repattern, self.reFlags );
end;
//=================================================================================
procedure TMyRegexProxy.ResolveMatches( SubjectString: String ; GlobalSticky: integer = 2 );  // Current Implementation
begin
   self.reSubject := SubjectString;
    Try
    //=================================================================================
      var I := 1 ;
      currentMatch := reEngine.Match( reSubject ) ;
      While  True do begin
        if not currentMatch.Success then break ;

          //=========================================================================================
        For var K in [1..currentMatch.Groups.Count-1]  do begin
          currentGroup := currentMatch.Groups[K] ;
          RegexGroupPath.FKeys := RegexGroupPath.FKeys + [ I.ToString +'|'+ K.ToString ]  ;
          RegexGroupPath.FVals := RegexGroupPath.FVals + [ currentMatch.Groups[K] ] ; ////
          //=========================================================================================
          DebugPrint( '%d_%d_%s', [ currentGroup.Index, currentGroup.Length, currentGroup.Value ] ) ;
        End;
          //======================================
        If          GlobalSticky = 1 then begin
          currentMatch := currentMatch.NextMatch() ;
        end else if GlobalSticky = 2 then begin
           var mOffset := currentMatch.Index + currentMatch.Length - 1 ;
          While True Do Begin
            mOffset := mOffset + 1 ;
            currentMatch := reEngine.Match( reSubject, mOffset ) ;
            if (currentMatch.Success = true) OR (mOffset > reSubject.Length) then break ;
          End;
           Inc(I);
        End;
      End;

      // if currentMatch.Success = False then
    Except
      on E: ERegularExpressionError do
        ShowMessage( 'ERegularExpressionError' );
    End;
end;
//===============================================================================================
procedure DebugPrint( fmtString: String;   const Args: array of Const );
begin
  var FormattedString : string := Format( fmtString, Args );
  OutputDebugString( PChar('DEBUG_PRINT >>> [ ' + FormattedString + ' ]' + ' <<< DEBUG_PRINT') );
end;

//========================================================================================================================

function ExecuteProcess(  const FileName, Params: string; Folder: string; WaitUntilTerminated, WaitUntilIdle, RunMinimized: boolean;
  var ErrorCode: integer): boolean;
var
  CmdLine: string;
  WorkingDirP: PChar;
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  LMarshaller: TMarshaller;
begin
  Result := true;
  CmdLine := '"' + Copy( FileName, 1, Length(FileName)-1) + '" ' + Params;
  if Folder = '' then Folder := ExcludeTrailingPathDelimiter(ExtractFilePath(FileName));
  ZeroMemory(@StartupInfo, SizeOf(StartupInfo));
  StartupInfo.cb := SizeOf(StartupInfo);
  if RunMinimized then
    begin
      StartupInfo.dwFlags := STARTF_USESHOWWINDOW;
      StartupInfo.wShowWindow := SW_SHOWMINIMIZED;
    end;
  if Folder <> '' then WorkingDirP := PChar(Folder)
  else WorkingDirP := nil;
  if not CreateProcess(nil, PChar(CmdLine), nil, nil, false, 0, nil, WorkingDirP, StartupInfo, ProcessInfo) then
    begin
      Result := false;
      ErrorCode := GetLastError;
      exit;
    end;
  with ProcessInfo do
    begin
      CloseHandle(hThread);
      if WaitUntilIdle then WaitForInputIdle(hProcess, INFINITE);
      if WaitUntilTerminated then
        repeat
          Application.ProcessMessages;
        until MsgWaitForMultipleObjects(1, hProcess, false, INFINITE, QS_ALLINPUT) <> WAIT_OBJECT_0 + 1;
      CloseHandle(hProcess);
    end;
end;

//========================================================================================================================


END.
