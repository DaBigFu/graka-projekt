function varargout = graka_gui(varargin)
% GRAKA_GUI MATLAB code for graka_gui.fig
%      GRAKA_GUI, by itself, creates a new GRAKA_GUI or raises the existing
%      singleton*.
%
%      H = GRAKA_GUI returns the handle to a new GRAKA_GUI or the handle to
%      the existing singleton*.
%
%      GRAKA_GUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GRAKA_GUI.M with the given input arguments.
%
%      GRAKA_GUI('Property','Value',...) creates a new GRAKA_GUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before graka_gui_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to graka_gui_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help graka_gui

% Last Modified by GUIDE v2.5 17-Sep-2012 22:11:17

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @graka_gui_OpeningFcn, ...
                   'gui_OutputFcn',  @graka_gui_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before graka_gui is made visible.
function graka_gui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to graka_gui (see VARARGIN)

% Choose default command line output for graka_gui
handles.output = hObject;
handles.ser = serial_con();
% Update handles structure
guidata(hObject, handles);

% UIWAIT makes graka_gui wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = graka_gui_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function com_baud_Callback(hObject, eventdata, handles)
% hObject    handle to com_baud (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of com_baud as text
%        str2double(get(hObject,'String')) returns contents of com_baud as a double
handles.ser.baud_rate = str2double(get(hObject,'String'));
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function com_baud_CreateFcn(hObject, eventdata, handles)
% hObject    handle to com_baud (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

guidata(hObject, handles);

% --- Executes on button press in com_connect_butt.
function com_connect_butt_Callback(hObject, eventdata, handles)
% hObject    handle to com_connect_butt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
switch handles.ser.status
    case 1
        handles.ser.open_port();
    case { 2, 3 }
        handles.ser.close_port();
    otherwise
end

update_gui(handles);
    
    
guidata(hObject, handles);

% --- Executes on selection change in ser_port_sel_drop.
function ser_port_sel_drop_Callback(hObject, eventdata, handles)
% hObject    handle to ser_port_sel_drop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns ser_port_sel_drop contents as cell array
%        contents{get(hObject,'Value')} returns selected item from ser_port_sel_drop
ports = get(hObject,'String');
handles.ser.com_port = ports{get(hObject,'Value')};
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function ser_port_sel_drop_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ser_port_sel_drop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
guidata(hObject, handles);


% --- Executes during object deletion, before destroying properties.
function figure1_DeleteFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.ser.close_port();


% --- Executes on button press in check_board_butt.
function check_board_butt_Callback(hObject, eventdata, handles)
% hObject    handle to check_board_butt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.ser.check_com;
update_gui(handles);   
guidata(hObject, handles);



function edit_first_12bit_Callback(hObject, eventdata, handles)
% hObject    handle to edit_first_12bit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_first_12bit as text
%        str2double(get(hObject,'String')) returns contents of edit_first_12bit as a double
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function edit_first_12bit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_first_12bit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
guidata(hObject, handles);


function edit_second_12bit_Callback(hObject, eventdata, handles)
% hObject    handle to edit_second_12bit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_second_12bit as text
%        str2double(get(hObject,'String')) returns contents of edit_second_12bit as a double
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function edit_second_12bit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_second_12bit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
guidata(hObject, handles);

% --- Executes on button press in dbg_pb_write.
function dbg_pb_write_Callback(hObject, eventdata, handles)
% hObject    handle to dbg_pb_write (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.ser.write_command(2);
str_1 = get(handles.edit_first_12bit, 'string');
str_2 = get(handles.edit_second_12bit, 'string');
handles.ser.write_command(hex2dec(str_1(1:2)));
handles.ser.write_command(hex2dec(str_1(3:4)));
handles.ser.write_command(hex2dec(str_2(1:2)));
handles.ser.write_command(hex2dec(str_2(3:4)));

guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function dbg_pan_mem_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dbg_pan_mem (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

set( get(hObject,'children'), 'enable', 'off');
guidata(hObject, handles);



function edit_file_path_Callback(hObject, eventdata, handles)
% hObject    handle to edit_file_path (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_file_path as text
%        str2double(get(hObject,'String')) returns contents of edit_file_path as a double
switch(fext)
    case '.bin'
        handles.FilterIndex = 1;
    case '.bmp'
        handles.FilterIndex = 2;
    otherwise
end
handles.FileName = [fname fext];
handles.PathName = fpath;
%TODO: check file properties
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function edit_file_path_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_file_path (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
guidata(hObject, handles);

% --- Executes on button press in pb_browse_file.
function pb_browse_file_Callback(hObject, eventdata, handles)
% hObject    handle to pb_browse_file (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
file_filter = { '*.bin', '*.bin, binary files, headers removed' ;...
                '*.bmp', '*.bmp, bitmap file, headers not removed' };
[handles.FileName,handles.PathName,handles.FilterIndex] = uigetfile(file_filter, 'Browse Files');
set(handles.edit_file_path, 'String', [handles.PathName handles.FileName]);
guidata(hObject, handles);

% --- Executes on button press in pb_write_file.
function pb_write_file_Callback(hObject, eventdata, handles)
% hObject    handle to pb_write_file (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
file_in = fopen( [ handles.PathName handles.FileName ], 'r');
file_array = fread(file_in, [512 1875], 'uint8', 'ieee-be');
handles.ser.write_uint8(2);
for i = 1:1:1875
    for j = 1:1:512
        handles.ser.write_uint8(file_array(j,i));
    end
    if handles.ser.read_char == 23
        disp(i);
    end
end



guidata(hObject, handles);
