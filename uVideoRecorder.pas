unit uVideoRecorder;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Generics.Collections, Generics.Collections,
  System.Variants, FireDAC.Phys.SQLite, FMX.DialogService, System.Permissions,
  FMX.Graphics,
  FireDAC.Stan.Async, FireDAC.Phys, FireDAC.DApt, FireDAC.Stan.Def, FMX.Media,
  System.IOUtils,
{$IFDEF ANDROID}
  Androidapi.Helpers,
  Androidapi.JNI.JavaTypes,
  Androidapi.JNI.Os,
  FireDAC.Stan.ExprFuncs, FireDAC.Phys.SQLiteWrapper.Stat,
  FireDAC.Phys.SQLiteDef, FireDAC.Stan.Intf,

{$ENDIF}
  FireDAC.FMXUI.Wait, Data.DB, FireDAC.Comp.Client;

const
{$IF DEFINED(ANDROID) OR DEFINED(IOS)}
  AUDIO_FILENAME = 'AUDIO.caf';
{$ELSE}
  AUDIO_FILENAME = 'AUDIO.wav';
{$ENDIF}

type
  TVideoManager = class
  private const
    PermissionCamera = 'android.permission.CAMERA';
    PermissionReadExternalStorage = 'android.permission.READ_EXTERNAL_STORAGE';
    PermissionWriteExternalStorage =
      'android.permission.WRITE_EXTERNAL_STORAGE';
    PermissionRecordAudio = 'android.permission.RECORD_AUDIO';

  var



    FMicrophone: TAudioCaptureDevice;
    Con: Tfdconnection;
    Q: Tfdquery;
    FDSQLiteSecurity1: TFDSQLiteSecurity;
    ChekPermisions: Boolean;
    MPlayerMicrafon: TMediaPlayer;

  public
    AUDIOPath: String; //
    mpxFilePath: String; // mpx dosyasýnýn tutulduðu tam dizin
    mpxFileName: string; // mpx dosya adý sadece
    FramePath: String; // Resimlerin tutulduðu tam dizin <dý
    PicList: TObjectList<TBitmap>;
    function CreateMpx: Boolean;
    function GetFrames: Boolean;
    function GetAUDIO: Boolean;
    function SaveAudioFile: Boolean;
    function ClearFrameCache: Boolean;
    function ClearFrameList: Boolean;
    function ClearSound: Boolean;
    function GetCameraPermission: Boolean;
    procedure TakePicturePermissionRequestResult(Sender: TObject;
      const APermissions: TArray<string>;
      const AGrantResults: TArray<TPermissionStatus>);
    procedure DisplayRationale(Sender: TObject;
      const APermissions: TArray<string>; const APostRationaleProc: TProc);
    function GetPath: string;
    function GetRecordPath: string;
    function PlayFromFile: Boolean;

    function HasMicrophone: Boolean;

    function CreateMicrafon: Boolean;
    function Createobjets: Boolean;
    function GetAudioFileName(const AFileName: string): string;
    procedure RequestPermissionsResult(Sender: TObject;
      const APermissions: TArray<string>;
      const AGrantResults: TArray<TPermissionStatus>);
    procedure StartMicrafonCapture;
    procedure StopMicrafonCapture;
    function IsMicrophoneRecording: Boolean;
    function PlaySound: Boolean;
    function StopSound: Boolean;
    function isActive: Boolean;
    function CaptureBitmap(bmp: TBitmap): Boolean;
  end;

implementation

{ TVideoManager }

function TVideoManager.CaptureBitmap(bmp: TBitmap): Boolean;
var
  pBmp: TBitmap;
begin
  try
    pBmp := TBitmap.Create;
    pBmp.Assign(bmp);
  finally
    PicList.Add(pBmp);
  end;
end;

function TVideoManager.isActive: Boolean;
begin
  if not(MPlayerMicrafon.State = TMediaState.Stopped) then
  begin
    Result := True;
  end;
end;

function TVideoManager.ClearFrameCache: Boolean;
begin
  PicList.Clear;
end;

function TVideoManager.ClearFrameList: Boolean;
begin
  PicList.Clear;
end;

function TVideoManager.ClearSound: Boolean;
begin
  if FileExists(AUDIOPath) then
    DeleteFile(AUDIOPath)
end;

function TVideoManager.CreateMicrafon: Boolean;
begin
  { get the microphone device }
  FMicrophone := TCaptureDeviceManager.Current.DefaultAudioCaptureDevice;
  if HasMicrophone then
  begin
    { and attempt to record to 'test.caf' file }
    AUDIOPath := GetAudioFileName(AUDIO_FILENAME);
    FMicrophone.FileName := AUDIOPath;
  end;
end;

function TVideoManager.CreateMpx: Boolean;
begin
  try
    with Con do
    begin
      Connected := False;
      Params.Clear;
      Params.DriverID := 'SQLite';
      Params.Database := mpxFilePath + mpxFileName;
      Connected := True;
    end;
  finally
    Q.Connection := Con;
    Q.SQL.Clear;
    Q.SQL.Text :=
      'create table IF NOT EXISTS  frames (sno integer , frame blob);';
    Q.ExecSQL;

    Q.SQL.Clear;
    Q.SQL.Text :=
      'create table IF NOT EXISTS  sounds (sno integer , soundf blob);';
    Q.ExecSQL;

    Q.SQL.Clear;
    Q.SQL.Text := 'delete from sounds  ;';
    Q.ExecSQL;

    Q.SQL.Clear;
    Q.SQL.Text := 'delete from frames  ;';
    Q.ExecSQL;
  end;

end;

function TVideoManager.Createobjets: Boolean;
begin
  Con := Tfdconnection.Create(nil);
  PicList := TObjectList<TBitmap>.Create;
  MPlayerMicrafon := TMediaPlayer.Create(nil);
  Q := Tfdquery.Create(nil);

end;

procedure TVideoManager.DisplayRationale(Sender: TObject;
  const APermissions: TArray<string>; const APostRationaleProc: TProc);
begin
  var
    RationaleMsg: string;
  for var I := 0 to High(APermissions) do
  begin
    if APermissions[I] = PermissionCamera then
      RationaleMsg := RationaleMsg +
        'The app needs to access the camera to take a photo' + SLineBreak +
        SLineBreak
    else if APermissions[I] = PermissionReadExternalStorage then
      RationaleMsg := RationaleMsg +
        'The app needs to read a photo file from your device'
    else if APermissions[I] = PermissionRecordAudio then
      RationaleMsg := RationaleMsg +
        'The app needs to read a photo file from your device';
  end;

  // Show an explanation to the user *asynchronously* - don't block this thread waiting for the user's response!
  // After the user sees the explanation, invoke the post-rationale routine to request the permissions
  TDialogService.ShowMessage(RationaleMsg,
    procedure(const AResult: TModalResult)
    begin
      APostRationaleProc;
    end)
end;

function TVideoManager.GetAudioFileName(const AFileName: string): string;
begin
{$IFDEF ANDROID}
  Result := TPath.GetTempPath + '/' + AFileName;
{$ELSE}
{$IFDEF IOS}
  Result := TPath.GetHomePath + '/Documents/' + AFileName;
{$ELSE}
  Result := TPath.Combine(TPath.GetTempPath, AFileName);
{$ENDIF}
{$ENDIF}
end;

function TVideoManager.GetCameraPermission: Boolean;
begin
  try
    PermissionsService.RequestPermissions
      ([PermissionCamera, PermissionReadExternalStorage,
      PermissionWriteExternalStorage, PermissionRecordAudio],
      TakePicturePermissionRequestResult, DisplayRationale);
  finally
    Result := True
  end;
end;

function TVideoManager.GetFrames: Boolean;
var
  fFrameCount, i: integer;
  oFld: TBlobField;
  actFrame: string;
  ms: TMemoryStream;
begin
  fFrameCount := 1;
  ms := TMemoryStream.Create;
  ms.Position := 0;
  actFrame := mpxFilePath + IntToStr(fFrameCount) + '.png';
  with Q do
  begin
    try
      SQL.Clear;
      SQL.Add('select * from frames');
      Open();
    finally
      for I := 0 to PicList.Count - 1 do
      begin
        PicList[i].SaveToStream(ms);
        ms.Position := 0;
        Insert;
        FieldByName('sno').Value := fFrameCount;
        oFld := TBlobField(FieldByName('frame'));
        oFld.LoadFromStream(ms);
        Post;
        ms.Clear;
        fFrameCount := fFrameCount + 1;
        actFrame := mpxFilePath + IntToStr(fFrameCount) + '.png';
      end;
    end;

  end;
  // ms.Free;
end;

function TVideoManager.GetAUDIO: Boolean;
var
  oFld: TBlobField;
  actFrame: string;
begin
  actFrame := AUDIOPath;
  Con.Close;
  con.Open();
  with Q do
  begin
    try
      SQL.Clear;
      SQL.Add('select * from sounds');
      Open();
    finally
      if FileExists(actFrame) then
      begin
        first;
        Insert;
        FieldByName('sno').Value := 1;
        oFld := TBlobField(FieldByName('soundf'));
        oFld.LoadFromFile(actFrame);
        Post;
      end;
    end;
  end;
  q.Close;
end;

function TVideoManager.GetPath: string;
begin
{$IFDEF ANDROID}
  Result := TPath.GetTempPath + '/';
{$ELSE}
{$IFDEF IOS}
  Result := TPath.GetHomePath + '/Documents/';
{$ELSE}
  Result := TPath.GetTempPath + PathDelim;
{$ENDIF}
{$ENDIF}
end;

function TVideoManager.GetRecordPath: string;
begin
  Result := GetPath + 'frames';
  if not DirectoryExists(Result) then
    CreateDir(Result);
  Result := Result + PathDelim;
end;

function TVideoManager.HasMicrophone: Boolean;
begin
  Result := Assigned(FMicrophone);
end;

function TVideoManager.IsMicrophoneRecording: Boolean;
begin
  Result := HasMicrophone and
    (FMicrophone.State = TCaptureDeviceState.Capturing);
end;

function TVideoManager.PlayFromFile: Boolean;
var
  ms: TMemoryStream;
  bm: TBitmap;
  oFld: TBlobField;
  k, i: Integer;
begin
  if FileExists(mpxFilePath + mpxFileName) then
  begin
    with Con do
    begin
      Connected := False;
      Params.Clear;
      Params.DriverID := 'SQLite';
      Params.Database := mpxFilePath + mpxFileName;
      Connected := True;
    end;
    Q.Connection := Con;
    with Q do
    begin
      // Get images
      try
        ms := TMemoryStream.Create;
        bm := TBitmap.Create;
        ms.Position := 0;
        SQL.Clear;
        SQL.Add('select * from frames');
        Open();
        PicList.Clear;
      finally
        first;
        PicList.Clear;
        k := Q.RecordCount;
        i := 0;
        for i := 0 to k do
        begin
          ms.Clear;
          ms.Position := 0;
          oFld := TBlobField(FieldByName('frame'));
          oFld.SaveToStream(ms);
          bm := TBitmap.Create;
          bm.LoadFromStream(ms);
          PicList.Add(bm);
          Next;
        end;
      end;
      // get audio file
      ms.Position := 0;
      SQL.Clear;
      SQL.Add('select * from frames');
      Open();
    end;
    SaveAudioFile;

  end;

end;

function TVideoManager.PlaySound: Boolean;
begin
  try
    AUDIOPath := GetAudioFileName(AUDIO_FILENAME);
    if IsMicrophoneRecording then
      StopMicrafonCapture;
    MPlayerMicrafon.FileName := FMicrophone.FileName;
  finally
    MPlayerMicrafon.Clear;
    MPlayerMicrafon.FileName := FMicrophone.FileName;
    MPlayerMicrafon.Play;
    Result := True;
  end;
end;

procedure TVideoManager.RequestPermissionsResult(Sender: TObject;
const APermissions: TArray<string>;
const AGrantResults: TArray<TPermissionStatus>);
begin
  if (Length(AGrantResults) = 1) then
  begin
    case AGrantResults[0] of
      TPermissionStatus.Granted:
        try
          FMicrophone.StartCapture;
        except
          TDialogService.ShowMessage
            ('StartCapture: Operation not supported by this device');
        end;
      TPermissionStatus.Denied:
        TDialogService.ShowMessage
          ('Cannot record sounds without the relevant permission being granted');
      TPermissionStatus.PermanentlyDenied:
        TDialogService.ShowMessage
          ('If you decide you wish to use the sounds recording feature of this app, please go to app settings and enable the microphone permission');
    end;
  end
  else
    TDialogService.ShowMessage
      ('Something went wrong with the permission checking');
end;

function TVideoManager.SaveAudioFile: Boolean;
var
  oFld: TBlobField;
  ms : TMemoryStream;
begin
  if StopSound then
  begin
    Con.Open;
    with Q do
    begin
      try
        MPlayerMicrafon.Clear;
        ms := TMemoryStream.Create;
        ms.Position := 0;
        SQL.Clear;
        SQL.Add('select * from sounds');
        Open();
        first;
        oFld := TBlobField(FieldByName('soundf'));
        oFld.SaveToStream(ms);
        ms.SaveToFile(AUDIOPath);
      finally
        q.Close;
        con.Close;
        ms.Free;
      end;
    end;
  end;
end;

procedure TVideoManager.StartMicrafonCapture;
begin
  if not IsMicrophoneRecording then
    FMicrophone.StartCapture;
end;

procedure TVideoManager.StopMicrafonCapture;
begin
  { stop capturing audio from the microphone }
  if IsMicrophoneRecording then
    try
      FMicrophone.StopCapture;
    except
      TDialogService.ShowMessage
        ('Get state: Operation not supported by this device');
    end;
end;

function TVideoManager.StopSound: Boolean;
begin
  try
    MPlayerMicrafon.Stop;
    MPlayerMicrafon.Clear;
  finally
    Result := True;
  end;
end;

procedure TVideoManager.TakePicturePermissionRequestResult(Sender: TObject;
const APermissions: TArray<string>;
const AGrantResults: TArray<TPermissionStatus>);
begin
  // 3 permissions involved: CAMERA, READ_EXTERNAL_STORAGE and WRITE_EXTERNAL_STORAGE
  if (Length(AGrantResults) = 4) and
    (AGrantResults[0] = TPermissionStatus.Granted) and
    (AGrantResults[1] = TPermissionStatus.Granted) and
    (AGrantResults[2] = TPermissionStatus.Granted) and
    (AGrantResults[3] = TPermissionStatus.Granted) then
  begin
    ChekPermisions := True
  end;
end;

end.
