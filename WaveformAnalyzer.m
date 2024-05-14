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
        dopplershift
        % дополнительные поля
        waveformSource
        waveformInfo
    end

    methods
        function this = WaveformAnalyzer(waveformSource, waveformInfo)
            % Конструктор класса. Чтение waveform-ы во временной области и структуры с информацией
            % необходимой для дальнейшей обработки данных и заполнения 
            % полей класса
            this.waveformSource = waveformSource;
            this.waveformInfo = waveformInfo;
        end

        function calcWaveformParameters(this)
            % подсчет среднеквадратического значения мощности
            powerVec = real(this.waveformSource).^2 + imag(this.waveformSource).^2;
            this.waveformMeanPower = sqrt(mean(powerVec.^2));
            % определение типа модуляции
            this.modulationType = unique(this.waveformInfo.payloadSymbols);
            % длительность waveform
            T = 1/this.waveformInfo.SampleRate;
            this.waveformDuration = length(this.waveformSource)*T;
        end

        function calcdopplerSHift

        end

        function plotPowerSpectrumDensity(this)
            spectrum = fftshift(fft(this.waveformSource));
            N = length(this.waveformSource);
            freq = (-N/2:N/2-1)/N;
            figure
            plot(freq,10*log10(abs(spectrum).^2))
            grid on
            title('Power spuctrum density of QPSK modulated signal');
            xlabel('frequency');
            ylabel('10*log10(power)');
        end

        function plotPayloadConstellation(this)
            figure
            plot(this.waveformInfo.payloadSymbols, 'o')
            title('Payload constellation');
            xlabel('I');
            ylabel('Q');
        end

        function calcEvmPerformance(this)

        end
    end
end