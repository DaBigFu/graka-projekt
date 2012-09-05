function open_ser_port( handles )
%OPEN_SER_PORT Summary of this function goes here
%   Detailed explanation goes here
if(~strcmp(get(handles.ser, 'Status'),'open'))
    fopen(handles.ser);
end

end

