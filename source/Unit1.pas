unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, directshow9, ActiveX, StdCtrls, sButton, sEdit,
  sSkinManager, sLabel, Registry, TlHelp32, sPanel, TransparentPanels;

type
  TForm1 = class(TForm)
    sSkinManager1: TsSkinManager;
    Panel1: TsPanel;
    TransparentPanel1: TTransparentPanel;
    ListBox1: TListBox;
    ListBox2: TListBox;
    sButton1: TsButton;
    sLabel2: TsLabel;
    sLabel3: TsLabel;
    function Initializ: HResult;
    function CreateGraph: HResult;
    procedure FormCreate(Sender: TObject);
    procedure sButton1Click(Sender: TObject);
    procedure FormClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  private
    { Private declarations }
  public
    { Public declarations }
  end;


var
  Form1: TForm1;
  FileName:string; //��� ����� ��� ������
  RecMode: Boolean = False; //���� ������
  DeviceName:OleVariant;  //��� ����������
  PropertyName:IPropertyBag; //
  pDevEnum:ICreateDEvEnum; //������������� ���������
  pEnum:IEnumMoniker; //������������� ���������
  pMoniker:IMoniker;

  MArray1,MArray2: array of IMoniker; //��� ������ ���������, �� �������
                                      //�� ����� ����� �������� ���������� �������


//����������
    FGraphBuilder:        IGraphBuilder;
    FCaptureGraphBuilder: ICaptureGraphBuilder2;
    FMux:                 IBaseFilter;
    FSink:                IFileSinkFilter;
    FMediaControl:        IMediaControl;
    FVideoWindow:         IVideoWindow;

    FVideoCaptureFilter:  IBaseFilter;
    FAudioCaptureFilter:  IBaseFilter;
//������� ������ �����������
    FVideoRect:           TRect;


implementation

{$R *.dfm}

function TForm1.Initializ: HResult;
begin
//������� ������ ��� ������������ ���������
Result:=CoCreateInstance(CLSID_SystemDeviceEnum, NIL, CLSCTX_INPROC_SERVER,
IID_ICreateDevEnum, pDevEnum);
if Result<>S_OK then EXIT;

//������������� ��������� Video
Result:=pDevEnum.CreateClassEnumerator(CLSID_VideoInputDeviceCategory, pEnum, 0);
if Result<>S_OK then EXIT;
//�������� ������ � ������ ���������
setlength(MArray1,0);
//������� ������ �� ������ ���������
while (S_OK=pEnum.Next(1,pMoniker,Nil)) do
begin
setlength(MArray1,length(MArray1)+1); //����������� ������ �� �������
MArray1[length(MArray1)-1]:=pMoniker; //���������� ������� � ������
Result:=pMoniker.BindToStorage(NIL, NIL, IPropertyBag, PropertyName); //������� ������� ���������� � ������� �������� IPropertyBag
if FAILED(Result) then Continue;
Result:=PropertyName.Read('FriendlyName', DeviceName, NIL); //�������� ��� ����������
if FAILED(Result) then Continue;
//��������� ��� ���������� � ������
Listbox1.Items.Add(DeviceName);
end;

//������������� ��������� Audio
Result:=pDevEnum.CreateClassEnumerator(CLSID_AudioInputDeviceCategory, pEnum, 0);
if Result<>S_OK  then EXIT;
//�������� ������ � ������ ���������
setlength(MArray2,0);
//������� ������ �� ������ ���������
while (S_OK=pEnum.Next(1,pMoniker,Nil)) do
begin
setlength(MArray2,length(MArray2)+1); //����������� ������ �� �������
MArray2[length(MArray2)-1]:=pMoniker; //���������� ������� � ������
Result:=pMoniker.BindToStorage(NIL, NIL, IPropertyBag, PropertyName); //������� ������� ���������� � ������� �������� IPropertyBag
if FAILED(Result) then Continue;
Result:=PropertyName.Read('FriendlyName', DeviceName, NIL); //�������� ��� ����������
if FAILED(Result) then Continue;
//��������� ��� ���������� � ������
Listbox2.Items.Add(DeviceName);
end;
//�������������� ����� ��������� ��� ������� ����� � �����
//�������� �� ����� ������
if ListBox1.Count=0 then
   begin
      ShowMessage('������ �� ����������');
      Result:=E_FAIL;;
      Exit;
   end;
Listbox1.ItemIndex:=0;
//�������� �� ����� ���������� ��� ������ �����
if ListBox2.Count=0 then
    begin
      ShowMessage('�������� �� ���������');
    end
                    else  Listbox2.ItemIndex:=0;

//���� ��� ��
Result:=S_OK;
end;

function TForm1.CreateGraph:HResult;
var
  pConfigMux: IConfigAviMux;
begin
Panel1.Left:=1;
Panel1.Top:=1;
Panel1.Height:=screen.Height-1;
Panel1.Width:=Screen.Width-1;
//������ ����
  FAudioCaptureFilter  := NIL;
  FVideoCaptureFilter  := NIL;
  FVideoWindow         := NIL;
  FMediaControl        := NIL;
  FSink                := NIL;
  FMux                 := NIL;
  FCaptureGraphBuilder := NIL;
  FGraphBuilder        := NIL;

//������� ������ ��� ����� ��������
Result:=CoCreateInstance(CLSID_FilterGraph, NIL, CLSCTX_INPROC_SERVER, IID_IGraphBuilder, FGraphBuilder);
if FAILED(Result) then EXIT;
//������� ������ ��� ����� �������
Result:=CoCreateInstance(CLSID_CaptureGraphBuilder2, NIL, CLSCTX_INPROC_SERVER, IID_ICaptureGraphBuilder2, FCaptureGraphBuilder);
if FAILED(Result) then EXIT;
//������ ���� ��������
Result:=FCaptureGraphBuilder.SetFiltergraph(FGraphBuilder);
if FAILED(Result) then EXIT;

//����� ��������� ListBox - ��
if Listbox1.ItemIndex>=0 then
           begin
              //�������� ���������� ��� ������� ����� �� ������ ���������
              MArray1[Listbox1.ItemIndex].BindToObject(NIL, NIL, IID_IBaseFilter, FVideoCaptureFilter);
              //��������� ���������� � ���� ��������
              FGraphBuilder.AddFilter(FVideoCaptureFilter, 'VideoCaptureFilter'); //�������� ������ ����� �������
           end;

//���� ������� ���������� ��� ������� �����
if Listbox2.ItemIndex>=0 then
           begin
              //�������� ���������� ��� ������� ����� �� ������ ���������
              MArray2[Listbox2.ItemIndex].BindToObject(NIL, NIL, IID_IBaseFilter, FAudioCaptureFilter);
              //��������� ���������� � ���� ��������
              FGraphBuilder.AddFilter(FAudioCaptureFilter, 'AudioCaptureFilter');
              //������ ���� ��� ������ �����
              Result:=FCaptureGraphBuilder.RenderStream(@PIN_CATEGORY_PREVIEW, @MEDIATYPE_Audio,
              FAudioCaptureFilter, NIL, NIL);
              if FAILED(Result) then EXIT;
           end;

//������ ���� ��� ������ �����������
Result:=FCaptureGraphBuilder.RenderStream(@PIN_CATEGORY_PREVIEW, @MEDIATYPE_Video, FVideoCaptureFilter, NIL, NIL);
if FAILED(Result) then EXIT;
//�������� ��������� ���������� ����� �����
Result:=FGraphBuilder.QueryInterface(IID_IVideoWindow, FVideoWindow);
if FAILED(Result) then EXIT;
//������ ����� ���� ������
FVideoWindow.put_WindowStyle(WS_CHILD or WS_CLIPSIBLINGS);
//����������� ���� ������ ��  Panel1
FVideoWindow.put_Owner(Panel1.Handle);
//������ ������� ���� �� ��� ������
FVideoRect:=Panel1.ClientRect;
FVideoWindow.SetWindowPosition(FVideoRect.Left,FVideoRect.Top, FVideoRect.Right - FVideoRect.Left,FVideoRect.Bottom - FVideoRect.Top);
//���������� ����
FVideoWindow.put_Visible(TRUE);

//������
if RecMode then
begin
//������� ���� ��� ������ ������ �� �����
Result:=FCaptureGraphBuilder.SetOutputFileName(MEDIASUBTYPE_Avi, PWideChar(FileName), FMux, FSink);
if FAILED(Result) then EXIT;

//������ ���� �������� ��� ������� �����������
Result:=FCaptureGraphBuilder.RenderStream(@PIN_CATEGORY_CAPTURE, @MEDIATYPE_Video, FVideoCaptureFilter, Nil, FMux);
if FAILED(Result) then EXIT;


if Listbox2.ItemIndex>=0 then
    begin
        //������ ���� �������� ��� ������� �����
        Result:=FCaptureGraphBuilder.RenderStream(@PIN_CATEGORY_CAPTURE, @MEDIATYPE_Audio, FAudioCaptureFilter, Nil, FMux);
        if FAILED(Result) then EXIT;
        // ��� ������� ����� �� ������ ������������� �������� ����� �
        // �������� ��������� ��� ������������� � ������� �������� � �����
                pConfigMux := NIL;
                Result:=FMux.QueryInterface(IID_IConfigAviMux, pConfigMux);
                if FAILED(Result) then EXIT;
                begin
                  pConfigMux.SetMasterStream(1);
                  pConfigMux := NIL;
                end;
    end;
end;
//����������� ��������� ���������� ������
Result:=FGraphBuilder.QueryInterface(IID_IMediaControl, FMediaControl);
if FAILED(Result) then Exit;
//��������� ����������� ��������� � ��������
FMediaControl.Run();

end;



procedure TForm1.FormCreate(Sender: TObject);

begin


CoInitialize(nil);// ���������������� OLE COM
//�������� ��������� ������ � ������������� ��������� ������� ����� � �����
if FAILED(Initializ) then
    Begin
      ShowMessage('��������! ��������� ������ ��� �������������');
      Exit;
    End;
//��������� ��������� ������ ���������
if Listbox1.Count>0 then
    Begin
        //���� ����������� ��� ������ ���������� �������,
        //�� �������� ��������� ���������� ����� ��������
        if FAILED(CreateGraph) then
            Begin
              ShowMessage('��������! ��������� ������ ��� ���������� ����� ��������');
              Exit;
            End;
    end else
            Begin
              ShowMessage('��������! ������ �� ����������.');
              //Application.Terminate;
            End;
             Form1.Click;
end;

procedure TForm1.sButton1Click(Sender: TObject);
begin
Application.Terminate;
end;

procedure TForm1.FormClick(Sender: TObject);
begin
if TransparentPanel1.Visible = True then
begin
TransparentPanel1.Visible:=False
end
else
begin
TransparentPanel1.Visible:=True;
end;
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
If Key=VK_F1 then
begin
if TransparentPanel1.Visible = True then
begin
TransparentPanel1.Visible:=False
end
else
begin
TransparentPanel1.Visible:=True;
end;
end;
end;

end.
