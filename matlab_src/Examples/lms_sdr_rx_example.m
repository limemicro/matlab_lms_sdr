
function lms_sdr_rx_example

terminateObj = onCleanup(@Terminate);

%Rx/Tx buffers length in samples to be allocated
InternalBuffersLength = 1536000*2;
MIMO_enabled = true;
if MIMO_enabled
    baseConfigFile = 'rx_mimo_RF.ini';
else
    baseConfigFile = 'rx_siso_RF.ini';
end

boardRefClkMHz = 52;
if ~lmssdr.Initialize(boardRefClkMHz, MIMO_enabled, InternalBuffersLength, baseConfigFile)
    disp('failed to initialize LMS SDR');
    return
end

%create Receiver
rx = lmssdr.Receiver();

%configure receiver parameters
rx.MIMO = MIMO_enabled;
if MIMO_enabled
    rx.channelsCount = 2;
else
    rx.channelsCount = 1;
end

%produces periodic bursts of contiguous samples
rx.BurstMode = true;
%realtime stream of samples, PC must be able to keep up or samples will be lost
%rx.BurstMode = false; 

%set number of samples to output each step
rx.outputSize = 1360*16;

%set center frequency of the receiver
rx.init_centerFreq_MHz = 1950;

disp('Press CTRL+C to stop');

processSamples = true;
displayTimer = tic;
while processSamples        
    %read samples from board
    [complex_samples, timestamp, fifoUsage, samplerate] = rx.step();
    
    if toc(displayTimer) > 1 % update each second
        if rx.BurstMode
            fprintf('Burst Mode | Rx sampling: ~%i Hz | Rx FIFO; %.1f%%\n', samplerate, fifoUsage);
        else
            fprintf('Rx sampling: ~%i Hz | Rx FIFO; %.1f%%\n', samplerate, fifoUsage);
            if fifoUsage > 99, disp('Rx FIFO should not be full, might be losing samples'); end
        end
        displayTimer = tic;
    end
    
    %draw received data
    if samplerate ~= 0
        nyquist = samplerate/2;
    else
        nyquist = 1;
    end
    %plots incoming signal and calculates FFT
    DisplaySignal(complex_samples, nyquist, 1, timestamp);
end

function Terminate()
    processSamples = false;
    %stop Rx
    rx.release();
    %closes devices, unloads memory
    lmssdr.Release();
end

disp('done');
end