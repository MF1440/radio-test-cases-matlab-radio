classdef WaveformAnalyzer < handle
    %% Описание класса
    %
    % 1. Класс читает данные (во временной области) на выходе OFDM модулятора сигнала, а также информацию о параметрах формирователя
    %
    % 2. Строит метрики: спектральная плотность мощности в частотной области, графическое представление созвездия на комплексной плоскости,
    % среднеквадратичное значение модуля вектора ошибки (EVM)
    %
    % Входные данные:
    %
    % waveformSource - массив содержащий отчеты baseband сигнала во временной области на выходе OFDM модулятора
    %
    % waveformInfo - структура с параметрами OFDM модулятора и пейлоуда:
    %       Nfft               - кол-во спектрально-временных отчетов дискретного преобразования Фурье
    %       SampleRate         - частота семплирования [Гц]
    %       CyclicPrefixLengths/SymbolLengths - длины циклического преффикса и OFDM символов [кол-во временных отчетов]
    %       SymbolsCount       - кол-во символов на слот радиокадра
    %       subCarriersCount   - кол-во поднесущих
    %       payloadSymbols     - информационные символы
    %       payloadSymbolsIdxs - индексы ресурсных элементов отведенные для передачи payloadSymbols
    %
    % Поля класса:
    %
    %       rmsEvm            - среднеквадратичное значение модуля вектора ошибки
    %       waveformMeanPower - среднеквадратичное значение мощности сигнала
    %       channelBandwidth  - ширина полосы канала
    %       noiseMeanPower    - среднеквадратичное значение мощности шума
    %       modulationType    - тип модуляционной схемы
    %       waveformDuration  - длина анализируемого сигнала
    %
    
    properties
        fftCount
        sampleRate
        cyclicPrefixLengthArray
        symbolLengthArray
        windowing
        symbolPhaseArray
        symbolPerSlotArray
        symbolsCount
        payloadSymbolArray
        subcarriersCount
        payloadSymbolsIdxArray
        
        waveformArray
        
        payloadConstellationArray
        powerSpectrumDensity
        rmsEvm
        waveformMeanPower
        channelBandwidth
        noiseMeanPower
        modulationType
        waveformDuration
        dopplerShift
        constellationGrid
    end
    
    methods
        function this = WaveformAnalyzer(waveformInfo, waveformSource)
            % Конструктор класса. Чтение waveform-ы во временной области и структуры с информацией
            % необходимой для дальнейшей обработки данных и заполнения полей класса
            
            this.fftCount = waveformInfo.Nfft;
            this.sampleRate = waveformInfo.SampleRate;
            this.cyclicPrefixLengthArray = waveformInfo.CyclicPrefixLengths;
            this.symbolLengthArray = waveformInfo.SymbolLengths;
            this.windowing = waveformInfo.Windowing;
            this.symbolPhaseArray = waveformInfo.SymbolPhases;
            this.symbolPerSlotArray = waveformInfo.SymbolsPerSlot;
            this.symbolsCount = waveformInfo.symbolsCount;
            this.payloadSymbolArray = waveformInfo.payloadSymbols;
            this.subcarriersCount = waveformInfo.subCarriersCount;
            this.payloadSymbolsIdxArray = waveformInfo.payloadSymbolsIdxs;
            
            this.waveformArray = waveformSource;
            
            switch waveformInfo.modulationType
                case 'BPSK'
                    % TODO:
                case 'QPSK'
                    % TODO:
                case 'QAM-16'
                    % TODO:
                case 'QAM-64'
                    this.modulationType = waveformInfo.modulationType;
                    this.constellationGrid = [-7,-5,-3,-1,1,3,5,7] / sqrt(42);
                case 'QAM-256'
                    % TODO:
            end
        end
        
        function calcWaveformParameters(this)
            this.calcWaveformDuration();
            
            this.calcChannelBandwidth();
            
            this.calcDopplerShift();
            
            this.calcPowerSpectrumDensity();
            
            this.calcPayloadConstellation();
            
            this.calcWaveformMeanPower();
            
            this.calcEvmPerformance();
        end
        
        function calcWaveformDuration(this)
            waveformLength = length((this.waveformArray));
            this.waveformDuration = waveformLength / this.sampleRate;
        end
        
        function calcChannelBandwidth(this)
            deltaF = this.sampleRate / this.fftCount;
            this.channelBandwidth = this.subcarriersCount * deltaF;
        end
        
        function calcDopplerShift(this)
            offset = 0;
            averageVectorPhaseShiftPerSymbol = complex(0, 0);
            windowingOffset = this.windowing / 2;
            for symbolIdx = 1:this.symbolsCount
                leftPrefixIdx = offset + windowingOffset + 1;
                rightPrefixIdx = offset + this.cyclicPrefixLengthArray(symbolIdx) - windowingOffset;
                prefixData = this.waveformArray(leftPrefixIdx:rightPrefixIdx);
                
                leftSuffixIdx = leftPrefixIdx + this.fftCount;
                rightSuffixIdx = rightPrefixIdx + this.fftCount;
                suffixData = this.waveformArray(leftSuffixIdx:rightSuffixIdx);
                
                currentVectorPhaseShiftPerSymbol = sum(suffixData .* conj(prefixData));
                averageVectorPhaseShiftPerSymbol = averageVectorPhaseShiftPerSymbol + currentVectorPhaseShiftPerSymbol;
                
                offset = offset + this.symbolLengthArray(symbolIdx);
            end
            
            tau = this.fftCount / this.sampleRate;
            this.dopplerShift = angle(averageVectorPhaseShiftPerSymbol) / (2 * pi * tau);
        end
        
        function calcPowerSpectrumDensity(this)
            %             [pxx, f] = pwelch(this.waveformArray, [], [], [], this.sampleRate);
            waveformFft = fftshift(fft(this.waveformArray) / (sqrt(2 * pi) * this.sampleRate));
            waveformFftAbs2 = abs(waveformFft).^2;
            this.powerSpectrumDensity = waveformFftAbs2 / this.waveformDuration;
        end
        
        function plotPowerSpectrumDensity(this)
            waveformLength = length(this.waveformArray);
            waveformLengthDiv2 = waveformLength / 2;
            deltaF = this.sampleRate / waveformLength;
            xArray = (-waveformLengthDiv2:(waveformLengthDiv2-1)) * deltaF;
            yArray = 10 * log10(this.powerSpectrumDensity);
            figure; plot(xArray, yArray);
            title('Power Spectrum Density Plot')
            xlabel('Frequency, Hz')
            ylabel('PSD, dB/Hz')
        end
        
        function calcPayloadConstellation(this)
            deltaPhase = this.dopplerShift / this.sampleRate ;
            offsetWaveform = 0;
            leftDemodulatedIdx = (this.fftCount - this.subcarriersCount) / 2 + 1;
            rightDemodulatedIdx = leftDemodulatedIdx + this.subcarriersCount - 1;
            
            constellationArray = zeros(1, this.subcarriersCount * this.symbolsCount);
            previousPhase = 0;
            
            idxPayload = 1;
            
            for symbolIdx = 1:this.symbolsCount
                currentPhaseArray = previousPhase - 2 * pi * deltaPhase * (0:(this.symbolLengthArray(symbolIdx)-1));
                correctedSymbol = this.waveformArray(offsetWaveform + (1:this.symbolLengthArray(symbolIdx))) ...
                    .* exp(1i * currentPhaseArray).'...
                    .* exp(1i * 2 * pi * -this.symbolPhaseArray(symbolIdx));
                offsetWaveform = offsetWaveform + this.symbolLengthArray(symbolIdx);
                
                demodulatedSymbol = ofdmdemod(correctedSymbol, this.fftCount, this.cyclicPrefixLengthArray(symbolIdx), this.windowing/2);
                demodulatedSymbol = demodulatedSymbol(leftDemodulatedIdx:rightDemodulatedIdx).';
                
                %%
                rotatedSymbol = [];
                for i = 1:length(demodulatedSymbol)
                    if ((symbolIdx - 1) * this.subcarriersCount + i) == this.payloadSymbolsIdxArray(idxPayload)
                        softDecision = demodulatedSymbol(i);
                        compareRe = abs(this.constellationGrid - real(softDecision));
                        compareIm = abs(this.constellationGrid - imag(softDecision));
                        [~, idxRe] = min(compareRe);
                        [~, idxIm] = min(compareIm);
                        rotVal = complex(this.constellationGrid(idxRe), this.constellationGrid(idxIm));
                        rotatedSymbol = [rotatedSymbol softDecision*conj(rotVal)];
                        idxPayload = idxPayload + 1;
                    end
                end
                
                averageRotVectorShift = sum(rotatedSymbol);
                constellationPhase = angle(averageRotVectorShift);
                previousPhase = currentPhaseArray(end) - constellationPhase;
                
                %%
                leftSubcarrierIdx = (symbolIdx - 1) * this.subcarriersCount + 1;
                rightSubcarrierIdx = leftSubcarrierIdx + this.subcarriersCount - 1;
                constellationArray(leftSubcarrierIdx:rightSubcarrierIdx) = demodulatedSymbol*exp(-1i*constellationPhase);
            end
            
            this.payloadConstellationArray = constellationArray(this.payloadSymbolsIdxArray);
        end
        
        function plotPayloadConstellation(this)
            scatterplot(this.payloadConstellationArray);
            title('Payload Constellation Array Plot')
        end
        
        function calcWaveformMeanPower(this)
            waveformPower = abs(this.waveformArray).^2;
            this.waveformMeanPower = sum(waveformPower) / length(this.waveformArray);
        end
        
        function calcEvmPerformance(this)
            err = 0;
            for i = 1:length(this.payloadConstellationArray)
                softDecision = this.payloadConstellationArray(i);
                errRe = min(abs(this.constellationGrid - real(softDecision)));
                errIm = min(abs(this.constellationGrid - imag(softDecision)));
                err = err + (errRe^2 + errIm^2);
            end
            
            this.rmsEvm = sqrt(err / length(this.payloadConstellationArray));  
        end
    end
end