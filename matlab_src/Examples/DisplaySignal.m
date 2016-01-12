function DisplaySignal(samples, Nyquist_Hz, figureId, Ts)
    frequencyDomain = fft(samples);
    frequencyDomain = fftshift(frequencyDomain);
    frequencyDomain = frequencyDomain/length(frequencyDomain); %normalize
    frequencyDomain = sqrt(real(frequencyDomain).^2+imag(frequencyDomain).^2);
    frequencyDomain = 20*log10(frequencyDomain) - 69.2369; % to dbFS
    
    figure(figureId);
    clf;
    subplot(2,2, 1);
    samplesToDisplayInTime = 128;
    axis([1 samplesToDisplayInTime -2048 2048]);
    hold on;grid on;
    plot(1:samplesToDisplayInTime, real(samples(1:samplesToDisplayInTime)), 'r');
    plot(1:samplesToDisplayInTime, imag(samples(1:samplesToDisplayInTime)), 'b');
    if size(samples, 2) > 1
        plot(1:samplesToDisplayInTime, real(samples(1:samplesToDisplayInTime, 2)), 'g');
        plot(1:samplesToDisplayInTime, imag(samples(1:samplesToDisplayInTime, 2)), 'k');
        legend('AI', 'AQ', 'BI', 'BQ');
    else
        legend('AI', 'AQ');
    end
    xlabel('# sample');
    title(sprintf('Time domain, timestamp=%i', Ts));

    subplot(2,2,2);    
    scatter(real(samples(:,1)), imag(samples(:,1)), '+');
    hold on;
    if size(samples, 2) > 1
        scatter(real(samples(:,2)), imag(samples(:,2)), '+');
        legend('ch. A', 'ch. B');
    else
        legend('ch. A');
    end
    axis([-2048 2048 -2048 2048]);
    grid on;    
    title('Constelation');

    subplot(2,2,[3 4]);
    
    i=double(1:length(samples));
    frequencyAxis = ones(1,length(samples));
    frequencyAxis = frequencyAxis *double(-Nyquist_Hz)+(i.*double(2*Nyquist_Hz)/length(frequencyDomain));
    
    if length(frequencyDomain) == length(frequencyAxis)
        plot(frequencyAxis, frequencyDomain);
        axis([-Nyquist_Hz Nyquist_Hz -120 0]);
        grid on;
        title(sprintf('Frequency domain, approximate sampling rate= ~%i', Nyquist_Hz*2));
        xlabel('Frequency, Hz');
        ylabel('dBFS');
        if size(samples, 2) > 1
            legend('ch. A', 'ch. B');
        else
            legend('ch. A');
        end
    end
    drawnow
end