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
  FileName:string; //имя файла для записи
  RecMode: Boolean = False; //флаг записи
  DeviceName:OleVariant;  //имя устройства
  PropertyName:IPropertyBag; //
  pDevEnum:ICreateDEvEnum; //перечислитель устройств
  pEnum:IEnumMoniker; //перечислитель моникеров
  pMoniker:IMoniker;

  MArray1,MArray2: array of IMoniker; //Это список моникеров, из которго
                                      //мы потом будем получать необходмый моникер


//интерфейсы
    FGraphBuilder:        IGraphBuilder;
    FCaptureGraphBuilder: ICaptureGraphBuilder2;
    FMux:                 IBaseFilter;
    FSink:                IFileSinkFilter;
    FMediaControl:        IMediaControl;
    FVideoWindow:         IVideoWindow;

    FVideoCaptureFilter:  IBaseFilter;
    FAudioCaptureFilter:  IBaseFilter;
//область вывода изображения
    FVideoRect:           TRect;


implementation

{$R *.dfm}

function TForm1.Initializ: HResult;
begin
//Создаем объект для перечисления устройств
Result:=CoCreateInstance(CLSID_SystemDeviceEnum, NIL, CLSCTX_INPROC_SERVER,
IID_ICreateDevEnum, pDevEnum);
if Result<>S_OK then EXIT;

//Перечислитель устройств Video
Result:=pDevEnum.CreateClassEnumerator(CLSID_VideoInputDeviceCategory, pEnum, 0);
if Result<>S_OK then EXIT;
//Обнуляем массив в списке моникеров
setlength(MArray1,0);
//Пускаем массив по списку устройств
while (S_OK=pEnum.Next(1,pMoniker,Nil)) do
begin
setlength(MArray1,length(MArray1)+1); //Увеличиваем массив на единицу
MArray1[length(MArray1)-1]:=pMoniker; //Запоминаем моникер в масиве
Result:=pMoniker.BindToStorage(NIL, NIL, IPropertyBag, PropertyName); //Линкуем моникер устройства к формату хранения IPropertyBag
if FAILED(Result) then Continue;
Result:=PropertyName.Read('FriendlyName', DeviceName, NIL); //Получаем имя устройства
if FAILED(Result) then Continue;
//Добавляем имя устройства в списки
Listbox1.Items.Add(DeviceName);
end;

//Перечислитель устройств Audio
Result:=pDevEnum.CreateClassEnumerator(CLSID_AudioInputDeviceCategory, pEnum, 0);
if Result<>S_OK  then EXIT;
//Обнуляем массив в списке моникеров
setlength(MArray2,0);
//Пускаем массив по списку устройств
while (S_OK=pEnum.Next(1,pMoniker,Nil)) do
begin
setlength(MArray2,length(MArray2)+1); //Увеличиваем массив на единицу
MArray2[length(MArray2)-1]:=pMoniker; //Запоминаем моникер в масиве
Result:=pMoniker.BindToStorage(NIL, NIL, IPropertyBag, PropertyName); //Линкуем моникер устройства к формату хранения IPropertyBag
if FAILED(Result) then Continue;
Result:=PropertyName.Read('FriendlyName', DeviceName, NIL); //Получаем имя устройства
if FAILED(Result) then Continue;
//Добавляем имя устройства в списки
Listbox2.Items.Add(DeviceName);
end;
//Первоначальный выбор устройств для захвата видео и звука
//Выбираем из спика камеру
if ListBox1.Count=0 then
   begin
      ShowMessage('Камера не обнаружена');
      Result:=E_FAIL;;
      Exit;
   end;
Listbox1.ItemIndex:=0;
//Выбираем из спика устройства для записи звука
if ListBox2.Count=0 then
    begin
      ShowMessage('Микрофон не обнаружен');
    end
                    else  Listbox2.ItemIndex:=0;

//если все ОК
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
//Чистим граф
  FAudioCaptureFilter  := NIL;
  FVideoCaptureFilter  := NIL;
  FVideoWindow         := NIL;
  FMediaControl        := NIL;
  FSink                := NIL;
  FMux                 := NIL;
  FCaptureGraphBuilder := NIL;
  FGraphBuilder        := NIL;

//Создаем объект для графа фильтров
Result:=CoCreateInstance(CLSID_FilterGraph, NIL, CLSCTX_INPROC_SERVER, IID_IGraphBuilder, FGraphBuilder);
if FAILED(Result) then EXIT;
//Создаем объект для графа захвата
Result:=CoCreateInstance(CLSID_CaptureGraphBuilder2, NIL, CLSCTX_INPROC_SERVER, IID_ICaptureGraphBuilder2, FCaptureGraphBuilder);
if FAILED(Result) then EXIT;
//Задаем граф фильтров
Result:=FCaptureGraphBuilder.SetFiltergraph(FGraphBuilder);
if FAILED(Result) then EXIT;

//выбор устройств ListBox - ов
if Listbox1.ItemIndex>=0 then
           begin
              //получаем устройство для захвата видео из списка моникеров
              MArray1[Listbox1.ItemIndex].BindToObject(NIL, NIL, IID_IBaseFilter, FVideoCaptureFilter);
              //добавляем устройство в граф фильтров
              FGraphBuilder.AddFilter(FVideoCaptureFilter, 'VideoCaptureFilter'); //Получаем фильтр графа захвата
           end;

//если выбрано устройство для захвата звука
if Listbox2.ItemIndex>=0 then
           begin
              //получаем устройство для захвата звука из списка моникеров
              MArray2[Listbox2.ItemIndex].BindToObject(NIL, NIL, IID_IBaseFilter, FAudioCaptureFilter);
              //добавляем устройство в граф фильтров
              FGraphBuilder.AddFilter(FAudioCaptureFilter, 'AudioCaptureFilter');
              //строим граф для вывода звука
              Result:=FCaptureGraphBuilder.RenderStream(@PIN_CATEGORY_PREVIEW, @MEDIATYPE_Audio,
              FAudioCaptureFilter, NIL, NIL);
              if FAILED(Result) then EXIT;
           end;

//строим граф для вывода изображения
Result:=FCaptureGraphBuilder.RenderStream(@PIN_CATEGORY_PREVIEW, @MEDIATYPE_Video, FVideoCaptureFilter, NIL, NIL);
if FAILED(Result) then EXIT;
//Получаем интерфейс управления окном видео
Result:=FGraphBuilder.QueryInterface(IID_IVideoWindow, FVideoWindow);
if FAILED(Result) then EXIT;
//Задаем стиль окна вывода
FVideoWindow.put_WindowStyle(WS_CHILD or WS_CLIPSIBLINGS);
//Накладываем окно вывода на  Panel1
FVideoWindow.put_Owner(Panel1.Handle);
//Задаем размеры окна во всю панель
FVideoRect:=Panel1.ClientRect;
FVideoWindow.SetWindowPosition(FVideoRect.Left,FVideoRect.Top, FVideoRect.Right - FVideoRect.Left,FVideoRect.Bottom - FVideoRect.Top);
//показываем окно
FVideoWindow.put_Visible(TRUE);

//Запись
if RecMode then
begin
//Создаем файл для записи данных из графа
Result:=FCaptureGraphBuilder.SetOutputFileName(MEDIASUBTYPE_Avi, PWideChar(FileName), FMux, FSink);
if FAILED(Result) then EXIT;

//строим граф фильтров для захвата изображения
Result:=FCaptureGraphBuilder.RenderStream(@PIN_CATEGORY_CAPTURE, @MEDIATYPE_Video, FVideoCaptureFilter, Nil, FMux);
if FAILED(Result) then EXIT;


if Listbox2.ItemIndex>=0 then
    begin
        //строим граф фильтров для захвата звука
        Result:=FCaptureGraphBuilder.RenderStream(@PIN_CATEGORY_CAPTURE, @MEDIATYPE_Audio, FAudioCaptureFilter, Nil, FMux);
        if FAILED(Result) then EXIT;
        // При захвате видео со звуком устанавливаем звуковой поток в
        // качестве основного для синхронизации с другими потоками в файле
                pConfigMux := NIL;
                Result:=FMux.QueryInterface(IID_IConfigAviMux, pConfigMux);
                if FAILED(Result) then EXIT;
                begin
                  pConfigMux.SetMasterStream(1);
                  pConfigMux := NIL;
                end;
    end;
end;
//Запрашиваем интерфейс управления графом
Result:=FGraphBuilder.QueryInterface(IID_IMediaControl, FMediaControl);
if FAILED(Result) then Exit;
//Запускаем отображение просмотра с вебкамер
FMediaControl.Run();

end;



procedure TForm1.FormCreate(Sender: TObject);

begin


CoInitialize(nil);// инициализировать OLE COM
//вызываем процедуру поиска и инициализации устройств захвата видео и звука
if FAILED(Initializ) then
    Begin
      ShowMessage('Внимание! Произошла ошибка при инициализации');
      Exit;
    End;
//проверяем найденный список устройств
if Listbox1.Count>0 then
    Begin
        //если необходимые для работы устройства найдены,
        //то вызываем процедуру построения графа фильтров
        if FAILED(CreateGraph) then
            Begin
              ShowMessage('Внимание! Произошла ошибка при построении графа фильтров');
              Exit;
            End;
    end else
            Begin
              ShowMessage('Внимание! Камера не обнаружена.');
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
