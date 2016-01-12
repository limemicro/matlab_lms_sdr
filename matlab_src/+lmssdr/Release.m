function Release()
    % Frees allocated memory and unloads DLL
    LibraryName = lmssdr.GetLibraryName();
    if libisloaded(LibraryName)
        calllib(LibraryName,'LMS_Destroy');
        disp('DLL unloaded');
        unloadlibrary(LibraryName);
    end
end