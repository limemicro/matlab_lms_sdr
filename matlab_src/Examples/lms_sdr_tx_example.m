function lms_sdr_tx_example

terminateObj = onCleanup(@Terminate);

%Rx/Tx buffers length in samples to be allocated
InternalBuffersLength = 1536000*4;
MIMO_enabled = true;
if MIMO_enabled
    baseConfigFile = 'tx_mimo.ini';
else
    baseConfigFile = 'tx_siso.ini';
end

boardRefClkMHz = 52;
if ~lmssdr.Initialize(boardRefClkMHz, MIMO_enabled, InternalBuffersLength, baseConfigFile)
    disp('failed to initialize LMS SDR');
    return
end

%create Receiver
tx = lmssdr.Transmitter();

%configure receiver parameters
tx.MIMO = MIMO_enabled;
if MIMO_enabled
    tx.channelsCount = 2;
else
    tx.channelsCount = 1;
end

%set number of samples to output each step
tx.inputSize = 1360*16*10;

%set center frequency of the receiver
tx.init_centerFreq_MHz = 2140;

disp('Press CTRL+C to stop');

processSamples = true;
timestamp = tx.inputSize; %set the first timestamp to be in future

%generate sin signal for testing
src_samples = complex(2047*cos((1:4).* pi/2), 2047*sin((1:4).* pi/2))';
complex_samples = zeros(tx.inputSize, tx.channelsCount);
displayTimer = tic;
while processSamples
    %fill A and B channel data
    complex_samples = repmat(src_samples, tx.inputSize/length(src_samples), tx.channelsCount);
    
    timestamp = timestamp + tx.inputSize;
    [fifoUsage, samplerate] = tx.step(complex_samples, timestamp);
    
    if toc(displayTimer) >= 1 % update each second
        fprintf('Tx sampling: ~%i Hz | Tx FIFO; %.1f%%\n', samplerate, fifoUsage);
        displayTimer = tic;
    end
    %if fifo has a lot of data, slow down data production
    if(fifoUsage > 75)
        pause(0.01);
    end

%     draw transmitted data
%     if samplerate ~= 0
%         nyquist = samplerate/2;
%     else
%         nyquist = 1;
%     end
%     plots incoming signal and calculates FFT
%     DisplaySignal(complex_samples, nyquist, 1, timestamp);
%     pause(0.2); %give some time to refresh plots
end

function Terminate()
    processSamples = false;
    %stop Tx
    tx.release();
    %closes devices, unloads memory
    lmssdr.Release();
end

disp('done');
end