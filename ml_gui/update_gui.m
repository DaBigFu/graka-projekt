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
        %switch panels on/off
        set( get(handles.write_file_panel, 'children'), 'enable', 'off');
        set( get(handles.pan_cont, 'children'), 'enable', 'off');
        set( get(handles.pan_brightness, 'children'), 'enable', 'off');
    case 2
        set(handles.com_connect_butt, 'String', 'close port');
        set(handles.check_board_butt, 'Enable', 'on');
        set(handles.ser_port_sel_drop, 'Enable', 'off');
        set(handles.com_baud, 'Enable', 'off');
        set(handles.com_status,'String', handles.ser.get_status_string());
        set(handles.com_status,'BackgroundColor', [0.87 0.49 0]);
        %switch panels on/off
        set( get(handles.write_file_panel, 'children'), 'enable', 'off');
        set( get(handles.pan_cont, 'children'), 'enable', 'off');
        set( get(handles.pan_brightness, 'children'), 'enable', 'off');
    case 3
        set(handles.com_status,'String', handles.ser.get_status_string());
        set(handles.com_status,'BackgroundColor', 'green');
        %switch panels on/off
        set( get(handles.write_file_panel, 'children'), 'enable', 'on');
        set( get(handles.pan_cont, 'children'), 'enable', 'on');
        set( get(handles.pan_brightness, 'children'), 'enable', 'on');
    otherwise
        %tbd
end

end

