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

    methods
        function this = WaveformAnalyzer(info, source)
            % Конструктор класса. 
            
            % Заполнение полей класса по данным info, source
           this.calcWaveformParameters(info, source);

        end

        function calcWaveformParameters(this, info, source)
            % Расчет средней мощности
            this.waveformMeanPower = mean(abs(source).^2);
            
            % Расчет ширины канала занятого под сигнал <SampleRate
            this.channelBandwidth = info.SampleRate * info.subCarriersCount / info.Nfft;

            % Заполенение поля тип модуляции 
            this.modulationType = 'OFDM';

            % Длительность source в секундах
            this.waveformDuration = numel(source)/info.SampleRate;

        end

        function calcDopplerShift(this, centralFrequency, radialSpeed)
            % centralFrequency - центральная частота сигнала 
            % radialSpeed - радиальная скорость передатчика-приемника

            this.dopplerShift = centralFrequency *  radialSpeed / physconst('LightSpeed');
        end

        function plotPowerSpectrumDensity(this, source, sampleRate)
            [xPsd, xFreq] = pwelch(source,[],[],1024,sampleRate);

            xPsdReshRoll = circshift(xPsd, numel(xPsd)/2);
            xLog = 10*log10(xPsdReshRoll);

            % Преобразование Hz -> MHz
            if sampleRate > 1e6
                freqScaling = 1e6;
                freqScalingText = 'MHz';
            else
                freqScaling = 1;
                freqScalingText = 'Hz';
            end
                
            xFreq(xFreq>=sampleRate/2) = xFreq(xFreq>=sampleRate/2)-sampleRate; 
            xFreqRoll = circshift(xFreq, numel(xPsd)/2);
            xFreqRoll = xFreqRoll./freqScaling;
            
            plot( xFreqRoll, xLog);
            grid;
             
            xlabel(['Frequency, ', freqScalingText])
            ylabel('PSD, dB')
            title(['mean power is ', num2str(this.waveformMeanPower, 2), ...
                   ', channel bandwidth is ', num2str(this.channelBandwidth/freqScaling, 3), freqScalingText] )

        end

        function plotPayloadConstellation(this)

        end

        function calcEvmPerformance(this)

        end
    end
end