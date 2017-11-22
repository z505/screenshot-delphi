unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Objects;

type
  TForm1 = class(TForm)
    Button1: TButton;
    Image1: TImage;
    Button2: TButton;
    Panel1: TPanel;
    Label1: TLabel;
    Panel2: TPanel;
    Label2: TLabel;
    Panel3: TPanel;
    Label3: TLabel;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

uses
 {$IFDEF MSWINDOWS}
  FMX.Platform.Win,
 {$ENDIF}
  xscreenshot;

procedure TForm1.Button1Click(Sender: TObject);
var bm: TBitmap;
begin
  bm := TBitmap.Create;
  TakeScreenshot(bm);
  Image1.Bitmap.Assign(bm);
  bm.Free; bm := nil;
end;

procedure TForm1.Button2Click(Sender: TObject);
var bm: TBitmap;
begin
  bm := TBitmap.Create;
  try
    TakeWindowShot(WindowHandleToPlatform(self.Handle).wnd, bm);
    Image1.Bitmap.Assign(bm);
  finally
    bm.Free; bm := nil;
  end;
end;

end.
