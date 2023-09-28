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
    end
    
    properties (Access = private)
       waveformInfo
       waveformSource
    end

    methods
        function this = WaveformAnalyzer()
            % Конструктор класса. Чтение waveform-ы во временной области и структуры с информацией
            % необходимой для дальнейшей обработки данных и заполнения полей класса
            this.waveformInfo = load('waveform\waveformInfo.mat').info;
            this.waveformSource = load('waveform\waveformSource.mat').rxWaveform;
        end

        function calcWaveformParameters(this)
            this.waveformDuration = length(this.waveformSource) / this.waveformInfo.SampleRate; % s
            this.waveformMeanPower = mean( this.waveformSource .* conj(this.waveformSource) );
            I = real(this.waveformInfo.payloadSymbols);
            Q = imag(this.waveformInfo.payloadSymbols);
            dI = 2*min(abs(I)); % grid I step
            dQ = 2*min(abs(Q)); % grid Q step
            N = floor((max(I) - min(I))/dI + 0.5) + 1;
            M = floor((max(Q) - min(Q))/dQ + 0.5) + 1;
            this.modulationType = N*M; % only for QAM-X (rectangle grid)
            this.channelBandwidth = this.waveformInfo.Nfft/this.waveformDuration; % N * frequency step, Hz
        end

        function calcDopplerShift

        end

        function plotPowerSpectrumDensity(this)

        end

        function plotPayloadConstellation(this)

        end

        function calcEvmPerformance(this)

        end
    end
end
