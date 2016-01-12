function [loaded, messages] = checkLibrary()    
    %checks if the LMS SDR library is loaded, if not tries to load it
    [rootdir] = fileparts(which('lmssdr.checkLibrary')) ;
    LibraryName = lmssdr.GetLibraryName();
	if libisloaded(LibraryName)
		loaded = true;
		messages = sprintf('%s is loaded', LibraryName);
	else
		disp('Loading LMS SDR DLL...');
		if computer('arch') == 'win64'
			[notfound, warnings] = loadlibrary(sprintf('%s/libs/%s.dll', rootdir, LibraryName), sprintf('%s/libs/%s.h',rootdir, LibraryName), 'alias', LibraryName);
        else
            [notfound, warnings] = loadlibrary(sprintf('%s/libs/%sx86.dll', rootdir, LibraryName), sprintf('%s/libs/%s.h',rootdir, LibraryName), 'alias', LibraryName);
        end
        loaded = true;
	end
end