function update_gui( handles )
%activates/deactivates GUI elements based on the status
%   Detailed explanation goes here
switch handles.ser.status
    case 1
        set(handles.com_connect_butt, 'String', 'open port');
        set(handles.check_board_butt, 'Enable', 'off');
        set(handles.ser_port_sel_drop, 'Enable', 'on');
        set(handles.com_baud, 'Enable', 'on');
        set(handles.com_status,'String', handles.ser.get_status_string());
        set(handles.com_status,'BackgroundColor', 'red');
        set( get(handles.dbg_pan_mem, 'children'), 'enable', 'off');
    case 2
        set(handles.com_connect_butt, 'String', 'close port');
        set(handles.check_board_butt, 'Enable', 'on');
        set(handles.ser_port_sel_drop, 'Enable', 'off');
        set(handles.com_baud, 'Enable', 'off');
        set(handles.com_status,'String', handles.ser.get_status_string());
        set(handles.com_status,'BackgroundColor', [0.87 0.49 0]);
        set( get(handles.dbg_pan_mem, 'children'), 'enable', 'off');
    case 3
        set(handles.com_status,'String', handles.ser.get_status_string());
        set(handles.com_status,'BackgroundColor', 'green');
        set( get(handles.dbg_pan_mem, 'children'), 'enable', 'on');
    otherwise
        %tbd
end

end

