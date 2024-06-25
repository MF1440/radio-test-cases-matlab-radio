classdef WaveformAnalyzer < handle
    %% Описание класса
    %
    % 1. Класс читает данные (во временной области) на выходе OFDM 
    % модулятора сигнала, а также информацию о параметрах формирователя
    %
    % 2. Строит метрики: спектральная плотность мощности в частотной области, 
    % графическое представление созвездия на комплексной плоскости,
    % среднеквадратичное значение модуля вектора ошибки (EVM)
    %
    % Входные данные:
    %
    % waveformSource - массив содержащий отчеты baseband сигнала во временной области 
    % на выходе OFDM модулятора
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
        waveformSourse
        waveformInfo
        initialSignal
        Nscs
        Nfft
        Nsymbols
        xTimeSamples
        yTimeSamples
        yFreqSamples
        prefixTimeSamples
        numerology
    end
    
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
        function this = WaveformAnalyzer(waveformSourse, waveformInfo)
            % Конструктор класса. Чтение waveform-ы во временной области и структуры 
            % с информацией необходимой для дальнейшей обработки данных и 
            % заполнения полей класса
            
            this.waveformSourse = waveformSourse.rxWaveform;
            this.waveformInfo = waveformInfo.info;
            this.Nscs = this.waveformInfo.subCarriersCount;
            this.Nfft = this.waveformInfo.Nfft;
            this.Nsymbols = this.waveformInfo.symbolsCount;
            
            % парсинг входной структуры и демодуляция данных
            this.parseSignal()
        end
        
        function calcWaveformParameters(this)
            % Метод класса, реализующий расчет параметров передаваемого
            % сигнала: вектор ошибки созвездия, спектральная мощность
            % сигнала, ширина полосы канала, средняя мощность шума,
            % тип модуляции, длина анализируемого сигнала
            
            % расчет вектора ошибки
            this.calcEvmPerformance();
            % расчет мощности сигнала
            this.waveformMeanPower = mean(rms(this.yTimeSamples, 2).^2);
            % расчет ширины полосы канала
            this.calcNumerology();
            this.channelBandwidth = this.Nscs * 15000 * 2 ^ (this.numerology);
            % расчет среднеквадратичного значения шума
            this.noiseMeanPower = mean(rms(this.yFreqSamples - this.xTimeSamples, 2).^2);
            % расчет модуляционной схемы
            this.getmodulationType()
            % расчет длины отправленного сигнала
            this.waveformDuration = size(this.waveformSourse, 1) / ...
                this.waveformInfo.SampleRate;
            % Рассчет Допплеровского сдвига
            this.calcdopplerShift();
        end % Конец function calcWaveformParameters(this)
        
        
        function printParametrs(this)
            % выводит параметры, рассчитанных в calcWaveformParameters в
            % консоль
            
            fprintf('RmsEVM              = %f\n', this.rmsEvm);
            fprintf('Mean Waveform power = %f\n', this.waveformMeanPower);
            fprintf('Bandwidth           = %f, MHz\n', this.channelBandwidth/1e6);
            fprintf('Mean Noise power    = %f\n', this.noiseMeanPower);
            fprintf('Modulation Type     = %s\n', this.modulationType);
            fprintf('Waveform duration   = %f, sec\n', this.waveformDuration);
            fprintf('Mean doppler shift  = %f, Hz\n', mean(this.dopplerShift));
        end
        
        function plotPowerSpectrumDensity(this)
            % Метод класса, который строит график спектральной плотности 
            % мощности по поднесущим частотам
           
            psdx = (1/(this.Nfft)) * mean(abs(this.yFreqSamples).^2, 1);
            freq = 0:this.Nfft-1;
            plot(freq,pow2db(psdx))
            grid on
            title("Power Spectral densiy")
            xlabel("Subcarrier")
            ylabel("Power/Frequency (dB/Scs)")
        end

        function plotPayloadConstellation(this)
            % Метод класса, реализующий графическое изображение 
            % созвездие модулированных символов
            
            scatterplot(this.waveformInfo.payloadSymbols);
            title(['Payload Constellation, Modulation = ', this.modulationType]);
            xticks('auto');
            yticks('auto');
            grid on;
        end
        
    end % конец Methods с public доступом
    
    methods (Access = private)
        function parseSignal(this)
            % метод который перестраивает входные 1-d массивы референсных 
            % и принятых данных в 2-d [SymbolsCount x Nfft] 
            % xTimeSamples, yTimeSamples, yFreqSamples [SymbolsCount x Nfft]
            % prefixTimeSamples [SymbolsCount x max(CyclicPrefixLengths)]
            
            % переменные для хранения OFDM символов по временным слотам
            % в частотной области [SymbolsCount x Nfft]
            xTime = zeros(this.Nfft, 1);
            yTime = zeros(this.Nfft, 1);
            
            % храним отчеты префикса для расчета Допплеровского сдвига
            prefixTime = zeros(max(this.waveformInfo.CyclicPrefixLengths), 1);
            
            % матрица для хранения демодулированных сигналов
            % во временной области
            yFreq = zeros(this.Nfft, 1);
            
            yIdx = 0;
            xIdx = 0;
            % парсинг входной структуры, избавление от циклического
            % префикса и пилотов в данных. 
            for symbIdx = 1:this.Nsymbols
                prefixLen = this.waveformInfo.CyclicPrefixLengths(symbIdx);
                % убираем префикс из начала каждого радиокарда
                yIdx = sum(this.waveformInfo.SymbolLengths(1:symbIdx-1)) + ...
                    prefixLen;
                yTime = this.waveformSourse(yIdx+1:yIdx+this.Nfft);
                prefixTime = this.waveformSourse(yIdx+1-prefixLen:yIdx);
                % расчет принятого сигнала в частотной области
                yFreq = fftshift(fft(yTime, this.Nfft));
                
                % Для X сигнала в 3 и 12 символе необходимо убрать пилоты
                if (symbIdx == 3) || (symbIdx == 12)
                    xTime(2:2:this.Nscs) = ...
                        this.waveformInfo.payloadSymbols(xIdx+1:xIdx+this.Nscs/2);
                    xIdx = xIdx + this.Nscs / 2;
                else
                    xTime(1:this.Nscs) = ...
                        this.waveformInfo.payloadSymbols(xIdx+1:xIdx+this.Nscs);
                    xIdx = xIdx + this.Nscs;
                end
                
                this.xTimeSamples(symbIdx, :) = xTime;
                this.yTimeSamples(symbIdx, :) = yTime;
                this.yFreqSamples(symbIdx, :) = yFreq;
                this.prefixTimeSamples(symbIdx, 1:prefixLen) = prefixTime;
            end
            
        end % конец метода parseSignal(this)

        function calcdopplerShift(this)
            % Метод класса, реализующий расчет Допплеровского сдвига по
            % частоте. Для расчета используется информация о сдвиге префикса
            % Выход: массив [Nymbs] со значениями сдвигов по частоте для
            % каждого символа
            
            windowShift = this.waveformInfo.Windowing;
            this.dopplerShift = zeros(this.Nsymbols, 1);
            % длина одного символа
            deltaT = this.waveformInfo.Nfft / this.waveformInfo.SampleRate;
            
            % цикл по всем символам: расчитаем для каждого dopplerShift
            for symbIdx = 1:this.Nsymbols
                % выберем из исходного сигнала последние prefixLen отчетов и
                % сам префикс
                prefixLen = this.waveformInfo.CyclicPrefixLengths(symbIdx);
                currSymbol = this.yTimeSamples(symbIdx, :);
                prefix = this.prefixTimeSamples(symbIdx, 1:prefixLen);

                % уберем guard окно из префикса и сигнала
                currSymbol = currSymbol(end-prefixLen+1:end-windowShift);
                prefix = prefix(1:end-windowShift);
                
                % вычисляем усредненный угол поворота фазы
                deltaPhase = angle(sum(currSymbol .* conj(prefix)));
                % рассчет Допплеровского сдвига по повороту фазы
                this.dopplerShift(symbIdx, :) = (deltaPhase) / (2 * pi * deltaT);
            end
        end % Конец calcdopplerShift(this)
        
        function calcNumerology(this)
            % метод для расчета нумерологии для выбранной структуры
            % радиокадра по заданным длинам циклических thisпрефиксов
            % формулы для расчета взяты из 3GPP TS 138.211 раздел 5.3.1
            
            firstprefixLen = this.waveformInfo.CyclicPrefixLengths(1);
            secondprefixLen = this.waveformInfo.CyclicPrefixLengths(2);
            
            if(firstprefixLen ~= secondprefixLen)
                divFactor = secondprefixLen / 144;
                k = (firstprefixLen - 144 * divFactor) / 16;
                this.numerology = log2(k / divFactor);
            else % проверка на extended префикс
                this.numerology = 2;
            end
        end % calcNumerology(this)
        
        function getmodulationType(this)
            % метод для определения типа модуляции
            
            bitsPerSymb = log2(size(unique(this.waveformInfo.payloadSymbols), 1));
            switch bitsPerSymb
                case 2
                    this.modulationType = 'QPSK';
                case 4
                    this.modulationType = 'QAM16';
                case 6
                    this.modulationType = 'QAM64';
                case 8
                    this.modulationType = 'QAM256';
                otherwise
                    error('Выбранный тип модуляции не найден!');
            end
        end 

        function calcEvmPerformance(this)
            % Метод класса, реализующий расчет векторной ошибки
            % демодулированного сигнала
            
            this.rmsEvm = 0;
            % расчет ошибки отдельно по каждому символу
            for symbIdx = 1:this.Nsymbols
                % расчет среднего значения исходного сигнала   
                rmsVal = rms(this.xTimeSamples(symbIdx,1:this.Nscs));
                % расчет среднеквадратичной ошибки между принятым и
                % исходным сигналом
                diff = (this.yFreqSamples(symbIdx,1:this.Nscs) - ...
                    this.xTimeSamples(symbIdx,1:this.Nscs)).^2;
                % нормализация ошибки на мощность сигнала и нахождение
                % среднего значения для всех поднесущих частот
                diff = abs(mean(sqrt(diff) / rmsVal));
                this.rmsEvm = this.rmsEvm + diff;
            end
            % нахождение средней ошибки для всех символов
            this.rmsEvm = this.rmsEvm / this.Nsymbols;
        end % конец function calcEvmPerformance
        
    end % конец methods с private доступом
    
end % конец class WaveformAnalyzer