classdef serial_con < handle
    %SERIAL_CON Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = protected, GetAccess = public)
        status = 1;
    end
    
    properties (Dependent = true, GetAccess = public, SetAccess = public)
        baud_rate;
        com_port;
    end
    
    properties (SetAccess = protected, GetAccess = protected)
        ser_port;
    end
    
    properties (Constant, GetAccess = protected)
        %strings to display in GUI with obj.status_strings{obj.status}
        status_strings = { 'not opened'...
                            'COM port opened'...
                            'board found' };
    end
    
    methods
        %returns a text status for use in GUI
        function status_string = get_status_string(obj)
            status_string = obj.status_strings{obj.status};
        end
        %##################################################################
        %Set & get for the dependent properties
        function obj = set.baud_rate(obj, n_baud)
            if (obj.status == 1)
                set(obj.ser_port, 'BAUD', n_baud);
            else
                disp('Tried to set baud rate on already opened port, YSNST');
            end
        end
        
        function baud_rate = get.baud_rate(obj)
            baud_rate = get(obj.ser_port, 'BAUD');
        end
        
        function obj = set.com_port(obj, n_port)
            if (obj.status == 1)
                set(obj.ser_port, 'Port', n_port);
            else
                disp('Tried to set com_port on already opened port, YSNST');
            end
        end
        
        function com_port = get.com_port(obj)
            com_port = get(obj.ser_port, 'Port');
        end
        %##################################################################
        %open/close the ports
        function open_port(obj)
            if (obj.status == 1)
                fopen(obj.ser_port);
                obj.status = 2;
            else
                disp('Tried to open port on already opened port, YSNST');
            end
        end
        
        function close_port(obj)
            if ~(obj.status == 1)
                fclose(obj.ser_port);
                obj.status = 1;
            else
                disp('Tried to close port that was not open, YSNST');
            end
        end
        %##################################################################
        %read/write functions
        function write_char(obj, char)
            if (obj.status == 1)
                disp('tried to send data via closed port');
            else
                fwrite(obj.ser_port, char);
            end
        end
        
        function char = read_char(obj)
            if (obj.status == 1)
                disp('tried to send data via closed port');
            else
                char = fread(obj.ser_port, 1, 'uint8');
            end
        end
        
        function write_command(obj, com)
            if (obj.status == 1)
                disp('tried to send data via closed port');
            else
                fprintf(obj.ser_port, '%c', com);
            end
        end
        
        function write_uint8(obj, int_in)
            if (obj.status == 1)
                disp('tried to send data via closed port');
            else
                fwrite(obj.ser_port,int_in, 'uint8');
            end
        end
        
        function write_uint8_fast(obj, int_in)
            fwrite(obj.ser_port,int_in, 'uint8');
        end
        
        function write_array(obj, arr_in, dim1, dim2)
            wait_h = waitbar(0, 'Daten werden übertragen...');
            for i = dim2:-1:1
                fwrite(obj.ser_port, arr_in(dim1:-1:1,i),'uint8');         
                if obj.read_char == 23
                    waitbar((dim2-i)/dim2,wait_h);                    
                end
            end
            close(wait_h);
        end
        
        function new_status = check_com(obj)
            if (obj.status == 1)
                disp('tried to send data via closed port');
            else
                fprintf(obj.ser_port, '%c', 5);
                if fread(obj.ser_port, 1,'uchar') == 6
                    obj.status = 3;
                    new_status = 3;
                else
                    obj.status = 2;
                    new_status = 2;
                end
            end
        end
        
    end
        
    methods
        %constructor
        function obj = serial_con()
            obj.ser_port = serial('COM1', 'BAUD', 115200, 'OutputBufferSize', 1024);
        end
    end
    
end

