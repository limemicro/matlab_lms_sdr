classdef Transmitter < matlab.System & matlab.system.mixin.Propagates ...
        & matlab.system.mixin.CustomIcon
    % Class for transmitting samples
    % Obejct for configuring LMS7002 streaming parameters and samples
    % transmitting
    
    properties (Nontunable, Logical)
       MIMO = logical(0); % transmitted data is multichannel
       dcControl = logical(0); % enable DC offset controls
       iqControl = logical(0); % enable IQ gain controls
       phaseControl = logical(0); % enable IQ phase offset controls
       padControl = logical(0); % enable Tx PAD gain controls
       freqControl = logical(0); % enable center frequency controls
    end
    
    properties (Nontunable)        
        inputSize = 1360; % number of samples to take each step
        init_centerFreq_MHz = 1950; % transmitter center frequency
        channelsCount = 1; % number of transmitted channels
    end
    
    properties (Access = private)
        inputBuf; % buffer for forming output data
        LibraryName = lmssdr.GetLibraryName();
        CMD_BRDSPI_WR = hex2dec('55');
        CMD_LMS7002_WR = hex2dec('21');
        CMD_LMS7002_RD = hex2dec('22');
        inputNames = {'dcControl'; 'iqControl'; 'phaseControl'; 'padControl'; 'centerFreq'};
        inputEnables = [logical(0), logical(0), logical(0), logical(0), logical(0)];
        timestamp = int64(0);
        
        %backup registers for modifying bits
        bck20 = [int16(0) int16(0)];
        bck101 = [int16(0) int16(0)];
        bck203 = [int16(0) int16(0)];
        
        samplingRate;
        FIFOfill;
        centerFreq;
        PADgain;
        Igain;
        Qgain;
        IQphaseCorrection;
        DCoffsetI;
        DCoffsetQ;
        paramTrig;
        statsUpdateTime = uint64(0);
    end
    
    properties (DiscreteState)        
    end
    
    methods
        % Constructor
        function obj = Transmitter(varargin)
            setProperties(obj,nargin,varargin{:});
        end
    end
        
    methods (Access = protected)
        function setupImpl(obj, varargin)
            if ~lmssdr.IsInitialized()
               error('Please initialize library before using Transmitter. lmssdr.Initialize(refClk, mimo, fifoLen, configFile)');
            end
            obj.FIFOfill = double(0);            
            obj.timestamp = double(0);
            obj.samplingRate = int32(0);
            obj.PADgain = int32(0);
            obj.Igain = int32(0);
            obj.Qgain = int32(0);
            obj.IQphaseCorrection = int32(0);
            obj.DCoffsetI = int32(0);
            obj.DCoffsetQ = int32(0);
            obj.paramTrig = int32(0);
            
            comPort = calllib(obj.LibraryName,'LMS_GetCOMPort');
            disp(sprintf('Setting Tx frequency to %f MHz', obj.init_centerFreq_MHz));
            calllib(obj.LibraryName,'LMS_SetCenterFrequencyTx', comPort, obj.init_centerFreq_MHz);
            
            comPort = calllib(obj.LibraryName,'LMS_GetCOMPort');
            usbPort = calllib(obj.LibraryName,'LMS_GetUSBPort');
            
            %reads register values for later use to change parameters
            obj.bck20 = lmssdr.ReadSPI16(comPort, obj.CMD_LMS7002_RD, hex2dec('20'));
            obj.bck20 = bitand( obj.bck20, hex2dec('FFFC'));
            for i=1:obj.channelsCount
                lmssdr.WriteSPI16(comPort, obj.CMD_LMS7002_WR, hex2dec('20'), bitor(obj.bck20, i));

                obj.bck101(i) = int16(lmssdr.ReadSPI16(comPort, obj.CMD_LMS7002_RD, hex2dec('101')));
                obj.bck101(i) = bitand(int32(obj.bck101(i)), hex2dec('F801'));

                obj.bck203(i) = int16(lmssdr.ReadSPI16(comPort, obj.CMD_LMS7002_RD, hex2dec('203')));
                obj.bck203(i) = bitand(int32(obj.bck203(i)), hex2dec('F000'));
            end
            lmssdr.WriteSPI16(usbPort, obj.CMD_BRDSPI_WR, 5, 14);
            
            calllib(obj.LibraryName,'LMS_TxStop'); %stops receiver thread
            calllib(obj.LibraryName,'LMS_TxStart'); %starts receiver thread
            obj.statsUpdateTime = tic;
        end
        
        function releaseImpl(obj)
            calllib(obj.LibraryName,'LMS_TxStop'); %stops receiver thread if it was already running
        end
        
        function [FIFOusage, samplerate] = stepImpl(obj, complex_samples, timestamp, varargin)
            complex_samples = reshape(complex_samples,  [], 1);
            obj.inputBuf(1:2:end) = int16(real(complex_samples));
            obj.inputBuf(2:2:end) = int16(imag(complex_samples));
            txBufferPtr = libpointer('int16Ptr', obj.inputBuf);
            [samplesSent] = calllib(obj.LibraryName,'LMS_TRxWrite_matlab', txBufferPtr, obj.inputSize, obj.channelsCount, timestamp, int32(1000));
            
            if nargin > 3                
                if varargin{nargin-3} == 1 && obj.paramTrig == 0 %check for rising edge                    
                    comPort = calllib(obj.LibraryName,'LMS_GetCOMPort');
                    bufLen = nargin-3
                    addresses = [];
                    values = [];
                    for ch=1:obj.channelsCount
                        inputIndex = 1;
                        addresses = [addresses hex2dec('20')];
                        values = [values hex2dec('FFFC')+ch];
                        if obj.inputEnables(1)
                             obj.DCoffsetI(ch) = int32(real(varargin{inputIndex}(ch)));
                             obj.DCoffsetQ(ch) = int32(imag(varargin{inputIndex}(ch)));

                             iqCorrection = bishift(bitand(obj.DCOffsetI(ch), hex2dex('FF')), -8);
                             iqCorrection = bitor(iqCorrection, bitand(obj.DCOffsetQ(ch), hex2dex('FF')));
                             
                             addresses = [addresses hex2dec('010E')];
                             values = [values iqCorrection];
                             inputIndex = inputIndex + 1;
                        end
                        if obj.inputEnables(2)
                            obj.Igain(ch) = int32(real(varargin{inputIndex}(ch)));
                            obj.Qgain(ch) = int32(imag(varargin{inputIndex}(ch)));
                            addresses = [addresses hex2dec('0201')];
                            values = [values bitand(obj.Qgain(ch), hex2dec('7FF'))];
                            addresses = [addresses hex2dec('0202')];
                            values = [values bitand(obj.Igain(ch), hex2dec('7FF'))];
                            inputIndex = inputIndex + 1;
                        end
                        if obj.inputEnables(3)
                            obj.IQphaseCorrection(ch) = int32(varargin{inputIndex}(ch));
                            addresses = [addresses hex2dec('0203')];
                            values = [values bitor(int32(obj.bck203(ch)), bitand(hex2dec('FFF'), obj.IQphaseCorrection(ch)))];
                            inputIndex = inputIndex + 1;
                        end
                        if obj.inputEnables(4)
                            obj.PADgain(ch) = int32(varargin{inputIndex}(ch));
                            addresses = [addresses hex2dec('101')];
                            loss_main = bitand(hex2dec('1F'), obj.PGAgain(ch));
                            loss_lin = bitshift(loss_main, -5);
                            regValue = bitshift(bitor(loss_main, loss_lin), -1);
                            values = [values bitor(int32(obj.bck119(ch)), regValue)];
                            inputIndex = inputIndex + 1;
                        end
                        if obj.inputEnables(5)
                            obj.centerFreq = int32(varargin{inputIndex});
                            calllib(obj.LibraryName,'LMS_SetCenterFrequencyTx', comPort, obj.centerFreq);
                            inputIndex = inputIndex + 1;
                        end
                    end
                    lmssdr.WriteSPI16(comPort, obj.CMD_LMS7002_WR, addresses, values);
                end
                obj.paramTrig = int32(varargin{nargin-3});
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
                samplerate = int32(TxRate);
                obj.samplingRate = samplerate;
                FIFOusage = double(100*double(TxBufFilled)/double(TxBufSize));
                obj.FIFOfill = FIFOusage;
                obj.statsUpdateTime = tic;
            else
                samplerate = obj.samplingRate;
                FIFOusage = obj.FIFOfill;
            end
        end
        
        function resetImpl(obj)
           obj.FIFOfill = double(0);
           obj.samplingRate = int32(0);
           obj.timestamp = int64(0);
           obj.inputBuf = int16(zeros(obj.inputSize*2*obj.channelsCount, 1));
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
        
        function flag = isInputSizeLockedImpl(~,~)
            flag = true;
        end
        
       function num = getNumInputsImpl(obj)
           if obj.dcControl == true, obj.inputEnables(1)=true; end;
           if obj.iqControl == true, obj.inputEnables(2)=true; end;
           if obj.phaseControl == true, obj.inputEnables(3)=true; end;
           if obj.padControl == true, obj.inputEnables(4)=true; end;
           if obj.freqControl == true, obj.inputEnables(5)=true; end;
           num = 2;
           for i=1:length(obj.inputEnables)
              if obj.inputEnables(i) == true
                 num = num+1; 
              end
           end
           if num > 2
               num = num+1;
           end
        end
        
        function varargout = getInputNamesImpl(obj)
            varargout = cell(1, getNumInputs(obj));
            varargout{1} = 'complex_samples';
            varargout{2} = 'timestamp';
            index = 3;
            for i=1:length(obj.inputEnables)
                if obj.inputEnables(i)
                   varargout{index} = obj.inputNames{i};
                   index = index + 1;
                end
            end
            if index > 3
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
            for i=1:getNumOutputs(obj);
                varargout{i} = false;
            end
        end
        
        function varargout = getOutputSizeImpl(obj)
%             if(obj.MIMO)
%                obj.channelsCount = 2;
%             else
%                obj.channelsCount = 1;
%             end
            varargout = cell(1, getNumOutputs(obj));            
            for i=1:getNumOutputs(obj);
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
            varargout{2} = 'int32';
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
