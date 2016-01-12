% Writes given value to selected address register
% port - pointer to communications port received from library
% command - LMS64C protocol command
% addresses - maximumum number of addreses 28
% values - maximumum number of values 28
% returns operation status, 0-success, 1-failure
function opStatus = WriteSPI16(port, command, addresses, values)
	LibraryName = lmssdr.GetLibraryName();
    if ~lmssdr.IsInitialized()
        opstatus = 1;
        return;
    end
    if length(addresses) > 28
        error('WriteSPI16: buffer too long');
    end
    dataBuffer = uint8(zeros(64, 1));
    dataBuffer(1) = command;
    dataBuffer(3) = length(addresses); %one pair of address, value
    for i=1:length(addresses)
        dataBuffer(9+(i-1)*4) = uint8(addresses(i)/256);
        dataBuffer(10+(i-1)*4) = uint8(mod(addresses(i), 256));
        dataBuffer(11+(i-1)*4) = uint8(values(i)/256);
        dataBuffer(12+(i-1)*4) = uint8(mod(values(i), 256));
    end
    bytesWritten = int32(0);
    bytesWritten = calllib(LibraryName, 'LMS_ControlWrite', port, dataBuffer, 64);
    if(bytesWritten ~= 64)
        opStatus = 1; return;
    end
    bytesRead = int32(0);
    [bytesRead, ~, dataBuffer] = calllib(LibraryName, 'LMS_ControlRead', port, dataBuffer, 64);
    if(dataBuffer(3) == 1 && bytesRead == 64)
        opStatus = 0; return;
    else
        opStatus = 1; return;
    end
end 