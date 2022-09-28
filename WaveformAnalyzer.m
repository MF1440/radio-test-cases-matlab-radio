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
    %       nFyrie               - кол-во спектрально-временных отчетов дискретного преобразования Фурье
    %       sampleRate         - частота семплирования [Гц]
    %       cyclicPrefixLengths/symbolLengths - длины циклического преффикса и OFDM символов [кол-во временных отчетов]
    %       symbolsCount       - кол-во символов на слот радиокадра
    %       subCarriersCount   - кол-во поднесущих
    %       payloadSymbols     - информационные символы
    %       payloadSymbolsIdxs - индексы ресурсных элементов отведенные для передачи payloadSymbols
    %
    % Поля класса:
    %
    %       rmsEvm            - среднеквадратичное значение модуля вектора ошибки
    %       waveformMeanPower - среднеквадратичное значение мощности сигнала[Гц] 
    %       channelBandwidth  - ширина полосы канала
    %       noiseMeanPower    - среднеквадратичное значение мощности шума
    %       modulationType    - тип модуляционной схемы
    %       waveformDuration  - длина анализируемого сигнала
    %
 properties (Access = private)
      nFyrie
      sampleRate
      cyclicPrefixLengths
      symbolLengths
      symbolsCount
      subCarriersCount
      payloadSymbols 
      payloadSymbolsIdxs
      waveformSource

 end

    properties
        rmsEvm
        waveformMeanPower
        channelBandwidth
        noiseMeanPower
        modulationType
        waveformDuration
    end

    methods
        function this = WaveformAnalyzer(paramWaveformInfo,waveformSource)
            % Конструктор класса. Чтение waveform-ы во временной области и структуры с информацией
            % необходимой для дальнейшей обработки данных и заполнения полей класса
            
            % Чтение входной структуры с информацией о сигнале
            this.nFyrie=paramWaveformInfo.Nfft;
            this.sampleRate=paramWaveformInfo.SampleRate;
            this.cyclicPrefixLengths=paramWaveformInfo.CyclicPrefixLengths;
            this.symbolLengths=paramWaveformInfo.SymbolLengths;
            this.symbolsCount=paramWaveformInfo.symbolsCount;
            this.subCarriersCount=paramWaveformInfo.subCarriersCount;
            this.payloadSymbols=paramWaveformInfo.payloadSymbols;
            this.payloadSymbolsIdxs=paramWaveformInfo.payloadSymbolsIdxs;
            % Чтение сигнала 
            this.waveformSource=waveformSource;

        end

        function calcWaveformParameters(this)
            % Рассчет средней мощности сигнала
            this.waveformMeanPower = mean(abs(this.waveformSource).^2);
            % Длинна полученного сигнала
            waveformLength = length(this.waveformSource);
         
            % Фурье преобразование исходного сигнала
            waveformFurie= fft(this.waveformSource);
            % Сдвиг преобразования Фурье относительно нулевой частоты
            shiftWaveform= fftshift(waveformFurie);
            % Задаем массив частот сигнала
            freqRange = (-waveformLength/2:waveformLength/2-1)*(this.sampleRate/waveformLength);
            % Мощность сигнала в Дб
            powerShiftWaveform = 10*log10(abs(shiftWaveform).^2);
         
            % Вычисление полосы пропускания спектра сигнала по уровню -3дБ,
            % находим значение слева от нуля и умножаем на 2.
            this.channelBandwidth=2*abs(freqRange(find(powerShiftWaveform>-3.01 & powerShiftWaveform<-2.9,1)));

            % Распознаем тип модуляции
            % Строим сигнальное созвездие информационных символов
            payloadConstellation=scatterplot(this.payloadSymbols);
            % Определяем порядок модуляции - количество сигнальных значений созвездия
            orderModulation=length(payloadConstellation.Alphamap);
            % Определяем тип модуляции по порядку модуляции 
            % (QAM-Квадратурная амплитудная модуляция, QPSK-Квадратурная фазовая манипуляция)
            if  orderModulation>2
                this.modulationType="-QAM";
            else 
                this.modulationType="-QPSK";
            end
            % Тип модуляции и порядок
            this.modulationType=orderModulation+this.modulationType;
            
            % Рассчет длительности сигнала
            this.waveformDuration = length(this.waveformSource) / this.sampleRate;

        end

        function plotPowerSpectrumDensity(this)
            % Метод класса, реализующий построение графика спектральной плотности сигнала

            % Длинна полученного сигнала
            waveformLength = length(this.waveformSource);
            % Фурье преобразование исходного сигнала
            waveformFurie= fft(this.waveformSource);
            % Сдвиг преобразования Фурье относительно нулевой частоты
            shiftWaveform= fftshift(waveformFurie);
            freqRange = (-waveformLength/2:waveformLength/2-1)*(this.sampleRate/waveformLength);
            % Мощность сигнала в Дб
            powerShiftWaveform = 10*log10(abs(shiftWaveform).^2); 
            
            plot(freqRange,powerShiftWaveform)
            title('Спектральная плотность сигнала');
            xlabel('Частота, Гц');
            ylabel('Мощность, дБ');
            grid on

        end

        function plotPayloadConstellation(this)

        end

        function calcEvmPerformance(this)

        end
    end
end