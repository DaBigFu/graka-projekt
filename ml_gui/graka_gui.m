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

% Last Modified by GUIDE v2.5 28-Sep-2012 18:41:40

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
guidata(hObject, handles);
handles.dbg_gui = dbg_gui(hObject);
set(handles.dbg_gui, 'Visible', 'off');
set( get(handles.write_file_panel, 'children'), 'enable', 'off');
update_gui(handles);
% Update handles structure
guidata(hObject, handles);

% UIWAIT makes graka_gui wait for user response (see UIRESUME)
% uiwait(handles.ser_gui);


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
function ser_gui_DeleteFcn(hObject, eventdata, handles)
% hObject    handle to ser_gui (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
delete(handles.dbg_gui);
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
[fpath fname fext] = fileparts(get(hObject, 'string'));
if exist( [fpath fname fext] )    
    switch(fext)
        case '.bin'
            handles.FilterIndex = 1;
        case '.bmp'
            handles.FilterIndex = 2;
        otherwise
    end
else
    errordlg(['File not found, the file "' fpath fname fext '" does not exist.'], 'File string error');    
    set(hObject, 'string', 'File not found');
end
handles.FileName = [fname fext];
handles.PathName = fpath;
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
switch handles.bit_depth
    case 12
        file_array = fread(file_in, [512 1875], 'uint8', 'ieee-be');
        handles.ser.write_uint8(2);
        handles.ser.write_array(file_array,512,1875);
    case 24
        profile clear
        profile on
        file_array = fread(file_in, [768 3072], 'uint8', 'ieee-be');
        file_array = flip_array(file_array);
        handles.ser.write_uint8(2);
        handles.ser.write_array(file_array,768,3072);
        profile off
        profile viewer
    otherwise
        disp('error in bit depth selection');
end

guidata(hObject, handles);


% --- Executes on button press in pb_open_dbg.
function pb_open_dbg_Callback(hObject, eventdata, handles)
% hObject    handle to pb_open_dbg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.dbg_gui, 'Visible', 'on');
guidata(hObject, handles);


% --- Executes when selected object is changed in pan_bit_depth.
function pan_bit_depth_SelectionChangeFcn(hObject, eventdata, handles)
% hObject    handle to the selected object in pan_bit_depth 
% eventdata  structure with the following fields (see UIBUTTONGROUP)
%	EventName: string 'SelectionChanged' (read only)
%	OldValue: handle of the previously selected object or empty if none was selected
%	NewValue: handle of the currently selected object
% handles    structure with handles and user data (see GUIDATA)
switch get(eventdata.NewValue, 'String')
    case '12 BPP'
        handles.bit_depth = 12;
    case '24 BPP'
        handles.bit_depth = 24;
    otherwise
        handles.bit_depth = -1;
end
guidata(hObject, handles);
        





% --- Executes during object creation, after setting all properties.
function pan_bit_depth_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pan_bit_depth (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
handles.bit_depth = 24;
set(hObject, 'HandleVisibility', 'off');
guidata(hObject, handles);





function edit_hist_move_Callback(hObject, eventdata, handles)
% hObject    handle to edit_hist_move (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_hist_move as text
%        str2double(get(hObject,'String')) returns contents of edit_hist_move as a double
if str2double(get(hObject,'String')) > 127
    set(hObject, 'String', '127');
elseif str2double(get(hObject,'String')) < -128
    set(hObject, 'String', '-128');
end
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function edit_hist_move_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_hist_move (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
guidata(hObject, handles);

% --- Executes on button press in pb_move_hist.
function pb_move_hist_Callback(hObject, eventdata, handles)
% hObject    handle to pb_move_hist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.ser.write_uint8(17);
handles.ser.write_sint8(str2double(get(handles.edit_hist_move,'String')));

guidata(hObject, handles);



function edit_cont_max_Callback(hObject, eventdata, handles)
% hObject    handle to edit_cont_max (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_cont_max as text
%        str2double(get(hObject,'String')) returns contents of edit_cont_max as a double
if str2double(get(hObject,'String')) > 255
    set(hObject, 'String', '255');
elseif str2double(get(hObject,'String')) < 0
    set(hObject, 'String', '0');
end
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function edit_cont_max_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_cont_max (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
guidata(hObject, handles);


function edit_cont_min_Callback(hObject, eventdata, handles)
% hObject    handle to edit_cont_min (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_cont_min as text
%        str2double(get(hObject,'String')) returns contents of edit_cont_min as a double
if str2double(get(hObject,'String')) > 255
    set(hObject, 'String', '255');
elseif str2double(get(hObject,'String')) < 0
    set(hObject, 'String', '0');
end
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function edit_cont_min_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_cont_min (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
guidata(hObject, handles);

% --- Executes on button press in pb_cont.
function pb_cont_Callback(hObject, eventdata, handles)
% hObject    handle to pb_cont (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.ser.write_uint8(18);
handles.ser.write_uint8(str2double(get(handles.edit_cont_min,'String')));
handles.ser.write_uint8(str2double(get(handles.edit_cont_max,'String')));
guidata(hObject, handles);
