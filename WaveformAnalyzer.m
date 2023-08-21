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
        rmsEvm
        waveformMeanPower
        channelBandwidth
        noiseMeanPower
        modulationType
        waveformDuration
        dopplerShift
        
        rxWaveform
        waveformInfo
        waveformLength
    end

    methods
        function this = WaveformAnalyzer(rxWaveform, waveformInfo)
            % Конструктор класса. Чтение waveform-ы во временной области и структуры с информацией
            % необходимой для дальнейшей обработки данных и заполнения полей класса
            this.rxWaveform = rxWaveform;
            this.waveformInfo = waveformInfo;
            this.calcWaveformParameters();
        end

        function calcWaveformParameters(this)
            % Расчёт основных параметров класса
            this.waveformLength = sum(this.waveformInfo.SymbolLengths);
            this.channelBandwidth = this.waveformInfo.SampleRate;
            this.waveformMeanPower = mean(abs(this.rxWaveform) .^ 2);
            this.waveformDuration = this.waveformLength / this.channelBandwidth;
        end

        function calcDopplerShift(this, desired)
            % Расчёт доплеровского сдвига на основе кросс-корреляционной
            % функции полученного сигнала и ожидаемоего сигнала
            absXCorrSequence = abs(xcorr(fft(this.rxWaveform),fft(desired)));
            [maxXCorrSequence, idxXCorrSequence] = max(absXCorrSequence);
            this.dopplerShift = (this.waveformLength - idxXCorrSequence) / this.waveformDuration;
        end

        function plotPowerSpectrumDensity(this)
            % Построение графика PSD
            powerSpectrumArray = abs(fftshift(fft(this.rxWaveform))) .^ 2 ...
                / (this.waveformLength*this.channelBandwidth);
            powerSpectrumArraydB = 10 * log10 (powerSpectrumArray);
            powerSpectrumXAxis = ( - this.waveformLength / 2 : this.waveformLength / 2 - 1) ...
                / this.waveformDuration;
            plot(powerSpectrumXAxis, powerSpectrumArraydB);
            xlim(powerSpectrumXAxis([1, end]));
            hold off;
            title('Power Spectrum Density');
            xlabel('Frequency, Hz');
            ylabel('Power, dB/Hz');
            xticks('auto');
            yticks('auto');
            grid on
        end

        function plotPayloadConstellation(this)

        end

        function calcEvmPerformance(this)

        end
    end
end