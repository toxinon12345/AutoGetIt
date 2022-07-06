unit ufrmAutoGetItMain;

interface  USES
  Generics.Collections, RegexProxy, RegularExpressions, RegularExpressionsCore,
  Winapi.CommCtrl,  Winapi.Windows, Winapi.Messages, System.SysUtils,
  System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, System.Actions, Vcl.ActnList,
  System.ImageList, Vcl.ImgList, Vcl.StdCtrls, Vcl.Buttons, Vcl.ExtCtrls,
  DosCommand, Vcl.CheckLst, Vcl.ComCtrls, Vcl.Menus, Vcl.Mask
  ;

TYPE
  TfrmAutoGetItMain = class(TForm)
    pnlTop: TPanel;
    btnRefresh: TBitBtn;
    aclAutoGetit: TActionList;
    actRefresh: TAction;
    cmbRADVersions: TComboBox;
    Label1: TLabel;
    DosCommand: TDosCommand;
    lbPackages: TCheckListBox;
    actInstallChecked: TAction;
    rgrpSortBy: TRadioGroup;
    chkInstalledOnly: TCheckBox;
    edtNameFilter: TLabeledEdit;
    StatusBar: TStatusBar;
    mnuCheckListPopup: TPopupMenu;
    actSaveCheckedList: TAction;
    actCheckAll: TAction;
    CheckAll1: TMenuItem;
    Savedcheckeditems1: TMenuItem;
    actUncheckAll: TAction;
    UncheckAll1: TMenuItem;
    N1: TMenuItem;
    InstallChecked1: TMenuItem;
    N2: TMenuItem;
    chkAcceptEULAs: TCheckBox;
    btnInstallSelected: TBitBtn;
    actUninstallChecked: TAction;
    UninstallChecked1: TMenuItem;
    FileOpenDialogSavedChecks: TFileOpenDialog;
    FileSaveDialogSavedChecks: TFileSaveDialog;
    actLoadCheckedList: TAction;
    dlgClearChecksFirst: TTaskDialog;
    actLoadCheckedList1: TMenuItem;
    actInstallOne: TAction;
    Installhighlightedpackage1: TMenuItem;
    actUninstallOne: TAction;
    Uninstallhighlightedpackage1: TMenuItem;
    Label2: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure DosCommandNewLine(ASender: TObject; const ANewLine: string; AOutputType: TOutputType);
    procedure DosCommandTerminated(Sender: TObject);
    procedure actRefreshExecute(Sender: TObject);
    procedure actInstallCheckedExecute(Sender: TObject);
    procedure actCheckAllExecute(Sender: TObject);
    procedure actUncheckAllExecute(Sender: TObject);
    procedure actUninstallCheckedExecute(Sender: TObject);
    procedure actSaveCheckedListExecute(Sender: TObject);
    procedure actLoadCheckedListExecute(Sender: TObject);
    procedure actInstallOneExecute(Sender: TObject);
    procedure actUninstallOneExecute(Sender: TObject);
    procedure lbPackagesClick(Sender: TObject);
    procedure rgrpSortByClick(Sender: TObject);
    procedure StatusBarDblClick(Sender: TObject);
    function GetPanelIndex( Point: TPoint ): Integer;
    procedure cmbRADVersionsSelect(Sender: TObject);
    function cmbParse() : integer;
  private
    type
      TGetItArgsFunction = reference to function (const GetItName: string): string;
    var
      FPastFirstItem: Boolean;
      FFinished: Boolean;
      FInstallAborted: Boolean;
    procedure SetExecLine(const Value: string);
    procedure SetDownloadTime(const Value: Integer);
    procedure SetPackageCount(const Value: Integer);
    procedure LoadRADVersionsCombo;
    procedure CleanPackageList;
    procedure ProcessCheckedPackages(GetItArgsFunc: TGetItArgsFunction);
    function BDSRootPath(const BDSVersion: string): string;
    function BDSBinDir: string;
    function GetItInstallCmd(const GetItPackageName: string): string;
    function GetItUninstallCmd(const GetItPackageName: string): string;
    function ParseGetItName(const GetItLine: string): string;
    function CountChecked: Integer;
    function SelectedBDSVersion: string;
    property PackageCount: Integer write SetPackageCount;
    property DownloadTime: Integer write SetDownloadTime;
    property ExecLine: string write SetExecLine;
  end;

VAR
  frmAutoGetItMain: TfrmAutoGetItMain;
  BDS_USER_ROOTS : string = '\Software\Embarcadero\BDS\';
  BDS_VERSIONSS : TArray<string> = ['19.0', '20.0', '21.0', '22.0'];
  DELPHI_NAMESS : TArray<string> = ['10.2 Tokyo', '10.3 Rio', '10.4 Sydney', '11 Alexandria'];
  switch_dispatch : Integer = 0;
  //================================================
  MyReProxy1 : TMyRegexProxy;
  MyReProxy2 : TMyRegexProxy;
  myRePattern : string = 'BDS ([^\x20]+) | Delphi ([^\x20]+) (\w+)';
  myRePattern2 : string = '@SET ([^\x20]+)=(.*)';
  getItUrl : string = 'https://getit.embarcadero.com';
  // getItUrl : string = 'https://getit-104.embarcadero.com';


implementation USES
  UEnvVars,
  Diagnostics, Win.Registry, StrUtils, IOUtils,
  ufrmInstallLog;

{$R *.dfm}

CONST
  GETIT_VR_NOT_SUPPORTED_MSG = 'This version of Delphi''s GetItCmd.exe is not supported.';
//===================================================================================================
procedure TfrmAutoGetItMain.FORMCREATE(Sender: TObject);
begin
  LoadRADVersionsCombo;
  lbPackages.Items.Clear;

  var AutoGetItDir := GetCurrentDir();
    var FilePaths := ['','',''] ;
    FilePaths[0] := TPath.Combine( AutoGetItDir, 'rsvars.bat' ) ;
    FilePaths[1] := TPath.Combine( BDSBinDir, 'rsvars.bat' ) ;

  If FileExists( FilePaths[0] ) Then FilePaths[2] := FilePaths[0]  else FilePaths[2] := FilePaths[1] ;

    {$REGION 'ENV_VARS'}
      var myStringList := TStringList.Create ;      myStringList.LoadFromFile( FilePaths[2], TEncoding.UTF8 ) ;
      MyReProxy2.Open( myRePattern2, [roIgnoreCase] );
      MyReProxy2.ResolveMatches( myStringList.Text );

      For var I in Range(0,Length(MyReProxy2.RegexGroupPath.FVals),2) Do begin
        var EnvName  := MyReProxy2.RegexGroupPath.FVals[I+0].Value ;
        var EnvValue := MyReProxy2.RegexGroupPath.FVals[I+1].Value ;
        SetEnvVarValue( EnvName, ExpandEnvVars(EnvValue) );
      End;
    {$ENDREGION}

   var reg := TRegistry.Create;
    try
      reg.RootKey := HKEY_CURRENT_USER;
      var SubKey := BDS_USER_ROOTS + SelectedBDSVersion() + '\CatalogRepository';
      var KeyExists := reg.OpenKey( SubKey, False);
      var serviceKind := reg.ReadString('ServiceKind');

      if      KeyExists and (serviceKind = 'Online')  then
        StatusBar.Panels[3].Text := reg.ReadString('ServiceUrl')
      else if KeyExists and (serviceKind = 'Offline') then
        StatusBar.Panels[3].Text :=  reg.ReadString('ServicePath') ;
    finally
      reg.Free;
    end;

end;
//===================================================================================================
function TfrmAutoGetItMain.GetItInstallCmd(const GetItPackageName: string): string;
begin

  case cmbParse() of
    1: Result := Format('-accept_eulas -i"%s"', [GetItPackageName]) ;
    2: Result := Format('-ae -i="%s"', [GetItPackageName]) ;
    3: Result := Format('-ae -i="%s"', [GetItPackageName]) ;
  else
    raise ENotImplemented.Create(GETIT_VR_NOT_SUPPORTED_MSG);
  end;

end;
//===================================================================================================
function TfrmAutoGetItMain.GetItUninstallCmd(const GetItPackageName: string): string;
begin

  case cmbParse() of
    1: Result := Format('-u"%s"', [GetItPackageName])  ;
    2: Result := Format('-u="%s"', [GetItPackageName]) ;
    3: Result := Format('-u="%s"', [GetItPackageName]) ;
  else
    raise ENotImplemented.Create(GETIT_VR_NOT_SUPPORTED_MSG);
  end;

end;
//===================================================================================================
procedure TfrmAutoGetItMain.lbPackagesClick(Sender: TObject);
begin
  actInstallOne.Enabled := (lbPackages.ItemIndex > -1) and (lbPackages.ItemIndex < lbPackages.Items.Count);
  actUninstallOne.Enabled := (lbPackages.ItemIndex > -1) and (lbPackages.ItemIndex < lbPackages.Items.Count);

  if actInstallOne.Enabled then begin
    actInstallOne.Caption := 'Install ' + ParseGetItName(lbPackages.Items[lbPackages.ItemIndex]);
    actUninstallOne.Caption := 'Uninstall ' + ParseGetItName(lbPackages.Items[lbPackages.ItemIndex]);
  end else begin
    actInstallOne.Caption := 'Install ...';
    actUninstallOne.Caption := 'Uninstall ...';
  end;
end;
//===================================================================================================
procedure TfrmAutoGetItMain.actInstallCheckedExecute(Sender: TObject);
begin
  actInstallChecked.Enabled := False;
  actRefresh.Enabled := False;
  try
    ProcessCheckedPackages(function (const GetItName: string): string
        begin
          Result := GetItInstallCmd(GetItName);
        end);
  finally
    actInstallChecked.Enabled := True;
    actRefresh.Enabled := True;
  end;
end;
//===================================================================================================
procedure TfrmAutoGetItMain.actUninstallCheckedExecute(Sender: TObject);
begin
  actUninstallChecked.Enabled := False;
  actRefresh.Enabled := False;
  try
    ProcessCheckedPackages(function (const GetItName: string): string
        begin
          Result := GetItUninstallCmd(GetItName);
        end);
  finally
    actUninstallChecked.Enabled := True;
    actRefresh.Enabled := True;
  end;
end;
//===================================================================================================
procedure TfrmAutoGetItMain.actInstallOneExecute(Sender: TObject);
begin
  actInstallOne.Enabled := False;
  actRefresh.Enabled := False;
  try
    frmInstallLog.Initialize;
    frmInstallLog.ProcessGetItPackage(BDSBinDir,
               GetItInstallCmd(ParseGetItName(lbPackages.Items[lbPackages.ItemIndex])),
               1, 1, FInstallAborted);

    frmInstallLog.NotifyFinished;
  finally
    actInstallOne.Enabled := True;
    actRefresh.Enabled := True;
  end;
end;
//===================================================================================================
procedure TfrmAutoGetItMain.actUninstallOneExecute(Sender: TObject);
begin
  actUninstallOne.Enabled := False;
  actRefresh.Enabled := False;
  try
    frmInstallLog.Initialize;
    frmInstallLog.ProcessGetItPackage(BDSBinDir,
                       GetItUninstallCmd(ParseGetItName(lbPackages.Items[lbPackages.ItemIndex])),
                       1, 1, FInstallAborted);
    frmInstallLog.NotifyFinished;
  finally
    actUninstallOne.Enabled := True;
    actRefresh.Enabled := True;
  end;
end;
//===================================================================================================
procedure TfrmAutoGetItMain.actRefreshExecute(Sender: TObject);
begin
  var SortField: string;
  var CmdLineArgs: string;
  actRefresh.Enabled := False;
  try
    lbPackages.Items.Clear;
    FPastFirstItem := False;
    FFinished := False;

    case rgrpSortBy.ItemIndex of
      0: SortField := 'name';
      1: SortField := 'vendor';
      2: SortField := 'date';
    end;

    DosCommand.CurrentDir := BDSBinDir();

     var Filter := IfThen(chkInstalledOnly.Checked, 'Installed', 'All') ;
    case cmbParse() of
      1: CmdLineArgs := Format( '-listavailable:%s -sort:%s -filter:%s ', [edtNameFilter.Text, SortField, Filter] ) ;
      2: CmdLineArgs := Format( '--list=%s --sort=%s --filter=%s', [edtNameFilter.Text, SortField, Filter] ) ;
      3: CmdLineArgs := Format( '--list=%s --sort=%s --filter=%s', [edtNameFilter.Text, SortField, Filter] ) ;
      else
        raise ENotImplemented.Create(GETIT_VR_NOT_SUPPORTED_MSG);
    end;

    DosCommand.CommandLine := 'GetItCmd.exe ' + CmdLineArgs;
    ExecLine := DosCommand.CommandLine;

    Screen.Cursor := crHourGlass;
    try
      var CmdTime := TStopWatch.Create;
      CmdTime.Start;

      DosCommand.Execute;
      Repeat
        Application.ProcessMessages;
      until FFinished;
      CleanPackageList;

      CmdTime.Stop;
      DownloadTime := cmdTime.Elapsed.Seconds;
      PackageCount := lbPackages.Items.Count;
    finally
      Screen.Cursor := crDefault;
    end;

    actInstallChecked.Enabled := lbPackages.Items.Count > 0;
    actUninstallChecked.Enabled := lbPackages.Items.Count > 0;
  finally
    actRefresh.Enabled := True;
  end;
end;
//===================================================================================================
procedure TfrmAutoGetItMain.actSaveCheckedListExecute(Sender: TObject);
begin
  var CheckedList := TStringList.Create;
  try
    for var i in [0 .. lbPackages.Count - 1] do
      if lbPackages.Checked[i] then begin
        var GetItName := ParseGetItName(lbPackages.Items[i]);
        CheckedList.Add(GetItName);
      end;

    FileSaveDialogSavedChecks.FileName := 'AutoGetIt for RAD Studio ' + cmbRADVersions.Text;
    if FileSaveDialogSavedChecks.Execute then
      CheckedList.SaveToFile(FileSaveDialogSavedChecks.FileName);
  finally
    CheckedList.Free;
  end;
end;
//===================================================================================================
procedure TfrmAutoGetItMain.actLoadCheckedListExecute(Sender: TObject);
begin
  var CheckedList := TStringList.Create;
  try
    FileOpenDialogSavedChecks.FileName := 'AutoGetIt for RAD Studio ' + cmbRADVersions.Text;
    if FileOpenDialogSavedChecks.Execute then begin
      CheckedList.LoadFromFile(FileOpenDialogSavedChecks.FileName);

      if CountChecked > 0 then begin
        if dlgClearChecksFirst.Execute then
          case dlgClearChecksFirst.ModalResult of
            mrCancel:
              Exit;
            mrYes:
              actUncheckAll.Execute;
          end;
      end;

      for var i in [0 .. CheckedList.Count - 1] do begin
        for var GetItPos in [0 .. lbPackages.Items.Count - 1] do
          if StartsText(CheckedList[i], lbPackages.Items[GetItPos]) then
            lbPackages.Checked[GetItPos] := True;
      end;
    end;
  finally
    CheckedList.Free;
  end;
end;
//===================================================================================================
procedure TfrmAutoGetItMain.actCheckAllExecute(Sender: TObject);
begin
  lbPackages.CheckAll(TCheckBoxState.cbChecked);
end;
//===================================================================================================
procedure TfrmAutoGetItMain.actUncheckAllExecute(Sender: TObject);
begin
  lbPackages.CheckAll(TCheckBoxState.cbUnchecked);
end;
//===================================================================================================
function TfrmAutoGetItMain.BDSBinDir: string;
begin
  Result := TPath.Combine( BDSRootPath( SelectedBDSVersion() ), 'bin');
end;
//===================================================================================================
function TfrmAutoGetItMain.BDSRootPath(const BDSVersion: string): string;
begin
  var reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_CURRENT_USER;

    if reg.OpenKey(BDS_USER_ROOTS + BDSVersion, False) then
      Result := reg.ReadString('RootDir');
  finally
    reg.Free;
  end;
end;
//===================================================================================================
procedure TfrmAutoGetItMain.CleanPackageList;
{ Not sure if there's a bug in DosCommand or what but the list of packages
  often contains cut-off entries that are then completed on the next line,
  like it misinterpreted a line break, so this routine goes through and
  deletes those partial entries by checking to see if the previous line
  is the start of the current line.
}
begin
  var LastPackage := EmptyStr;
  For var I in Range(lbPackages.Count-1, 0, -1) do begin    // Checkpoint
    LastPackage := lbPackages.Items[I-1];

    if (LastPackage.Length > 0) and StartsText(LastPackage, lbPackages.Items[i]) then
      lbPackages.Items.Delete(i - 1)
    else
  end;
end;
//===================================================================================================
function TfrmAutoGetItMain.cmbParse() : integer;
begin
    var switch_dispatch : Integer ;
    MyReProxy1.Open( myRePattern, [roIgnoreCase] );
    MyReProxy1.ResolveMatches( cmbRADVersions.Text );

    var version := TArray<TGroup>( MyReProxy1.RegexGroupPath.FVals)[0] ;
    if version.Value = '19.0' then switch_dispatch := 1;   // BDS 19 | Delphi 10.2 Tokyo
    if version.Value = '20.0' then switch_dispatch := 1;   // BDS 20 | Delphi 10.3 Rio
    if version.Value = '21.0' then switch_dispatch := 2;   // BDS 21 | Delphi 10.4 Sydney
    if version.Value = '22.0' then switch_dispatch := 3;   // BDS 22 | Delphi 11.0 Alexandria

    Result := switch_dispatch ;
end;
//===================================================================================================
procedure TfrmAutoGetItMain.cmbRADVersionsSelect(Sender: TObject);
begin

end;
//===================================================================================================
function TfrmAutoGetItMain.CountChecked: Integer;
begin
  Result := 0;
  for var i in [0 .. lbPackages.Count - 1] do
    if lbPackages.Checked[i] then
      Result := Result + 1;
end;

procedure TfrmAutoGetItMain.DosCommandNewLine( ASender: TObject; const ANewLine: string; AOutputType: TOutputType );
begin
  if not FPastFirstItem then begin
    if StartsText('--', ANewLine) then
      FPastFirstItem := True;
  end else if ContainsText(ANewLine, 'command finished') then
    FFinished := True
  else if not FFinished and (Trim(ANewLine).Length > 0) then
    if lbPackages.Items.IndexOf(ANewLine) = -1 then
      lbPackages.Items.Add(ANewLine);
end;
//===================================================================================================
procedure TfrmAutoGetItMain.DosCommandTerminated(Sender: TObject);
begin
  FFinished := True;
end;
//===================================================================================================
procedure TfrmAutoGetItMain.LoadRADVersionsCombo;
begin
  cmbRADVersions.Items.Clear;

  var reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_CURRENT_USER;

    // find and list all versions of RAD studio installed
    for var i in [1 .. Length(BDS_VERSIONSS) ] do
      if reg.OpenKey(BDS_USER_ROOTS + BDS_VERSIONSS[i], False) then begin
        // make sure a root path is listed before adding this version
        if Length(BDSRootPath(BDS_VERSIONSS[i])) > 0 then
          cmbRADVersions.Items.Insert(0, 'BDS ' + BDS_VERSIONSS[i] + ' | Delphi ' + DELPHI_NAMESS[i]);
      end;

    if cmbRADVersions.Items.Count > 0 then
      cmbRADVersions.ItemIndex := 0
    else begin
      cmbRADVersions.Style := TComboBoxStyle.csSimple;
      cmbRADVersions.Text := '<None Found>';
      cmbRADVersions.Enabled := False;
    end;
  finally
    reg.Free;
  end;
end;
//===================================================================================================
function TfrmAutoGetItMain.ParseGetItName(const GetItLine: string): string;
begin
  var space := Pos(' ', GetItLine);
  Result := LeftStr(GetItLine, space - 1);
end;
//===================================================================================================
procedure TfrmAutoGetItMain.ProcessCheckedPackages(GetItArgsFunc: TGetItArgsFunction);
begin
  FInstallAborted := False;
  var total := CountChecked;
  var count := 0;
  frmInstallLog.Initialize;
  for var i in [0 .. lbPackages.Count - 1] do begin
    if lbPackages.Checked[i] then begin
      var GetItLine := lbPackages.Items[i];
      var GetItName := ParseGetItName(GetItLine);

      Inc(count);
      frmInstallLog.ProcessGetItPackage(BDSBinDir, GetItArgsFunc(GetItName),
                                        Count, Total, FInstallAborted)
    end;

    if FInstallAborted then
      Break;
  end;
  frmInstallLog.NotifyFinished;
end;
//===================================================================================================
procedure TfrmAutoGetItMain.rgrpSortByClick(Sender: TObject);
begin
  case cmbParse() of
    1:  if (rgrpSortBy.ItemIndex = 2) then  begin
          rgrpSortBy.ItemIndex := 0;
          ShowMessage('Sorting by Date not available with GetItCmd for RAD Studio 19 or 20') ;
        end
  end;
end;
//===================================================================================================
function TfrmAutoGetItMain.SelectedBDSVersion: string;
begin
  cmbParse() ;
  var version := MyReProxy1.RegexGroupPath.FVals[0] ;
  DebugPrint( '%s',  [ version.Value ] );
  Result := version.Value;
end;
//===================================================================================================
procedure TfrmAutoGetItMain.SetDownloadTime(const Value: Integer);
begin
  StatusBar.Panels[1].Text := Format('%d seconds', [Value]);
  StatusBar.Update;
end;
//===================================================================================================
procedure TfrmAutoGetItMain.SetExecLine(const Value: string);
begin
  StatusBar.Panels[2].Text := Value;
  StatusBar.Update;
end;
//===================================================================================================
procedure TfrmAutoGetItMain.SetPackageCount(const Value: Integer);
begin
  StatusBar.Panels[0].Text := Format('%d packages', [Value]);
  StatusBar.Update;
end;
//===================================================================================================
procedure TfrmAutoGetItMain.StatusBarDblClick(Sender: TObject);
begin
  var LClickPos := SmallPointToPoint(TSmallPoint(GetMessagePos()));
  LClickPos := StatusBar.ScreenToClient(LClickPos);
  var LIndex := GetPanelIndex(LClickPos);

  var Comspec : string := ExpandEnvVars( '%windir%\system32\cmd.exe' );       var ErrorCode: Integer;
  if 2 = LIndex then ExecuteProcess( Comspec , '/K title RADStudio', '', false, false, false, ErrorCode);
  if 3 = LIndex then begin
       var reg := TRegistry.Create;
        try
          reg.RootKey := HKEY_CURRENT_USER;
          var SubKey := BDS_USER_ROOTS + SelectedBDSVersion() + '\CatalogRepository';
          var KeyExists := reg.OpenKey( SubKey, False);
          var serviceKind := reg.ReadString('ServiceKind');
          if KeyExists and (serviceKind = 'Online') then begin
            StatusBar.Panels[3].Text := reg.ReadString('ServicePath');
            DosCommand.CommandLine := 'GetItCmd.exe --config=useoffline';
          end else if KeyExists and (serviceKind = 'Offline') then begin
            StatusBar.Panels[3].Text :=  reg.ReadString('ServiceUrl');
            DosCommand.CommandLine := 'GetItCmd.exe --config=useonline';
          end;
          DosCommand.Execute();
          ExecLine := DosCommand.CommandLine;
        finally
          reg.Free;
        end;
  end;
end;

//=========================================================================================================================

function  TfrmAutoGetItMain.GetPanelIndex( Point: TPoint ): Integer;
begin
  var LRect: TRect;
  For var I in [0 .. StatusBar.Panels.Count - 1] do    begin
    if 0 <> SendMessage(StatusBar.Handle, SB_GETRECT, I, LPARAM(@LRect))  then begin
      if PtInRect(LRect, Point) then
        Exit(I);
    end;
  End;

  Result := -1;
end;


END.
