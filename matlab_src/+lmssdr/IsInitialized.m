function initialized = IsInitialized()
    % checks if the DLL is initialized and devices are connected
    lmssdr.checkLibrary();
    if calllib(lmssdr.GetLibraryName(), 'LMS_IsInitialized')
        comPort = calllib(lmssdr.GetLibraryName(), 'LMS_GetCOMPort');
        if ~calllib(lmssdr.GetLibraryName(), 'LMS_IsDeviceOpen', comPort)
           error('COM port not connected');
           initialized = false;
        end
        usbPort = calllib(lmssdr.GetLibraryName(), 'LMS_GetUSBPort');
        if ~calllib(lmssdr.GetLibraryName(), 'LMS_IsDeviceOpen', usbPort)
           error('USB port not connected');
           initialized = false;
        end
        initialized = true;
    else
        initialized = false;
    end
end