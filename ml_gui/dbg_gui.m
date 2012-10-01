function varargout = dbg_gui(varargin)
% DBG_GUI MATLAB code for dbg_gui.fig
%      DBG_GUI, by itself, creates a new DBG_GUI or raises the existing
%      singleton*.
%
%      H = DBG_GUI returns the handle to a new DBG_GUI or the handle to
%      the existing singleton*.
%
%      DBG_GUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in DBG_GUI.M with the given input arguments.
%
%      DBG_GUI('Property','Value',...) creates a new DBG_GUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before dbg_gui_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to dbg_gui_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help dbg_gui

% Last Modified by GUIDE v2.5 19-Sep-2012 19:38:58

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @dbg_gui_OpeningFcn, ...
                   'gui_OutputFcn',  @dbg_gui_OutputFcn, ...
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


% --- Executes just before dbg_gui is made visible.
function dbg_gui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to dbg_gui (see VARARGIN)

% Choose default command line output for dbg_gui
handles.output = hObject;
handles.graka_gui = guidata(varargin{:}); % passes the handles to the new gui

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes dbg_gui wait for user response (see UIRESUME)
% uiwait(handles.dbg_gui);


% --- Outputs from this function are returned to the command line.
function varargout = dbg_gui_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in pb_dbg_close.
function pb_dbg_close_Callback(hObject, eventdata, handles)
% hObject    handle to pb_dbg_close (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.dbg_gui, 'Visible', 'off');
guidata(hObject, handles);


function edit_dbg_read_Callback(hObject, eventdata, handles)
% hObject    handle to edit_dbg_read (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_dbg_read as text
%        str2double(get(hObject,'String')) returns contents of edit_dbg_read as a double
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function edit_dbg_read_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_dbg_read (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
guidata(hObject, handles);

% --- Executes on button press in pb_dbg_read.
function pb_dbg_read_Callback(hObject, eventdata, handles)
% hObject    handle to pb_dbg_read (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.edit_dbg_read, 'string', get(handles.graka_gui.ser.read_char, 'string'));
guidata(hObject, handles);


function edit_dbg_write_cnt_Callback(hObject, eventdata, handles)
% hObject    handle to edit_dbg_write_cnt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_dbg_write_cnt as text
%        str2double(get(hObject,'String')) returns contents of edit_dbg_write_cnt as a double
if ~(str2dec(get(hObject, 'String')) > 1 && str2dec(get(hObject, 'String')) < 513)
    set(hObject, 'String', '1');
end
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function edit_dbg_write_cnt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_dbg_write_cnt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
guidata(hObject, handles);

function edit_dbg_write_data_Callback(hObject, eventdata, handles)
% hObject    handle to edit_dbg_write_data (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_dbg_write_data as text
%        str2double(get(hObject,'String')) returns contents of edit_dbg_write_data as a double
try
    hex2dec(get(hObject,'String'));
catch
    set(hObject, 'String', 'FF');
end
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function edit_dbg_write_data_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_dbg_write_data (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
guidata(hObject, handles);

% --- Executes on button press in pb_dbg_write.
function pb_dbg_write_Callback(hObject, eventdata, handles)
% hObject    handle to pb_dbg_write (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
send_arr = zeros(1,str2num(get(handles.edit_dbg_write_cnt, 'String')));
send_arr(1,:) = hex2dec(get(handles.edit_dbg_write_data, 'String'));
handles.graka_gui.ser.write_uint8(send_arr(1,:));
guidata(hObject, handles);


% --- Executes when user attempts to close dbg_gui.
function dbg_gui_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to dbg_gui (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
set(hObject, 'Visible', 'off');
