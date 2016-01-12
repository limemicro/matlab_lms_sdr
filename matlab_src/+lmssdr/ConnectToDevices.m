function ConnectToDevices()
    % Enumerates connected devices and instructs user to select devices
    LibraryName = lmssdr.GetLibraryName();
    comPort = calllib(LibraryName,'LMS_GetCOMPort');
    deviceCount = calllib(LibraryName,'LMS_UpdateDeviceList', comPort);
    if deviceCount == 0
        disp('No connected devices found');
        return;
    end
    disp('Listing available devices:');
    for i=0:deviceCount
        disp( calllib(LibraryName,'LMS_GetDeviceName', comPort, i));
    end
    deviceIndex = str2double(input('Select LMS7002M device: ','s'));
    status = calllib(LibraryName,'LMS_DeviceOpen', comPort, deviceIndex);
    if status ~= 0
        devName = calllib(LibraryName,'LMS_GetDeviceName', comPort, deviceIndex);
        error('Unable to connect to %s', devName);
    end
    
    usbPort = calllib(LibraryName,'LMS_GetUSBPort');
    deviceCount = calllib(LibraryName,'LMS_UpdateDeviceList', usbPort);
    if deviceCount == 0
        disp('No connected usb devices found');
        %return;
    end
    disp('Listing available devices:');
    for i=0:deviceCount
        disp( calllib(LibraryName,'LMS_GetDeviceName', usbPort, i));
    end
    deviceIndex = str2double(input('Select RF samples device: ','s'));
    status = calllib(LibraryName,'LMS_DeviceOpen', usbPort, deviceIndex);
    if  status ~= 0
        devName = calllib(LibraryName,'LMS_GetDeviceName', usbPort, deviceIndex);
        error('Unable to connect to %s', devName);
    end
end