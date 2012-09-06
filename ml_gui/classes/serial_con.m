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
    
    properties (Constant, GetAccess = public)
        %strings to display in GUI with obj.status_strings(obj.status)
        stauts_strings = { 'not opened'...
                            'COM port opened'...
                            'board found' };
    end
    
    methods
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
                disp('Tried to com_port on already opened port, YSNST');
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
                disp('Tried open port on already opened port, YSNST');
            end
        end
        
        function close_port(obj)
            if ~(obj.status == 1)
                fclose(obj.ser_port);
                obj.status = 1;
            else
                disp('Tried close port that was not open, YSNST');
            end
        end
        %##################################################################
    end
        
    methods
        %constructor
        function obj = serial_con()
            obj.ser_port = serial('COM1', 'BAUD', 115200);
        end
    end
    
end

