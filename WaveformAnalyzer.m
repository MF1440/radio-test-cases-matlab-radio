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
    end    

    properties (Access = private)
        lengthFft
        sampleRate 
        cyclicPrefixLenghtsList
        symbolLenghtsList
        lengthWindow  
        symbolsCount 
        payloadSymbolsList
        subCarriersCount
        payloadSymbolsIdxsList
        samplesList
    end

    methods
        function this = WaveformAnalyzer(infoWaveform,samplesWaveform)
            % Конструктор класса. Чтение waveform-ы во временной области и структуры с информацией
            % необходимой для дальнейшей обработки данных и заполнения полей класса
            this.lengthFft                = infoWaveform.Nfft;
            this.sampleRate               = infoWaveform.SampleRate;
            this.cyclicPrefixLenghtsList  = infoWaveform.CyclicPrefixLengths;
            this.symbolLenghtsList        = infoWaveform.SymbolLengths;
            this.lengthWindow             = infoWaveform.Windowing;
            this.symbolsCount             = infoWaveform.symbolsCount;
            this.payloadSymbolsList       = infoWaveform.payloadSymbols;
            this.subCarriersCount         = infoWaveform.subCarriersCount;
            this.payloadSymbolsIdxsList   = infoWaveform.payloadSymbolsIdxs;
            this.samplesList              = samplesWaveform;
        end

        function calcWaveformParameters(this)
            % Метод класса вычисляет параметры сигнала
            
            % Вычисление среднеквадратичной мощности сигнала
            this.waveformMeanPower = mean(abs(this.samplesList).^2);
            % Вычисление ширины полосы сигнала
            spaceSubCarrier = this.sampleRate/this.lengthFft;
            this.channelBandwidth = spaceSubCarrier * this.subCarriersCount;
            % Вычисление длительности сигнала
            timeSample = 1 / this.sampleRate;
            this.waveformDuration = timeSample * length(this.samplesList);
            % Вычисление длительности сигнала
            this.calcDopplerShift();
            % Определение типа созвездия 
            this.estimatModulationType(); 
        end
    
        function plotPowerSpectrumDensity(this)
            % Метод выполняет вычисление и вывод спектральной плотности мощности (СПМ) сигнала
            % в дБ. Вычисления СПМ выполняется с помощью метода периодаграмм
            sampelPerSegmet     = 500;
            segmentsCount       = ceil(length(this.samplesList)/sampelPerSegmet);
            remaindSamp         = mod(length(this.samplesList), sampelPerSegmet);
            samplesZeroPaddList = [this.samplesList; zeros(sampelPerSegmet - remaindSamp,1)];
            hannWindow          = 0.5 * (1 - cos(2 * pi * (0:sampelPerSegmet-1) / sampelPerSegmet)).';
            energWindow         = hannWindow.'*hannWindow;
            freqRange           = (-sampelPerSegmet / 2:sampelPerSegmet / 2 - 1)*this.sampleRate/sampelPerSegmet; 
            powerDensity        = zeros(sampelPerSegmet,1);
            n                   = (0:sampelPerSegmet-1)';
            
            for segIdx = 1:segmentsCount
                segmetSamples = samplesZeroPaddList(((segIdx-1))*sampelPerSegmet + 1:segIdx*sampelPerSegmet);

                for freqIdx = 1:sampelPerSegmet
                    normFactor = 1 / (energWindow*this.sampleRate);
                    complexExponent = exp(-1i * 2 * pi * (freqRange(freqIdx) / this.sampleRate) * n);                    
                    segmetSamplesWeigh = hannWindow.*segmetSamples;
                    correlation = sum(segmetSamplesWeigh.*complexExponent);
                    
                    powerDensity(freqIdx) = powerDensity(freqIdx) + normFactor*abs(correlation).^2;   
                end
            end

            powerDensity = powerDensity / segmentsCount;

            powerDensitydB = 10 * log10(powerDensity);
            
            plot(freqRange * 1e-6,powerDensitydB);
            xlabel('Частота, МГц');
            ylabel('CПМ, дБ/Гц');
        end

    end

    methods (Access = private)

        function calcDopplerShift(this)
            % Метод вычисляет доплеровское смещение сигнала 
            spaceSubCarrier      = this.sampleRate/this.lengthFft;
            maxLogLikelyEstList  = zeros(this.symbolsCount,1);
            startOfdmSymb        = 1;
            % Цикл вычисления частотного смещения в каждом OFDM символе
            for idxSymb = 1:this.symbolsCount
                % Выделение отсчётов текущего OFDM символа из всего массива отсчётов
                currentOfdmSymb = this.samplesList(startOfdmSymb:startOfdmSymb + this.symbolLenghtsList(idxSymb) - 1);
                % Выделение отсчётов циклического префикса текущего OFDM символа
                cyclicPrefix = currentOfdmSymb(this.lengthWindow:this.cyclicPrefixLenghtsList(idxSymb) - this.lengthWindow);
                % Выделение отсчётов OFDM символа из которых сформирован циклический префикс
                tailSymb = currentOfdmSymb(end - this.cyclicPrefixLenghtsList(idxSymb) + this.lengthWindow:end - this.lengthWindow);
                % Вычисление оценки нормированного доплеровского смещение
                maxLogLikelyEstList(idxSymb) = -angle(sum(cyclicPrefix  .* conj(tailSymb)));

                startOfdmSymb = startOfdmSymb + this.symbolLenghtsList(idxSymb);
            end
            % Перевод единиц измерения доплеровского смещения в Гц
            freqOffset = (sum(maxLogLikelyEstList) * spaceSubCarrier) / ((2*pi) * this.symbolsCount);
            this.dopplershift = freqOffset; 
        end

        function estimatModulationType(this)
             % Метод определяет принадлежность сигнального созвездия к
             % квадратному созвездию M-QAM
             % Для доказательства, что рассматриваемое созвездие
             % принадлежит к типу квадратного M-QAM, используется
             % утверждение, что квадратное M-QAM может быть представлена
             % как прямое произведение (cartisan product) двух модуляций 
             % типа sqrt(M)-PAM.
             % Следовательно, необходимо показать, что координаты точек на 
             % реальной и мнимой оси образуют sqrt(M)-PAM.
                
             uniqSymbConstell = unique(this.payloadSymbolsList);

             pointsConstell = length(uniqSymbConstell);
                
             realMPAM = unique(sort(real(uniqSymbConstell))); 
             imagMPAM = unique(sort(imag(uniqSymbConstell)));
                         
             pointsRealCount = length(realMPAM);
             pointsImagCount = length(imagMPAM);

             pointsCortisanProduct = pointsRealCount*pointsImagCount;
             
             % Проверк количества точек полученного при прямом произведение
             % двух PAM и количества точек исследуемого созвездия
             if pointsCortisanProduct == pointsConstell
                 % Проверка двух PAM на равенство числа точек
                 if (pointsRealCount == pointsImagCount)

                     distanesPointReal = (abs(realMPAM(1) - realMPAM(1:end)));
                     distanesPointImag = (abs(imagMPAM(1) - imagMPAM(1:end))); 

                     % Вычисление расстояния между соседними точками 
                     for idx = 1:length(distanesPointReal)-1
                         distansEachOtherReal(idx) = abs(distanesPointReal(idx+1) - distanesPointReal(idx));
                     end
                     % Вычисление расстояния между соседними точками    
                     for idx = 1:length(distanesPointReal)-1
                         distansEachOtherImag(idx) = abs(distanesPointImag(idx+1) - distanesPointImag(idx));
                     end
                     
                     % Проверка равенства расстояний между точками двух PAM
                     % модуляций
                     relativeDistanceReal = distansEachOtherReal ./ (distansEachOtherImag(1));
                     relativeDistanceImag = distansEachOtherImag ./ (distansEachOtherReal(1));
    
                     relativeDistanceReal = ceil(relativeDistanceReal*1e12)/1e12;
                     relativeDistanceImag = ceil(relativeDistanceImag*1e12)/1e12;
    
                     checkEqualDistanceReal = (relativeDistanceReal == ones(1,length(relativeDistanceReal))); 
                     checkEqualDistanceImag = (relativeDistanceImag == ones(1,length(relativeDistanceImag)));  
                     % Проверка, что точки обеих PAM имеют равное
                     % расстояние с соседними точками
                     if checkEqualDistanceReal == checkEqualDistanceImag
                        % Определение порядка модуляции
                        orderMQAM = pointsRealCount * pointsImagCount;
                        this.modulationType = sprintf('%d-QAM',orderMQAM);
                     else 
                        this.modulationType = 'Тип модуляции не определен'; 
                     end
                 else 
                     this.modulationType = 'Тип модуляции не определен';
                 end
             else
                 this.modulationType = 'Тип модуляции не определен';
             end
        end        

        function plotPayloadConstellation(this)

        end

        function calcEvmPerformance(this)

        end
     end
   
end