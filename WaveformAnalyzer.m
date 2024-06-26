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
    % measInfo - структура, содержащая методы измерения параметров сигнала:
    %   - сhannelBandwidth.mode - метод измерения ширины полосы пропускания.
    %          Дефолтное значение: "obw"
    %          Доступные значения:
    %              * "obw"             - измерение на основе оценки занимаемой полосы частот
    %              * "subCarrierCount" - измерение на основе количества используемых 
    %                                    поднесущих и расстояния между ними.
    %                                         
    %   - сhannelBandwidth.powerPercentage - процент от общей передаваемой мощности, используемый при расчете
    %                                        занимаемой полосы частот при сhannelBandwidth.Mode= "obw" [%]
    %                                        Дефолтное значение: 99
    % Примачение 1: measInfo может расширяться по мере добавления в класс новых методов измерения
    % Примечание 2: метод измерения ширины полосы пропускания "subCarrierCount" предполагает, 
    %               что subCarrierCount включает в себя центральную нулевую несущую (при ее наличии).
    %
    % Поля класса:
    %       rmsEvm            - среднеквадратичное значение модуля вектора ошибки
    %       waveformMeanPower - среднее значение мощности сигнала [дБм]
    %       channelBandwidth  - ширина полосы канала [Гц]
    %       noiseMeanPower    - среднеквадратичное значение мощности шума
    %       modulationType    - тип модуляционной схемы
    %       waveformDuration  - длина анализируемого сигнала [c]
    %

    properties (Access = private)
        waveform
        waveformInfo
        measInfo
    end
    
    properties
        rmsEvm
        waveformMeanPower
        channelBandwidth
        noiseMeanPower
        modulationType
        waveformDuration
        dopplershift
    end

    methods
        function this = WaveformAnalyzer(waveformSource, waveformInfo, measInfo)
            % Конструктор класса. Чтение waveform-ы во временной области и структуры с информацией
            % необходимой для дальнейшей обработки данных и заполнения полей класса
            
            this.waveform = waveformSource; 
            this.waveformInfo = waveformInfo;
            if nargin == 3
                this.measInfo = measInfo;
            else
                this.measInfo.channelBandwidth.mode = "obw";
                this.measInfo.channelBandwidth.powerPercentage = 99;
            end
        end

        function calcWaveformParameters(this)
            % Метод рассчитывает параметры сигнала waveformSource и заносит их в соответствующие поля класса WaveformAnalyzer

            measModeChannelBandwidth = this.measInfo.channelBandwidth.mode;
            if strcmp(measModeChannelBandwidth,"obw")
                powerPercentage = this.measInfo.channelBandwidth.powerPercentage;
            end
            sampleRate = this.waveformInfo.SampleRate;
            
            % Расчет длительности, средней мощности и частотного сдвига сигнала
            this.waveformDuration = length(this.waveform) * 1 / sampleRate;
            this.waveformMeanPower = 10 * log10( mean( abs(this.waveform).^2 ) / 1e-3 ); 
            this.dopplershift = this.calcDopplerShift();
            % Формула для рассчета среднеквадратичной мощности сигнала:
            % this.waveformRmsPower = 10 * log10( mean( rms(this.waveform.^2) ) / 1e-3 );

            % Измерение ширины полосы пропускания
            switch lower(measModeChannelBandwidth)
                case "obw"
                    % Измерение полосы пропускания на основе занимаемой полосы частот:
                    this.channelBandwidth = obw(this.waveform, sampleRate, [], powerPercentage);
                case "subcarriercount"
                    % Вычисление полосы пропускания на основе количества поднесущих и расстояния между ними:
                    subCarrierSpacing = (sampleRate / this.waveformInfo.Nfft);
                    this.channelBandwidth = subCarrierSpacing * this.waveformInfo.subCarriersCount;
                otherwise
                    error(sprintf("calcWaveformParameters: Режим измерения " + ...
                        "ширины полосы пропускания введен некорректно.\n" + ...
                        "Доступные варианты: 'obw','subcarriercount'"))
            end
            
            % Выбор типа модуляции на основе значений payload символов из 
            % waveformInfo. Алгоритм рассчитан на то, что вид модуляции
            % соответствует BPSK, QPSK или N-QAM, где N - порядок модуляции.
            % Также алгоритм рассчитан на то, что payload символы в waveformInfo
            % представляют из себя идеальные значения символов одной  из выше
            % перечисленных модуляций и в payload задействовано больше
            % половины возможных значений, принимаемых символами.
            % Также было принято, что payload каждой поднесущей, имеет
            % одинаковый тип модуляции.
            % (Для более жестких условий возможно придется описывать нейронную сеть,
            % определяющую тип модуляции)
            uniqSymCount = length(unique(this.waveformInfo.payloadSymbols));
            modulationOrder = 2^nextpow2(uniqSymCount);
            if ( modulationOrder ~= 0 && (bitand(modulationOrder, modulationOrder - 1) == 0) )
                switch modulationOrder
                    case 2
                        this.modulationType = "BPSK";
                    case 4
                        this.modulationType = "QPSK";
                    otherwise
                        this.modulationType = strcat(num2str(modulationOrder), "QAM");
                end
            else
                this.modulationType = "None";
                warning('calcWaveformParameters: Тип модуляции не определен')
            end
        end

        function frequencyOffset = calcDopplerShift(this)
            % Метод класса реализует расчет смещения несущей частоты 
            % OFDM cигнала на основе корреляции с циклическим префиксом
            % 
            % Реализованный метод определяет дробный сдвиг несущей частоты
            % (FFO). Пределы измерения частотного сдвига представляет из
            % себя диапазон частот(-subCarrierSpacing/2;subCarrierSpacing/2],
            % где subCarrierSpacing - расстояния между поднесущими.
            % Если частотный сдвиг по модулю больше, чем subCarrierSpacing/2,
            % то дополнительно к FFO необходимо рассчитать целочисленный
            % сдвиг несущей частоты (IFO). Тогда итоговый частотный сдвиг
            % (CFO) может быть найден как результат сложения найденных 
            % частотных сдвигов: CFO = IFO + FFO
            %
            % Метод предполагает,что в сигнале содержится хотя бы один 
            % целый OFDM символ.
            %
            % За основу взят алгоритм из статьи:
            % Sandell M., Van de Beek J.J., Borjesson P.O. "On Synchronization
            % in OFDM Systems Using the Cyclic Prefix". Division of Signal
            % Processing, Lulea University of Technology, 1996. 
            
            nfft = this.waveformInfo.Nfft;
            sampleRate = this.waveformInfo.SampleRate;
            
            % Выбор наиболее часто встречаемого циклического префикса
            cyclicPrefixLength = mode(this.waveformInfo.CyclicPrefixLengths);
            
            % Формирование обычного и задержанного окна корреляции
            firstCorrelationWindow = this.waveform(1:end-nfft);
            secondCorrelationWindow = this.waveform(1+nfft:end);

            % Энергетическая часть
            energyTerm = abs(firstCorrelationWindow).^2 + abs(secondCorrelationWindow).^2;
            energyTerm = conv(energyTerm,ones(cyclicPrefixLength, 1));
            energyTerm = energyTerm(cyclicPrefixLength:end-cyclicPrefixLength);
            
            % Корреляционная часть
            cpCorrelation = firstCorrelationWindow .* conj(secondCorrelationWindow);
            cpCorrelation = conv(cpCorrelation,ones(cyclicPrefixLength, 1));
            cpCorrelation = cpCorrelation(cyclicPrefixLength:end-cyclicPrefixLength);
            clear firstCorrelationWindow secondCorrelationWindow
            
            % Поиск позиции максимума корреляции
            cpCorrelationAfterCompensation = 2 * abs(cpCorrelation) - energyTerm;
            [~,maxCorrPosition] = max(cpCorrelationAfterCompensation);
            clear energyTerm
            
            % Расчет частотного сдвига
            subCarrierSpacing = (sampleRate/nfft);
            frequencyOffset = -angle( cpCorrelation(maxCorrPosition) ) ./ (2 * pi) * subCarrierSpacing;
        end

        function plotPowerSpectrumDensity(this)
            % Метод класса строит спектральную плотность мощности для
            % сигнала waveformSource
            
            [powerSpectrumDensity,frequencyScale] = pwelch(this.waveform, [], [], [], ...
                                                        this.waveformInfo.SampleRate,'centered');
            % Выбор размерности шкалы частот:
            % Определение количества чисел до запятой
            freqIntegerPart = regexp(num2str(max(frequencyScale)),'\.','split');
            freqIntegerPart = length(freqIntegerPart{1});
            % Выбор метрического префикса единицы измерения частоты:
            scalingType = floor((freqIntegerPart-1)/3);
            switch scalingType
                case 0
                    nameFreqUnit = "Гц";
                case 1
                    nameFreqUnit = "кГц";
                case 2
                    nameFreqUnit = "МГц";
                case 3
                    nameFreqUnit = "ГГц";
                otherwise
                    nameFreqUnit = "Гц";
                    scalingType = 0;
            end
            % Масштабирования шкалы частот
            freqScalingFactor = 1e3.^(scalingType);
            frequencyScale = frequencyScale ./ freqScalingFactor;
            
            % Вывод графика спектральной плотности мощности:
            plot(frequencyScale, 10 * log10(powerSpectrumDensity ./ 1e-3))
            xlabel(strcat('Частота, ', nameFreqUnit))
            ylabel('Мощность/Частота (дБм/Гц)')
            title('Спектральная плотность мощности')
            xlim([frequencyScale(1) frequencyScale(end)])
            grid on
        end

        function plotPayloadConstellation(this)

        end

        function calcEvmPerformance(this)

        end
    end
end