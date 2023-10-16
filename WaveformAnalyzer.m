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

    properties (Access = private)
        waveformSource
        waveformInfo
    end
    
    properties
        rmsEvm
        waveformMeanPower
        channelBandwidthHz
        noiseMeanPower
        modulationType
        waveformDurationMcs
        dopplerShiftHz
    end

    methods
        function this = WaveformAnalyzer(waveformSourceFileName, waveformInfoFileName)
            % Конструктор класса. Чтение waveform-ы во временной области и структуры с информацией
            % необходимой для дальнейшей обработки данных и заполнения полей класса

            this.waveformSource = load(waveformSourceFileName).rxWaveform;
            this.waveformInfo = load(waveformInfoFileName).info;
        end

        function calcWaveformParameters(this)
            
            % вычисление средней мощности сигнала
            this.waveformMeanPower = mean(abs(this.waveformSource) .^ 2);
            
            % вычисление разноса между поднесущими в Гц
            subCarrierBandwidthHz = this.waveformInfo.SampleRate / this.waveformInfo.Nfft;
            % вычисление полосы канала в Гц
            this.channelBandwidthHz = subCarrierBandwidthHz * this.waveformInfo.subCarriersCount;
            
            % определяем тип модуляции
            this.modulationType = this.getModulationType();
                       
            % вычисление длительности сигнала в мкс 
            this.waveformDurationMcs = length(this.waveformSource) / this.waveformInfo.SampleRate * 1e6;
            
            
        end

        function modType = getModulationType(this) 
            % метод расчета типа модуляции
            % рассчитываем по известным символам waveformInfo.payloadSymbols
            
            % перебираем из заданных видов модуляции. 
            % в дальнейшем можно добавить другие виды
            checkModulations = ["QPSK", "16QAM", "64QAM", "256QAM"];
            errs = zeros(1, length(checkModulations));
            
            % вычисляем ошибку для разных видов модуляции
            % между исходными payloadSymbols и проверочными символами для разных видов модуляции 
            payloadQAM4Check = qammod(qamdemod(this.waveformInfo.payloadSymbols, 4, 'UnitAveragePower', true), 4, 'UnitAveragePower', true);
            errs(1) = mean(abs(payloadQAM4Check - this.waveformInfo.payloadSymbols));
            payloadQAM16Check = qammod(qamdemod(this.waveformInfo.payloadSymbols, 16, 'UnitAveragePower', true), 16, 'UnitAveragePower', true);
            errs(2) = mean(abs(payloadQAM16Check - this.waveformInfo.payloadSymbols));
            payloadQAM64Check = qammod(qamdemod(this.waveformInfo.payloadSymbols, 64, 'UnitAveragePower', true), 64, 'UnitAveragePower', true);
            errs(3) = mean(abs(payloadQAM64Check - this.waveformInfo.payloadSymbols));
            payloadQAM256Check = qammod(qamdemod(this.waveformInfo.payloadSymbols, 256, 'UnitAveragePower', true), 256, 'UnitAveragePower', true);
            errs(4) = mean(abs(payloadQAM256Check - this.waveformInfo.payloadSymbols));
            
            % определяем модуляцию по минимуму ошибки
            [minError, minErrorIndx] = min(errs);
            modType = checkModulations(minErrorIndx);
        end
        
        function calcDopplerShift(this)
            % метод расчета доплеровского сдига
            % вычисляем сдвиг по набегу фазы между отсчетами префикса и последней частью OFDM символа 
            % реализовано вычисление только по первому длинному префиксу
            % в дальнейшем нужно реализовать вычисление для каждого OFDM символа
            
            cpLength = this.waveformInfo.CyclicPrefixLengths(1);
            % отсчеты префикса
            cp = this.waveformSource(1 : cpLength);
            % отсчеты символа
            ofdm = this.waveformSource(cpLength + 1 : this.waveformInfo.SymbolLengths(1));
            
            % вычисляем набег фазы для каждого отсчета
            dphi = angle(ofdm(end - cpLength + 1 : end) .* conj(cp));
            % усредняем по всем отсчетам
            meanDPhi = mean(dphi(1 : end - this.waveformInfo.Windowing));
            % вычисляем длительность OFDM символа в сек.
            durOFDMSec = this.waveformInfo.Nfft / this.waveformInfo.SampleRate;   
            
            % вычисление частоты доплеровского сдвига
            this.dopplerShiftHz = (meanDPhi / durOFDMSec) / (2 * pi);
        end

        function plotPowerSpectrumDensity(this)
            % метод вывода графика спектральной плотности мощности
            % плотность мощности отнормирована таким образом,
            % чтобы суммарная мощность в частотной области совпадала с
            % суммарной мощностью во временной области
            
            fftSmplCount = length(this.waveformSource);
            waveformFFT = fftshift(fft(this.waveformSource) ./ sqrt(fftSmplCount));
            waveformPowerDensityDB = 20 * log10(abs(waveformFFT));
            freq = (0 : fftSmplCount - 1) - fftSmplCount / 2;
            freq = freq .* (this.waveformInfo.SampleRate / 1000000 / fftSmplCount);
            plot(freq, waveformPowerDensityDB);
            title('Power Spectrum Density');
            xlabel('Freq, MHz');
            ylabel('Power Density, dB');
            
        end

        function plotPayloadConstellation(this)

        end

        function calcEvmPerformance(this)

        end
    end
end
