classdef Receiver < matlab.System & matlab.system.mixin.Propagates ...
        & matlab.system.mixin.CustomIcon
    % Class for receiving samples
    % Obejct for configuring LMS7002 streaming parameters and samples
    % receiving
    
    properties (Nontunable, Logical)
       BurstMode = logical(0); % data is received in contiguous bursts
       MIMO = logical(0); % received data is multichannel
       dcControl = logical(0); % enable DC correction controls
       iqControl = logical(0); % enable IQ gain controls
       phaseControl = logical(0); % enable IQ phase offset controls
       pgaControl = logical(0); % enable PGA controls
       tiaControl = logical(0); % enable TIA controls
       freqControl = logical(0); % enable center frequency controls
    end
    
    properties (Nontunable)        
        burstLength = 680*16*10; % Single burst length in samples
        fifoLength = 5000000; % total size of internal FIFO in samples
        outputSize = 1360;  % number of samples in step output
        rxLNAselection = 1; % Rx LNA index, 0-none, 1-LNAH, 2-LNAL, 3-LNAW
        init_centerFreq_MHz = 1950; % center frequency in MHz
        channelsCount = 1;  % number of channels in MIMO mode
    end
    
    properties (Access = private)
        buffer; % buffer for storing samples received from FIFO
        active = 0;
        LibraryName = lmssdr.GetLibraryName();
        CMD_BRDSPI_WR = hex2dec('55');
        CMD_LMS7002_WR = hex2dec('21');
        CMD_LMS7002_RD = hex2dec('22');
        inputNames = {'dcControl'; 'iqControl'; 'phaseControl'; 'pgaControl'; 'tiaControl'; 'centerFreq'};
        inputEnables = [logical(0), logical(0), logical(0), logical(0), logical(0), logical(0)];
        timestamp = double(0);
        bck20 = [int16(0) int16(0)];
        bck403 = [int16(0) int16(0)];
        bck119 = [int16(0) int16(0)];
        bck113 = [int16(0) int16(0)];
        IQphaseCorrection;
        LNAgain;
        TIAgain;
        PGAgain;
        Igain;
        Qgain;
        DCoffsetI;
        DCoffsetQ;
        FIFOfill = double(0);
        paramTrig = int32(0);
        samplingRate;
        centerFreq;
        statsUpdateTime = uint64(0);
    end
        
    methods
        % Constructor
        function obj = Receiver(varargin)
            setProperties(obj,nargin,varargin{:});
        end
    end
        
    methods (Access = protected)
        function setupImpl(obj, varargin)
            if ~lmssdr.IsInitialized()
               error('Please initialize library before using Receiver. lmssdr.Initialize(refClk, mimo, fifoLen, configFile)');
            end
            obj.centerFreq = double(0);
            obj.samplingRate = int32(0);
            obj.LNAgain = [int32(0) int32(0)];
            obj.TIAgain = [int32(0) int32(0)];
            obj.PGAgain = [int32(0) int32(0)];
            obj.Igain = [int32(0) int32(0)];
            obj.Qgain = [int32(0) int32(0)];
            obj.IQphaseCorrection = [int32(0) int32(0)];
            obj.DCoffsetI = [int32(0) int32(0)];
            obj.DCoffsetQ = [int32(0) int32(0)];
            
            usbPort = calllib(obj.LibraryName,'LMS_GetUSBPort');                
            comPort = calllib(obj.LibraryName,'LMS_GetCOMPort');
            disp(sprintf('Setting Rx frequency to %f MHz', obj.init_centerFreq_MHz));
            calllib(obj.LibraryName,'LMS_SetCenterFrequencyRx', comPort, obj.init_centerFreq_MHz);
            
            obj.bck20 = lmssdr.ReadSPI16(comPort, obj.CMD_LMS7002_RD, hex2dec('20'));
            obj.bck20 = bitand( obj.bck20, hex2dec('FFFC'));
            for i=1:obj.channelsCount
                lmssdr.WriteSPI16(comPort, obj.CMD_LMS7002_WR, hex2dec('20'), bitor(obj.bck20, i));

                obj.bck403(i) = int16(lmssdr.ReadSPI16(comPort, obj.CMD_LMS7002_RD, hex2dec('403')));
                obj.bck403(i) = bitand(int32(obj.bck403(i)), hex2dec('F000'));

                obj.bck119(i) = int16(lmssdr.ReadSPI16(comPort, obj.CMD_LMS7002_RD, hex2dec('119')));
                obj.bck119(i) = bitand(int32(obj.bck119(i)), hex2dec('FFE0'));

                obj.bck113(i) = int16(lmssdr.ReadSPI16(comPort, obj.CMD_LMS7002_RD, hex2dec('113')));
                obj.bck113(i) = bitand(int32(obj.bck113(i)), hex2dec('FFFC'));
            end
            reg10D = bitand(lmssdr.ReadSPI16(comPort, obj.CMD_LMS7002_RD, hex2dec('10D')), hex2dec('fe79'));
            lnaVal = int32(bitand(obj.rxLNAselection, 3));
            lnaVal = bitshift(lnaVal, 7);
            lnaVal = bitor(lnaVal, int32(reg10D));
            switch obj.rxLNAselection
                case 1 %LNAH
                    lnaVal = bitor(int32(reg10D), hex2dec('6'));
                case 2 %LNAL
                    lnaVal = bitor(int32(reg10D), hex2dec('2'));
                case 3 %LNAW
                    lnaVal = bitor(int32(reg10D), hex2dec('4'));
            end
            lmssdr.WriteSPI16(comPort, obj.CMD_LMS7002_WR, hex2dec('10D'), lnaVal);
            
            calllib(obj.LibraryName,'LMS_RxStop'); %stops receiver thread if it was already running
            obj.active = 0;
            lmssdr.WriteSPI16(usbPort, obj.CMD_BRDSPI_WR, 5, 14);
            obj.statsUpdateTime = tic;
        end
        
        function releaseImpl(obj)
            calllib(obj.LibraryName,'LMS_RxStop'); %stops receiver thread if it was already running          
        end
        
        function [complex_samples, timestamp, FIFOusage, samplerate] = stepImpl(obj, varargin)
            %start Rx thread on the first step to prevent filling FIFO
            %and losing samples before before the first step
            if ~obj.active
                calllib(obj.LibraryName,'LMS_RxStart', obj.BurstMode, obj.burstLength); %starts receiver thread
                obj.active = 1;
            end
            
            RxTimeStamp = uint64(0);
            RxTimeStampPtr = libpointer('uint64Ptr', RxTimeStamp);
            
            bufferPtr = libpointer('int16Ptr', obj.buffer);
            [samplesReceived, obj.buffer, RxTimeStamp] = calllib(obj.LibraryName,'LMS_TRxRead_matlab', bufferPtr, obj.outputSize, obj.channelsCount, RxTimeStampPtr, int32(1000));
            
            obj.buffer = reshape(obj.buffer, [obj.outputSize*2, obj.channelsCount]);
            complex_samples = complex( double(obj.buffer(1:2:end, :)), double(obj.buffer(2:2:end, :)));
            
            obj.timestamp = int64(RxTimeStamp);
            timestamp = double(obj.timestamp);
            
            if nargin > 1                
                if varargin{nargin-1} == 1 && obj.paramTrig == 0 %check for rising edge                    
                    comPort = calllib(obj.LibraryName,'LMS_GetCOMPort');
                    addresses = [];
                    values = [];
                    for ch=1:obj.channelsCount
                        inputIndex = 1;
                        addresses = [addresses hex2dec('20')];
                        values = [values hex2dec('FFFC')+ch];
                        if obj.inputEnables(1)
                             obj.DCoffsetI(ch) = int32(real(varargin{inputIndex}(ch)));
                             obj.DCoffsetQ(ch) = int32(imag(varargin{inputIndex}(ch)));

                             rxDCoffset = int32(complex(obj.DCoffsetI(ch), obj.DCoffsetQ(ch)));
                             isig = sign(real(rxDCoffset));
                             iOffsetValue = bitshift(int32(isig < 0), int8(6));
                             iOffsetValue = bitor(iOffsetValue, abs(real(int32(rxDCoffset))));
                             qOffsetValue = bitshift(int32(sign(imag(rxDCoffset)) < 0), 6);
                             qOffsetValue = bitor(qOffsetValue, abs(imag(int32(rxDCoffset))));                
                             iqOffsetValue = bitor(bitshift(int32(iOffsetValue), 7), qOffsetValue);                             

                             addresses = [addresses hex2dec('010E')];
                             values = [values iqOffsetValue];
                             inputIndex = inputIndex + 1;
                        end
                        if obj.inputEnables(2)
                            obj.Igain(ch) = int32(real(varargin{inputIndex}(ch)));
                            obj.Qgain(ch) = int32(imag(varargin{inputIndex}(ch)));
                            addresses = [addresses hex2dec('0401')];
                            values = [values bitand(obj.Qgain(ch), hex2dec('7FF'))];
                            addresses = [addresses hex2dec('0402')];
                            values = [values bitand(obj.Igain(ch), hex2dec('7FF'))];
                            inputIndex = inputIndex + 1;
                        end
                        if obj.inputEnables(3)
                            obj.IQphaseCorrection(ch) = int32(varargin{inputIndex}(ch));
                            addresses = [addresses hex2dec('0403')];
                            values = [values bitor(int32(obj.bck403(ch)), bitand(hex2dec('FFF'), obj.IQphaseCorrection(ch)))];
                            inputIndex = inputIndex + 1;
                        end
                        if obj.inputEnables(4)
                            obj.PGAgain(ch) = int32(varargin{inputIndex}(ch));
                            addresses = [addresses hex2dec('119')];
                            values = [values bitor(int32(obj.bck119(ch)), bitand(hex2dec('1F'), obj.PGAgain(ch)))];
                            inputIndex = inputIndex + 1;
                        end
                        if obj.inputEnables(5)
                            obj.TIAgain(ch) = int32(varargin{inputIndex}(ch));
                            addresses = [addresses hex2dec('113')];
                            values = [values bitor(int32(obj.bck113(ch)), bitand(hex2dec('3'), obj.TIAgain(ch)))];
                            inputIndex = inputIndex + 1;
                        end
                        if obj.inputEnables(6)
                            obj.centerFreq = int32(varargin{inputIndex});
                            calllib(obj.LibraryName,'LMS_SetCenterFrequencyRx', comPort, obj.centerFreq);
                            inputIndex = inputIndex + 1;
                        end
                    end
                    lmssdr.WriteSPI16(comPort, obj.CMD_LMS7002_WR, addresses, values);
                end
                obj.paramTrig = int32(varargin{nargin-1});
            end
            
            if toc(obj.statsUpdateTime) >= 1
                %variables for retrieving Buffers status
                RxRate = uint32(0);
                RxRatePtr = libpointer('uint32Ptr', RxRate);
                RxBufSize = uint32(0);
                RxBufSizePtr = libpointer('uint32Ptr', RxBufSize);
                RxBufFilled = uint32(0);
                RxBufFilledPtr = libpointer('uint32Ptr', RxBufFilled);
                TxRate = uint32(0);
                TxRatePtr = libpointer('uint32Ptr', TxRate);
                TxBufSize = uint32(0);
                TxBufSizePtr = libpointer('uint32Ptr', TxBufSize);
                TxBufFilled = uint32(0);
                TxBufFilledPtr = libpointer('uint32Ptr', TxBufFilled);
                [RxBufSize, RxBufFilled, RxRate, TxBufSize, TxBufFilled, TxRate] = calllib(obj.LibraryName,'LMS_Stats', RxBufSizePtr, RxBufFilledPtr, RxRatePtr, TxBufSizePtr, TxBufFilledPtr, TxRatePtr);
                samplerate = int32(RxRate);
                obj.samplingRate = samplerate;
                FIFOusage = double(100*double(RxBufFilled)/double(RxBufSize));
                obj.FIFOfill = FIFOusage;
                obj.statsUpdateTime = tic;
            else
                samplerate = obj.samplingRate;
                FIFOusage = obj.FIFOfill;
            end
        end
        
        function resetImpl(obj)
           obj.IQphaseCorrection = [int32(0) int32(0)];
           obj.FIFOfill = double(0);
           obj.samplingRate = int32(0);
           obj.timestamp = int64(0);
           obj.buffer = int16(zeros(obj.outputSize*2*obj.channelsCount, 1));
        end
        
        %% Backup/restore functions
        function s = saveObjectImpl(obj)
            % Save private, protected, or state properties in a
            % structure s. This is necessary to support Simulink
            % features, such as SimState.
        end
        
        function loadObjectImpl(obj,s,wasLocked)
            % Read private, protected, or state properties from
            % the structure s and assign it to the object obj.
        end
        
        %% Simulink functions
        function flag = isInputSizeLockedImpl(~,~)
            flag = true;
        end
        
       function num = getNumInputsImpl(obj)
           if obj.dcControl == true, obj.inputEnables(1)=true; end;
           if obj.iqControl == true, obj.inputEnables(2)=true; end;
           if obj.phaseControl == true, obj.inputEnables(3)=true; end;
           if obj.pgaControl == true, obj.inputEnables(4)=true; end;
           if obj.tiaControl == true, obj.inputEnables(5)=true; end;
           if obj.freqControl == true, obj.inputEnables(6)=true; end;
           num = 0;
           for i=1:length(obj.inputEnables)
              if obj.inputEnables(i) == true
                 num = num+1; 
              end
           end
           if num > 0
               num = num+1;
           end
        end
        
        function varargout = getInputNamesImpl(obj)
            varargout = cell(1, getNumInputs(obj));
            index = 1;
            for i=1:length(obj.inputEnables)
                if obj.inputEnables(i)
                   varargout{index} = obj.inputNames{i};
                   index = index + 1;
                end
            end
            if index > 1
                varargout{index} = 'setConfig';
            end
        end
        
        function varargout = isOutputFixedSizeImpl(obj,~)
            varargout = cell(1, getNumOutputs(obj));
            for i=1:getNumOutputs(obj);
                varargout{i} = true;
            end
        end
        
        function varargout = isOutputComplexImpl(obj,~)
            varargout = cell(1, getNumOutputs(obj));
            varargout{1} = true;
            for i=2:getNumOutputs(obj);
                varargout{i} = false;
            end
        end
        
        function varargout = getOutputSizeImpl(obj)
            varargout = cell(1, getNumOutputs(obj));
            if(obj.MIMO)
                varargout{1} = [obj.outputSize 2];
                %obj.channelsCount = 2;
            else
                varargout{1} = [obj.outputSize 1];
                %obj.channelsCount = 1;
            end
            for i=2:getNumOutputs(obj);
                varargout{i} = 1;
            end
        end
        
        function icon = getIconImpl(~)
            % Define a string as the icon for the System block in Simulink.
            icon = mfilename('class');
        end
        
        function varargout = getOutputDataTypeImpl(obj)
            varargout = cell(1, getNumOutputs(obj));
            varargout{1} = 'double';
            varargout{2} = 'double';
            varargout{3} = 'double';
            varargout{4} = 'int32';			
        end
        
    
    end
    
    methods(Static, Access = protected)
        %% Simulink customization functions
        function header = getHeaderImpl(obj)
            % Define header for the System block dialog box.
            header = matlab.system.display.Header(mfilename('class'));
        end
        
        function group = getPropertyGroupsImpl(obj)
            % Define section for properties in System block dialog box.
            group = matlab.system.display.Section(mfilename('class'));
        end
    end
end
