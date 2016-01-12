% Reads register value from selected address
% port - pointer to communications port received from library
% command - LMS64C protocol command
% returns operation status, 0-success, 1-failure
function [value, opStatus] = ReadSPI16(port, command, addresses)
	LibraryName = lmssdr.GetLibraryName();
    if ~lmssdr.IsInitialized()
        opstatus = 1;
        return;
    end
    if length(addresses) > 28
        error('WriteSPI16: buffer too long');
    end
    value = 0;
    dataBuffer = uint8(zeros(1, 64));
    rxdataBuffer = uint8(zeros(1, 64));
    dataBuffer(1) = command;
    dataBuffer(3) = 1; %one pair of address, value
    dataBuffer(9) = uint8(addresses/256);
    dataBuffer(10) = uint8(mod(addresses, 256));
    bytesWritten = int32(0);
    bytesWritten = calllib(LibraryName, 'LMS_ControlWrite', port, dataBuffer, 64);
    if(bytesWritten ~= 64)
        opStatus = 1; return;
    end
    bytesRead = int32(0);
    [bytesRead, ~, rxdataBuffer] = calllib(LibraryName, 'LMS_ControlRead', port, rxdataBuffer, 64);
    if(rxdataBuffer(2) == 1 && bytesRead == 64)
        value = uint16(rxdataBuffer(11)) * 256 + uint16(rxdataBuffer(12));
        opStatus = 0; return;
    else
        opStatus = 1; return;
    end
end