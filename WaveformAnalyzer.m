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
        % искомые параметры
        rmsEvm
        waveformMeanPower
        channelBandwidth
        noiseMeanPower
        modulationType
        waveformDuration
        dopplerShift

        % параметры сигнала
        sampleRate
        ftCount
        cyclicPrefixArrayLength
        symbolArrayLength
        payloadArraySymbol
        subCarrierCount

        % сигнал
        waveform



    end

    methods
        function this = WaveformAnalyzer(rxWaveform, info)
            % Конструктор класса. Чтение waveform-ы во временной области и структуры с информацией
            % необходимой для дальнейшей обработки данных и заполнения полей класса

            this.waveform = rxWaveform;
            
            this.sampleRate = info.SampleRate;
            this.ftCount = info.Nfft;
            this.cyclicPrefixArrayLength = info.CyclicPrefixLengths;
            this.symbolArrayLength = info.SymbolLengths;
            this.payloadArraySymbol = info.payloadSymbols;
            this.subCarrierCount = info.subCarriersCount;
            
        end

        function calcWaveformParameters(this)

            this.waveformMeanPower = mean(abs(this.waveform).^2);

            deltaF = this.sampleRate / this.ftCount;
            this.channelBandwidth = this.subCarrierCount * deltaF;

            % Тип модуляции определяется по количеству уникальных значений
            % в созвездии. Если количество уникальных значений не равно
            % степени 2, то выводим ошибку

            constellationMatrix = [real(this.payloadArraySymbol) imag(this.payloadArraySymbol)];
            constellationPointCount = size(unique(constellationMatrix, 'rows'), 1);
            logRatio = log(constellationPointCount) / log(2);
            tolerance = 1e-15;
            isPower2 = (logRatio-round(logRatio) < tolerance);
            if isPower2
                this.modulationType = [num2str(constellationPointCount) '-QAM'];
            else
                error('Ошибка в модуляции');
            end

            this.waveformDuration = length(this.waveform) / this.sampleRate;

            this.calcDopplerShift();

        end


        function calcDopplerShift(this)
            % Определение частотного смещения производится в соответствии с:
            % Van de Beek,et. al "ML estimation of time and frequency offset in OFDM systems.", 1997
            % Moose, Paul H. "A technique for orthogonal frequency division multiplexing frequency offset correction.", 1994
            % 
            % В связи со свойством цикличности цикличный префикс совпадает
            % с окончанием OFDM символа. Тогда с помощью метода
            % максимального правдоподобия можно оценить сдвиг по частоте.
            % Для улучшения оценки сдвига использовались все 14 символов.

            slotCorrelation = 0;
            shift = 1;
            for symbolIdx = 1:length(this.cyclicPrefixArrayLength)

                prefixStart = shift;
                prefixEnd = prefixStart + this.cyclicPrefixArrayLength(symbolIdx) - 1;
                prefix = this.waveform(prefixStart:prefixEnd);

                tailStart = prefixStart + this.ftCount - this.cyclicPrefixArrayLength(symbolIdx);
                tailEnd = prefixStart + this.ftCount - 1;
                tail = this.waveform(tailStart:tailEnd);

                symbolCorrelation = sum(prefix .* conj(tail));
                slotCorrelation = slotCorrelation + symbolCorrelation;
                shift = shift + this.ftCount;
            end

            carrierOffsetRatioEstimation = angle(slotCorrelation) / (2*pi);
            this.dopplerShift = carrierOffsetRatioEstimation * this.sampleRate / (this.ftCount);
        end

        function plotPowerSpectrumDensity(this)
            [psd, frequency] = pwelch(this.waveform, [], [], [], this.sampleRate);
            figure(1); plot(frequency*1e-6, 10*log10(psd));
            title('Оценка СПМ')
            xlabel('Частота, МГц');
            ylabel('СПМ');
        end

        function plotPayloadConstellation(this)

        end

        function calcEvmPerformance(this)

        end
    end
end