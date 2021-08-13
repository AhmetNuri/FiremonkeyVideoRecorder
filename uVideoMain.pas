unit uVideoMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Variants, FMX.Platform, Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.TabControl,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Media, FMX.Objects,
  uVideoRecorder, FMX.Memo.Types, FMX.ScrollBox, FMX.Memo;

type
  TForm2 = class(TForm)
    TabControl1: TTabControl;
    ToolBar1: TToolBar;
    tiCapture: TTabItem;
    Camera: TCameraComponent;
    imgCameraView: TImage;
    btnRecord: TButton;
    TimerCreate: TTimer;
    btnPlay: TButton;
    TimerCapture: TTimer;
    TimerPlayer: TTimer;
    btnMakeVideo: TButton;
    btnPlayFromFile: TButton;
    OpenDialog1: TOpenDialog;
    procedure CameraSampleBufferReady(Sender: TObject; const ATime: TMediaTime);
    procedure btnRecordClick(Sender: TObject);
    procedure TimerCreateTimer(Sender: TObject);
    function AppEvent(AAppEvent: TApplicationEvent; AContext: TObject): Boolean;
    procedure btnPlayClick(Sender: TObject);
    procedure TimerCaptureTimer(Sender: TObject);
    procedure TimerPlayerTimer(Sender: TObject);
    function RecorderStart: Boolean;
    function RecorderStop: Boolean;
    function playerStart: Boolean;
    function playerStop: Boolean;
    procedure FormShow(Sender: TObject);
    procedure btnMakeVideoClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure btnPlayFromFileClick(Sender: TObject);
  private
    { Private declarations }
    fFrameCount: integer;
    procedure DisplayCameraPreviewFrame;

  public
    { Public declarations }
  end;

var
  Form2: TForm2;
  VideoManager: TVideoManager;
  fPlayerFrameCount: integer;
  lbFcount: String;
  bmp: TBitmap;

implementation

{$R *.fmx}

function TForm2.AppEvent(AAppEvent: TApplicationEvent;
  AContext: TObject): Boolean;
begin
  case AAppEvent of
    TApplicationEvent.WillBecomeInactive, TApplicationEvent.EnteredBackground,
      TApplicationEvent.WillTerminate:
      begin
        Result := True;
      end;
  end;
end;

procedure TForm2.btnRecordClick(Sender: TObject);
begin
  if Camera.Active then
  begin
    Camera.Active := False;
    RecorderStop
  end
  else
  begin
    try
      playerStop;
    finally
      RecorderStart;
    end;
  end;
end;

procedure TForm2.Button1Click(Sender: TObject);
begin
  fPlayerFrameCount := 1;
  VideoManager.PlayFromFile;
  TimerPlayer.Enabled := True;
end;

procedure TForm2.btnMakeVideoClick(Sender: TObject);
begin
  VideoManager.CreateMpx;
  VideoManager.GetFrames;
  VideoManager.GetAUDIO;
end;

procedure TForm2.btnPlayClick(Sender: TObject);
begin
  if not(VideoManager.isActive) or (TimerPlayer.Enabled) or
    (TimerCapture.Enabled) then
  begin
    try
      RecorderStop;
    finally
      playerStop;
    end;
  end
  else
  begin
    playerStart
  end;
end;

procedure TForm2.btnPlayFromFileClick(Sender: TObject);
begin
  try
{$IFDEF MSWINDOWS}
    if OpenDialog1.Execute then
      if FileExists(OpenDialog1.FileName) then
      begin
        VideoManager.mpxFilePath := OpenDialog1.FileName;
        VideoManager.mpxFileName := '';
      end;
{$ENDIF}
    RecorderStop;
    TabControl1.ActiveTab := tiCapture;
    VideoManager.PlayFromFile;
  finally
    btnPlayClick(Self);
  end;
end;

procedure TForm2.CameraSampleBufferReady(Sender: TObject;
  const ATime: TMediaTime);
begin
  TThread.Synchronize(TThread.CurrentThread, DisplayCameraPreviewFrame);
end;

procedure TForm2.DisplayCameraPreviewFrame;
begin
  Camera.SampleBufferToBitmap(imgCameraView.Bitmap, True);
end;

procedure TForm2.FormShow(Sender: TObject);
begin
  TimerCreate.Enabled := True;
end;

function TForm2.playerStart: Boolean;
begin
  VideoManager.PlaySound;
  fPlayerFrameCount := 1;
  TimerPlayer.Enabled := True;
  Result := True;
end;

function TForm2.playerStop: Boolean;
begin
  VideoManager.StopSound;
  TimerPlayer.Enabled := False;
  Result := True;
end;

function TForm2.RecorderStart: Boolean;
begin
  try
    fFrameCount := 0;
    TimerCapture.Enabled := False;
    Camera.Quality := TVideoCaptureQuality(2);
    TabControl1.ActiveTab := tiCapture;
    Camera.Quality := TVideoCaptureQuality(2);
    Application.ProcessMessages;
  finally
    Camera.Active := True;
    VideoManager.ClearSound;
    VideoManager.ClearFrameCache;
    TimerCapture.Enabled := True;
    VideoManager.StartMicrafonCapture;
    Result := True;
  end;
end;

function TForm2.RecorderStop: Boolean;
begin
  try
    TimerCapture.Enabled := False;
    Application.ProcessMessages;
    Sleep(100);
    VideoManager.StopMicrafonCapture;
  finally
    Camera.Active := False;
    Result := True;
  end;
end;

procedure TForm2.TimerCaptureTimer(Sender: TObject);
begin
  fFrameCount := fFrameCount + 1;
  if (imgCameraView.Bitmap.Width > 0) and (imgCameraView.Bitmap.Height > 0) then
    VideoManager.CaptureBitmap(imgCameraView.Bitmap);
end;

procedure TForm2.TimerCreateTimer(Sender: TObject);
var
  AppEventSvc: IFMXApplicationEventService;
begin
  if TPlatformServices.Current.SupportsPlatformService
    (IFMXApplicationEventService, IInterface(AppEventSvc)) then
    AppEventSvc.SetApplicationEventHandler(AppEvent);
  VideoManager := TVideoManager.Create;

  VideoManager.GetCameraPermission;
  VideoManager.CreateMicrafon;
  VideoManager.Createobjets;
  // VideoManager.GetMicrafonePermission;
  TimerCreate.Enabled := False;

  VideoManager.FramePath := VideoManager.GetRecordPath;
  VideoManager.mpxFileName := 'video.mpx';
  VideoManager.mpxFilePath := VideoManager.GetRecordPath;
  VideoManager.AUDIOPath := VideoManager.GetAudioFileName(AUDIO_FILENAME);
  // Camera.Quality := TVideoCaptureQuality.MediumQuality;

end;

procedure TForm2.TimerPlayerTimer(Sender: TObject);

begin
  try
    fPlayerFrameCount := fPlayerFrameCount + 1;
    lbFcount := fPlayerFrameCount.ToString;

    if VideoManager.PicList.Count > fPlayerFrameCount + 1 then

      imgCameraView.Bitmap.Assign(VideoManager.PicList[fPlayerFrameCount])
    else
    begin
      TimerPlayer.Enabled := False;

    end;
    Application.ProcessMessages;
  except

  end;
end;

end.
