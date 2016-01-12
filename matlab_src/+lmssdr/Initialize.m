function initialized = Initialize(refClkMHz, MIMO, fifoLengthInSamples, baseConfigurationFilename)
% Allocates receiver and transmitter buffers, configures chip parameters
% for data buffers, and configures LMS7002 chip with base configuration
    LibraryName = lmssdr.GetLibraryName();
    lmssdr.checkLibrary();
    initStatus = calllib(LibraryName,'LMS_IsInitialized');
    if initStatus == 0
        lmssdr.ConnectToDevices()
        channelsCount = 1;
        if MIMO
            channelsCount = 2;
        end
        calllib(LibraryName,'LMS_Init', refClkMHz, 0, fifoLengthInSamples, channelsCount); %sets internal buffers size, clears old samples
        disp('loading base configuration file');
        if length(baseConfigurationFilename) > 0
            if calllib(LibraryName,'LMS_LoadConfigurationFile', baseConfigurationFilename) == 0
               disp('Configuration file loaded successfully');
            else
               initialized = false;
               error('FAILED to load Configuration file');
            end
        end
        initialized = true;
    else
        initialized = true;
    end
end