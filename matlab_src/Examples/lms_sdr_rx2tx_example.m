function lms_sdr_rx2tx_example

terminateObj = onCleanup(@Terminate);

%Rx/Tx buffers length in samples to be allocated
InternalBuffersLength = 1536000*2;
MIMO_enabled = true;
if MIMO_enabled
    baseConfigFile = 'rx2tx_mimo.ini';
else
    baseConfigFile = 'rx2tx_siso.ini';
end

boardRefClkMHz = 52;
if ~lmssdr.Initialize(boardRefClkMHz, MIMO_enabled, InternalBuffersLength, baseConfigFile)
    disp('failed to initialize LMS SDR');
    return
end

%create Receiver
rx = lmssdr.Receiver();
tx = lmssdr.Transmitter();

%configure receiver/transmitter parameters
rx.MIMO = MIMO_enabled;
tx.MIMO = MIMO_enabled;
if MIMO_enabled
    rx.channelsCount = 2;
    tx.channelsCount = 2;
else
    rx.channelsCount = 1;
    tx.channelsCount = 1;
end

%produces periodic bursts of contiguous samples
rx.BurstMode = false;
%realtime stream of samples, PC must be able to keep up or samples will be lost
%rx.BurstMode = false; 

%set number of samples to output each step
rx.outputSize = 1360*16*10;
tx.inputSize = rx.outputSize;

%set center frequency of the receiver
rx.init_centerFreq_MHz = 1950;
tx.init_centerFreq_MHz = 2140;

disp('Press any key to stop');

processSamples = true;

%Rx to Tx delay in samples
rx2txDelay = rx.outputSize*8;
displayTimer = tic;
while processSamples
    %read samples from board
    [complex_samples, timestamp, rxfifoUsage, rxrate] = rx.step();
    
    %complex_samples can be processed in here
    
    [txfifoUsage, txrate] = tx.step(complex_samples, timestamp+rx2txDelay);
    
    if toc(displayTimer) > 1 % update each second
        fprintf('Rx sampling: ~%i Hz | Tx sampling: ~%i Hz | Rx FIFO: %.1f%% | Tx FIFO: %.1f%%\n', rxrate, txrate, rxfifoUsage, txfifoUsage);
        displayTimer = tic;
    end
    %Rx fifo should never reach 100% or samples will be lost
    if rxfifoUsage > 99
        disp('Rx FIFO should not be full, might be losing samples');
    end
%     draw received data, drawing is slow and heavily affects performance
%     if rxrate ~= 0
%         nyquist = rxrate/2;
%     else
%         nyquist = 1;
%     end
%     plots incoming signal and calculates FFT
%     DisplaySignal(complex_samples, nyquist, 1, timestamp);
%     pause(0.2); %give some time to refresh plots
end

function Terminate()
    processSamples = false;
    %stop Rx/Tx
    rx.release();
    tx.release();
    %closes devices, unloads memory
    lmssdr.Release();
end
disp('done');
end