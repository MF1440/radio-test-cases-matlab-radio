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
    %       dopplerShift      - Допплеровский сдвиг частоты

    properties
        rmsEvm
        waveformMeanPower
        channelBandwidth
        noiseMeanPower
        modulationType
        waveformDuration
        dopplerShift
    end

    properties (Access = private)
        fftSize
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
        sampleArray
    end

    methods
        function this = WaveformAnalyzer(waveformData, waveformInfo)
            % Конструктор класса. Чтение waveform-ы во временной области и структуры с информацией
            % необходимой для дальнейшей обработки данных и заполнения полей класса
            this.fftSize                    = waveformInfo.Nfft;
            this.sampleRate                 = waveformInfo.SampleRate;
            this.cyclicPrefixLengthArray    = waveformInfo.CyclicPrefixLengths;
            this.symbolLengthArray          = waveformInfo.SymbolLengths;
            this.windowing                  = waveformInfo.Windowing;
            this.symbolPhaseArray           = waveformInfo.SymbolPhases;
            this.symbolPerSlotArray         = waveformInfo.SymbolsPerSlot;
            this.symbolsCount               = waveformInfo.symbolsCount;
            this.payloadSymbolArray         = waveformInfo.payloadSymbols;
            this.subcarriersCount           = waveformInfo.subCarriersCount;
            this.payloadSymbolsIdxArray     = waveformInfo.payloadSymbolsIdxs;
            this.sampleArray                = waveformData;
        end

        function calcWaveformParameters(this)
            % Метод класса, реализующий расчет параметров сигнала.
            this.calcWaveformMeanPower();
            this.calcChannelBandwidth();
            this.calcModulationType();
            this.calcWaveformDuration();            
            this.calcDopplerShift();
            this.calcEvmPerformance();            
        end

        function plotPowerSpectrumDensity(this)
            % Метод класса, реализующий вывод спектральной плотности средней мощности в частотной области.
            
            % Преобразование Фурье сигнала
            signalFft = fftshift(fft(this.sampleArray));
            % Вычисление спектральной плотности мощности
            powerDensity = 10*log10(abs(signalFft).^2); 
            % Формирование частотной сетки
            sampleLength = length(this.sampleArray);
            freqArray = (-sampleLength/2:sampleLength/2-1)*(this.sampleRate/sampleLength);
           
            plot(freqArray, powerDensity);
            title('Power Spectrum Density');
            xlabel('Frequency, MHz');
            ylabel('Power Spectrum Density, dB');
        end

        function plotPayloadConstellation(this)
            % Метод класса, реализующий вывод созвездия на комплексной плоскости.
            scatterplot(this.payloadSymbolArray);
            title('Payload Constellation');            
        end
    end

    methods(Access = private)

        function calcWaveformMeanPower(this)
            % Метод класса, реализующий расчет среднеквадратичного значения мощности сигнала.
            this.waveformMeanPower = mean(abs(this.sampleArray).^2);
        end

        function calcChannelBandwidth(this)
            % Метод класса, реализующий расчет ширины полосы канала.
            subCarrierBandwidth = this.sampleRate / this.fftSize;
            this.channelBandwidth = this.subcarriersCount * subCarrierBandwidth;
        end

        function calcModulationType(this)
            % Метод класса, реализующий вычисления типа модуляционной схемы.
            % Массив проверяемых порядков модуляции
            orderArray = [2, 4, 16, 64, 256];
            % Резервируем массив средних ошибок
            errorArray = zeros(1, length(orderArray));
            for orderIdx = 1:length(orderArray)
                currentOrder = orderArray(orderIdx);
                % Генерация сетки созвездия
                constellationGrid = qammod((0:currentOrder-1)', currentOrder, 'UnitAveragePower', true);
                constellationGridRepMat = repmat(constellationGrid, 1, length(this.payloadSymbolArray))';
                % Вычисляем ошибки до каждого возможного модуляционного символа
                symbolErrorMat = abs(this.payloadSymbolArray - constellationGridRepMat);
                % Вычисляем мин ошибку для каждого информационного символа
                minErrorArray = min(symbolErrorMat, [], 2);
                % Сохраняем среднюю ошибки по всем символам
                errorArray(orderIdx) = mean(minErrorArray); 
            end
            % Определяем порядок модуляции по критерию минимума средней
            % ошибки по всем информационным символам
            [~, indMin] = min(errorArray);
            modOrder = orderArray(indMin);
            switch modOrder
                case 2
                    this.modulationType = 'BPSK';
                case 4
                    this.modulationType = 'QPSK';
                case 16
                    this.modulationType = 'QAM-16';
                case 64
                    this.modulationType = 'QAM-64';
                case 256
                    this.modulationType = 'QAM-256';
                otherwise
                    this.modulationType = 'Unknown modulation';
            end
        end

        function calcWaveformDuration(this)
            % Метод класса, реализующий расчет длины анализируемого сигнала.
            this.waveformDuration = length((this.sampleArray)) / this.sampleRate;
        end

        function calcDopplerShift(this)
            % Метод класса, реализующий расчет Допплеровского сдвига частоты.
            symbolOffset = 1;
            phaseShiftArray = zeros(this.symbolsCount, 1);
            for symbolIdx = 1:this.symbolsCount
                % Семплы текущего символа
                currentSymbol = this.sampleArray(symbolOffset:symbolOffset + this.symbolLengthArray(symbolIdx) - 1);
                % Семплы текущего префикса
                currentPrefix = currentSymbol(1:this.cyclicPrefixLengthArray(symbolIdx));
                % Вычисление набегов фазы
                phaseArray = angle(currentSymbol(end - this.cyclicPrefixLengthArray(symbolIdx) + 1 : end) .* conj(currentPrefix));
                % Вычисление набега фазы на символ с учетом windowing
                phaseShiftArray(symbolIdx) = mean(phaseArray(1:end - this.windowing));
                % Вычисление начала следующего символа
                symbolOffset = symbolOffset + this.symbolLengthArray(symbolIdx);
            end

            this.dopplerShift = mean(phaseShiftArray) * this.sampleRate / this.fftSize / (2 * pi);
        end

        function calcEvmPerformance(this)
            % Метод класса, реализующий расчет среднеквадратичное значение модуля вектора ошибки.
            
        end
    end
end
