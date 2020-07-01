{ Unit to takes a full screenshot or a window shot (window contents)

  Goal is for it to work on MS Windows and MacOS

  Thanks to Tipiweb (Stackoverflow user name) for the initial code of this
  project
}

unit xscreenshot;

interface
uses
  FMX.Types, FMX.Graphics, System.SysUtils,
 {$IFDEF MSWINDOWS}
  Classes, Windows, VCL.Forms, VCL.Graphics;
 {$ENDIF}
 {$IFDEF MACOS}
  Macapi.CoreFoundation, Macapi.CocoaTypes, Macapi.CoreGraphics, Macapi.ImageIO,
  system.Classes;
 {$ENDIF MACOS}

  procedure TakeScreenshot(Dest: FMX.Graphics.TBitmap);
  procedure TakeWindowShot(h: TWindowHandle; Dest: FMX.Graphics.TBitmap);

 {$IFDEF MSWINDOWS}
  procedure TakeWindowShotFromHWND(h: HWND; Dest: FMX.Graphics.TBitmap);
 {$ENDIF MSWINDOWS}

implementation


uses
{$IFDEF MSWINDOWS}
  FMX.Platform.Win;
{$ENDIF}
{$IFDEF MacOS}
  FMX.Platform.Mac;
{$ENDIF}


{$IFDEF MSWINDOWS}

// get window width and height
procedure GetWinSz(han: HWND; out w: integer; out h: integer);
var rect: TRect;
begin
  GetClientRect(han, rect);
  w := rect.Width;
  h := rect.Height;
end;

procedure WriteWindowsToStream(AStream: TStream; h: HWND);
var
  dc: HDC; lpPal : PLOGPALETTE;
  bm: TBitMap;
  WinWidth, WinHeight: integer;
begin
{test width and height}
  bm := TBitmap.Create;

  // full screenshot if h = 0
  if h = 0 then begin
    bm.Width := Screen.Width;
    bm.Height := Screen.Height;
  end else begin  // else a window shot, not full screen
    GetWinSz(h, WinWidth, WinHeight);
    bm.Width := WinWidth;
    bm.Height := WinHeight;
  end;

  //get the window handle dc (full screen is 0)
  dc := GetDc(h);
  if (dc = 0) then exit;
 //do we have a palette device?
  if (GetDeviceCaps(dc, RASTERCAPS) AND RC_PALETTE = RC_PALETTE) then
  begin
    //allocate memory for a logical palette
    GetMem(lpPal, sizeof(TLOGPALETTE) + (255 * sizeof(TPALETTEENTRY)));
    //zero it out to be neat
    FillChar(lpPal^, sizeof(TLOGPALETTE) + (255 * sizeof(TPALETTEENTRY)), #0);
    //fill in the palette version
    lpPal^.palVersion := $300;
    //grab the system palette entries
    lpPal^.palNumEntries :=GetSystemPaletteEntries(dc,0,256,lpPal^.palPalEntry);
    if (lpPal^.PalNumEntries <> 0) then
    begin
      //create the palette
      bm.Palette := CreatePalette(lpPal^);
    end;
    FreeMem(lpPal, sizeof(TLOGPALETTE) + (255 * sizeof(TPALETTEENTRY)));
  end;
  //copy from the screen to the bitmap
  BitBlt(bm.Canvas.Handle,0,0,bm.Width,bm.height,Dc,0,0,SRCCOPY);
                                        bm.SaveToStream(AStream);

  FreeAndNil(bm);
  //release the screen dc
  ReleaseDc(0, dc);
end;

procedure TakeWindowShotFromHWND(h: HWND; Dest: FMX.Graphics.TBitmap);
var
  Stream: TMemoryStream;
begin
  try
    Stream := TMemoryStream.Create;
    WriteWindowsToStream(Stream, h);
    Stream.Position := 0;
    Dest.LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TakeWindowShot(h: TWindowHandle; Dest: FMX.Graphics.TBitmap);
begin
  TakeWindowShotFromHWND(WindowHandleToPlatform(h).wnd, Dest);
end;


procedure TakeScreenshot(Dest: FMX.Graphics.TBitmap);
begin
  // 0 parameter means full screen shot
  TakeWindowShotFromHWND(0, Dest);
end;


{$ENDIF MSWINDOWS}

{$IFDEF MACOS}

{$IF NOT DECLARED(CGRectInfinite)}
const
  CGRectInfinite: CGRect = (origin: (x: -8.98847e+30; y: -8.98847e+307);
    size: (width: 1.79769e+308; height: 1.79769e+308));
{$IFEND}

{$IF NOT DECLARED(CGRectNull)}
  // TODO: Returns pointer or CGRect ?
  function CGRectNull: CGRect; cdecl; external libCoreGraphics name _PU + 'CGRectNull';
  {$EXTERNALSYM CGRectNull}

{$IFEND}

function PutBytesCallback(Stream: TStream; NewBytes: Pointer;
  Count: LongInt): LongInt; cdecl;
begin
  Result := Stream.Write(NewBytes^, Count);
end;

procedure ReleaseConsumerCallback(Dummy: Pointer); cdecl;
begin
end;

procedure WriteCGImageToStream(const AImage: CGImageRef; AStream: TStream;
  const AType: string = 'public.png'; AOptions: CFDictionaryRef = nil);
var
  Callbacks: CGDataConsumerCallbacks;
  Consumer: CGDataConsumerRef;
  ImageDest: CGImageDestinationRef;
  TypeCF: CFStringRef;
begin
  Callbacks.putBytes := @PutBytesCallback;
  Callbacks.releaseConsumer := ReleaseConsumerCallback;
  ImageDest := nil;
  TypeCF := nil;
  Consumer := CGDataConsumerCreate(AStream, @Callbacks);
  if Consumer = nil then RaiseLastOSError;
  try
    TypeCF := CFStringCreateWithCharactersNoCopy(nil, PChar(AType), Length(AType),
      kCFAllocatorNull); //wrap the Delphi string in a CFString shell
    ImageDest := CGImageDestinationCreateWithDataConsumer(Consumer, TypeCF, 1, AOptions);
    if ImageDest = nil then RaiseLastOSError;
    CGImageDestinationAddImage(ImageDest, AImage, nil);
    if CGImageDestinationFinalize(ImageDest) = 0 then RaiseLastOSError;
  finally
    if ImageDest <> nil then CFRelease(ImageDest);
    if TypeCF <> nil then CFRelease(TypeCF);
    CGDataConsumerRelease(Consumer);
  end;
end;

procedure TakeScreenshot(Dest: TBitmap);
var
  Screenshot: CGImageRef;
  Stream: TMemoryStream;
begin
  Stream := nil;
  ScreenShot := CGWindowListCreateImage(CGRectInfinite,
    kCGWindowListOptionOnScreenOnly, kCGNullWindowID, kCGWindowImageDefault);
  if ScreenShot = nil then RaiseLastOSError;
  try
    Stream := TMemoryStream.Create;
    WriteCGImageToStream(ScreenShot, Stream);
    Stream.Position := 0;
    Dest.LoadFromStream(Stream);
  finally
    CGImageRelease(ScreenShot);
    Stream.Free;
  end;
end;

procedure TakeWindowShot(h: TWindowHandle; Dest: FMX.Graphics.TBitmap);
var
  Screenshot: CGImageRef;
  Stream: TMemoryStream;
begin
  Stream := nil;
 // todo: window handle if logic
  ScreenShot := CGWindowListCreateImage(CGRectNull,
    kCGWindowListOptionIncludingWindow or kCGWindowListOptionOnScreenAboveWindow,
 	  WindowHandleToPlatform(h).Wnd.windowNumber, { platform specific Mac window ID here}
	  kCGWindowImageDefault
    );
  if ScreenShot = nil then RaiseLastOSError;
  try
    Stream := TMemoryStream.Create;
    WriteCGImageToStream(ScreenShot, Stream);
    Stream.Position := 0;
    Dest.LoadFromStream(Stream);
  finally
    CGImageRelease(ScreenShot);
    Stream.Free;
  end;
end;

 {$ENDIF MACOS}

 (* take screenshot of hidden window, objective c source:

 NSImage *img = [[NSImage alloc] initWithCGImage:[window windowImageShot] size:window.frame.size];

// category to NSWindow:

- (CGImageRef)windowImageShot
{
    CGWindowID windowID = (CGWindowID)[self windowNumber];
    CGWindowImageOption imageOptions = kCGWindowImageBoundsIgnoreFraming | kCGWindowImageNominalResolution;
    CGWindowListOption singleWindowListOptions = kCGWindowListOptionIncludingWindow;
    CGRect imageBounds = CGRectNull;

    CGImageRef windowImage = CGWindowListCreateImage(imageBounds, singleWindowListOptions, windowID, imageOptions);

    return windowImage;
}

 *)

end.
