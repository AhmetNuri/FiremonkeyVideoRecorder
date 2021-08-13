program FiremonkeyVideoRecorder;

uses
  System.StartUpCopy,
  FMX.Forms,
  uVideoMain in 'uVideoMain.pas' {Form2},
  uVideoRecorder in 'uVideoRecorder.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
