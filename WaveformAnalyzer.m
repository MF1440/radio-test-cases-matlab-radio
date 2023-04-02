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
        
        rmsEvm
        waveformMeanPower
        channelBandwidth
        noiseMeanPower
        modulationType
        waveformDuration
        dopplerShift
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
        end

        function calcWaveformParameters(this)

        end

        function calcdopplerSHift

        end

        function plotPowerSpectrumDensity(this)

        end

        function plotPayloadConstellation(this)

        end

        function calcEvmPerformance(this)

        end
    end
end