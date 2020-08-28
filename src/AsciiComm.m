classdef AsciiComm < handle
    
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    properties (Constant)
        
        cCONNECTION_SERIAL = 'serial'
        cCONNECTION_TCPCLIENT = 'tcpclient'
        
    end
    
    properties
    
        % {char 1xm}
        cConnection % cCONNECTION_SERIAL | cCONNECTION_TCPCLIENT
        
        
        % {char 1xm} port of MATLAB {serial}
        cPort = 'COM1'
        
        % {uint16 1x1} - baud rate of MATLAB {serial}.  Must match hardware
        % to set on hardware: menu --> communication --> rs-232 -> baud
        u16BaudRate = uint16(9600);
        
        % {double 1x1} - timeout of MATLAB {serial, tcpip, tcpclient} - amount of time it will
        % wait for a response before aborting.  
        dTimeout = 2

        
        % tcpip config
        % --------------------------------
        % {char 1xm} tcp/ip host
        cTcpipHost = '192.168.0.3'
        
        % {uint16 1x1} tcpip port NPort requires a port of 4001 when in
        % "TCP server" mode
        u16TcpipPort = uint16(4001)
        
        lDebug = false
        
        u8TerminatorWrite = uint8([13 10])
        u8TerminatorRead = uint8([13 10])
    end
    
    properties (Access = protected)
        
        % {tcpip 1x1} tcpip connection 
        % MATLAB talks to nPort 5150A Serial Device Server over tcpip.
        % The nPort then talks to the MMC-103 using RS-485 BUS
        comm
        
    end
    
    methods
        
        function this = AsciiComm(varargin) 
            
            this.cConnection = this.cCONNECTION_SERIAL; % default
            
            for k = 1 : 2: length(varargin)
                this.msg(sprintf('passed in %s', varargin{k}));
                if this.hasProp( varargin{k})
                    this.msg(sprintf('settting %s', varargin{k}));
                    this.(varargin{k}) = varargin{k + 1};
                end
            end
            
        end
        
        function init(this)
            
            switch this.cConnection
                case this.cCONNECTION_SERIAL
                    try
                        this.msg('init() creating serial instance');
                        this.comm = serial(this.cPort);
                        this.comm.BaudRate = this.u16BaudRate;
                        % this.comm.InputBufferSize = this.u16InputBufferSize;
                        % this.comm.OutputBufferSize = this.u16OutputBufferSize;
                        fopen(this.comm); 
                    catch ME
                        getReport(ME)
                        rethrow(ME)
                    end
                case this.cCONNECTION_TCPCLIENT
                    try
                       this.msg('init() creating tcpclient instance');
                       this.comm = tcpclient(this.cTcpipHost, this.u16TcpipPort);
                    catch ME
                        this.msg(getReport(ME));
                        rethrow(ME)
                    end
            end
            
        end
        
        
        function clearBytesAvailable(this)
            
            % This doesn't alway work.  I've found that if I overfill the
            % input buffer, call this method, then do a subsequent read,
            % the results come back all with -1.6050e9.  Need to figure
            % this out
            
            this.msg('clearBytesAvailable()');
            
            while this.comm.BytesAvailable > 0
                cMsg = sprintf(...
                    'clearBytesAvailable() clearing %1.0f bytes', ...
                    this.comm.BytesAvailable ...
                );
                this.msg(cMsg);
                fread(this.comm, this.comm.BytesAvailable);
            end
        end
        
        
        
        
        function delete(this)
            
            % close open connections
            
            switch this.cConnection
                case this.cCONNECTION_SERIAL
                    
                    if ~isa(this.comm, 'serial')
                        return;
                    end
                    try
                        fclose(this.comm);
                    catch ME
                        rethrow(ME);
                    end
            end
        end
        
       
        % Writes an ASCII command to the communication object (serial,
        % tcpip, or tcpclient
        % Create the binary command packet as follows:
        % Convert the char command into a list of uint8 (decimal), 
        % concat with the terminator

        
        function writeAscii(this, cCmd)
            
            % this.msg(sprintf('write %s', cCmd))
            switch this.cConnection
                case this.cCONNECTION_TCPCLIENT
                    u8Cmd = [uint8(cCmd) this.u8TerminatorWrite];
                    write(this.comm, u8Cmd);
                otherwise
                    u8Cmd = [uint8(cCmd) this.u8TerminatorWrite];
                    fwrite(this.comm, u8Cmd);
            end
                    
        end
        
        % Read until the terminator is reached and convert to ASCII if
        % necessary (tcpip and tcpclient transmit and receive binary data).
        % @return {char 1xm} the ASCII result
        
        function c = readAscii(this)
            
            u8Result = this.readToTerminator();
            % remove terminator
            u8Result = u8Result(1 : end - length(this.u8TerminatorRead));
            % convert to ASCII (char)
            c = char(u8Result);
                
        end
        
    end
    
    
    methods (Access = private)
        
        % Returns a list of uint8, one for each byte of the answer
        % Returns {logical 1x1} true if bytes are read before timeout,
        % false otherwise
        function [u8Result, lSuccess] = readToTerminator(this)
            
            lTerminatorReached = false;
            u8Result = [];
            idTic = tic;
            while(~lTerminatorReached )
                if (this.comm.BytesAvailable > 0)
                    
                    cMsg = sprintf(...
                        'readToTerminator reading %u bytesAvailable', ...
                        this.comm.BytesAvailable ...
                    );
                    this.msg(cMsg);
                    % Append available bytes to previously read bytes
                    
                    % {uint8 1xm} 
                    u8Val = read(this.comm, this.comm.BytesAvailable);
                    % {uint8 1x?}
                    u8Result = [u8Result u8Val];
                    
                    % search new data for terminator
                    % convert to ASCII and use strfind, since
                    % terminator can be multiple characters
                    
                    if contains(char(u8Val), char(this.u8TerminatorRead))
                        lTerminatorReached = true;
                    end
                end
                
                if (toc(idTic) > this.comm.Timeout)
                    
                    lSuccess = false;
                    
                    cMsg = sprintf(...
                        'Error.  readToTerminator took too long (> %1.1f sec) to reach terminator', ...
                        this.dTimeout ...
                    );
                    this.msg(cMsg);
                    return
                    
                end
            end
            
            lSuccess = true;
            
            
        end
        
        function l = hasProp(this, c)
            
            l = false;
            if ~isempty(findprop(this, c))
                l = true;
            end
            
        end
        
        function msg(this, cMsg)
            if this.lDebug
                fprintf('%s\n', cMsg);
            end
        end
        
    end
    
end

