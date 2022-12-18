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
        wfStorage

        rmsEvm
        waveformMeanPower
        channelBandwidth
        noiseMeanPower
        modulationType
        waveformDuration

        subcarrierSpacing
    end

    methods
        function this = WaveformAnalyzer(storage)
            % Here I've decided to make some architecture change
            % Since analyzer class should only analyze waveforms
            % it should not store data but only reference to storage class
            this.wfStorage = storage;
        end

        function calcWaveformParameters(this)
            this.calcMeanPower();
            this.calcChannelBandwidth();
            this.estimateModulationType();
            this.calcWaveformDuration();
        end

        function calcMeanPower(this)
            this.waveformMeanPower = ...
                                mean(abs(this.wfStorage.getSamples().^2));
        end
           
        % !TODO: check if need to divide or multiply by 2
        function calcChannelBandwidth(this)
            samplingRate = this.wfStorage.getSampleRate();
            this.subcarrierSpacing = samplingRate / this.wfStorage.getNfft();
            occupancy = this.wfStorage.getSubCarriersCount() / this.wfStorage.getNfft();
            this.channelBandwidth = samplingRate * occupancy;
        end

        % !TODO: Temporary solution!
        % Need to introduce other modulation patterns
        % PSK, QAM, APSK
        function estimateModulationType(this)
            uniquePtsCount = length(unique(this.wfStorage.getPayloadSymbols()));
            switch uniquePtsCount
                case 16
                    this.modulationType = "QAM-16";
                case 64
                    this.modulationType = "QAM64";
                otherwise
                    error("Unknown modulation type!");
            end
        end

        function calcWaveformDuration(this)
            this.waveformDuration = length(this.wfStorage.getSamples()) / this.wfStorage.getSampleRate();
        end

        function plotPowerSpectrumDensity(this)
            % plot(pow2db(abs(fftshift(fft(this.wfStorage.getSamples()))).^2));
            [Pxx, w] = pwelch(this.wfStorage.getSamples(), [], [], [],...
                              this.wfStorage.getSampleRate());
            figure;
            plot(w, pow2db(fftshift(Pxx)));
            xlabel("Frequency, Hz");
            ylabel("Power density, dB/Hz");
            grid on;
            title("Power spectral density");
        end

        function plotPayloadConstellation(this)

        end

        function calcEvmPerformance(this)

        end

        function setStorage(this, storageHandle)
            this.wfStorage = storageHandle;
        end

        function showAnalyzeResult(this)
            fprintf("Mean Power: %f\n", this.waveformMeanPower);
            fprintf("Channel Bandwidth: %f Hz\n", this.channelBandwidth);
            fprintf("Modulation Type: %s\n", this.modulationType);
            fprintf("Signal Duration: %f seconds\n", this.waveformDuration);
        end
    end
end