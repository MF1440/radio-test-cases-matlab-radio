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
            % Здесь было принято решение вынести хранение WF в отдельный
            % класс
            % Класс-анализатор WF не должен хранить данные
            % Корректнее хранить данные в отдельном классе-хэндле
            % и получать их по требованию различных классов
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
                                mean(abs(this.wfStorage.getSamples()).^2);
        end
        
        function calcChannelBandwidth(this)
            samplingRate = this.wfStorage.getSampleRate();
            % this.subcarrierSpacing = samplingRate / this.wfStorage.getNfft();
            occupancy = this.wfStorage.getSubCarriersCount() / this.wfStorage.getNfft();
            this.channelBandwidth = samplingRate * occupancy;
        end

        % !TODO: Временное решение
        % Возможно, необходимо проводить анализ на разные типы модуляций
        % PSK, QAM, APSK
        function estimateModulationType(this)
            uniquePtsCount = length(unique(this.wfStorage.getPayloadSymbols()));
            switch uniquePtsCount
                case 16
                    this.modulationType = ModulationType.QAM16;
                case 64
                    this.modulationType = ModulationType.QAM64;
                case 256
                    this.modulationType = ModulationType.QAM256;
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
            plot(w ./ 1e6, pow2db(fftshift(Pxx)));
            xlabel("Frequency, MHz");
            ylabel("Power spectral density, dB/Hz");
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
            fprintf("Channel Bandwidth: %f MHz\n", this.channelBandwidth / 1e6);
            fprintf("Modulation Type: %s\n", this.modulationType);
            fprintf("Signal Duration: %f seconds\n", this.waveformDuration);
        end
    end
end