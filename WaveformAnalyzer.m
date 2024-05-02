classdef WaveformAnalyzer < handle
    %% Описание класса
    %
    % 1. Класс получает данные (во временной области) прошедшие через
    % радиоканал с доплеровским сдвигом частот от OFDM модулятора QAM
    % сигнала, а также информацию о параметрах формирователя, включая,
    % (возможно не полные) данные о передаваемых QAM символах
    % 2. Осуществляет компенсацию доплеровского сдвига оценивая
    % набег фаз в копиях циклического префикса, демодулирует QAM символы с
    % неизвестной начально фазой
    % 3. По возможности оценивает тип модуляции.
    % 4. Строит метрики: спектральная плотность мощности в частотной области, графическое представление созвездия на комплексной плоскости,
    %
    %
    % Входные данные:
    %
    % Структура inputDatа:
    % rxWaveform - массив содержащий отчеты baseband сигнала во временной
    % области на выходе OFDM модулятора и доплеровское смещение
    %
    % info - структура с параметрами OFDM модулятора и пейлоуда:
    %       Nfft               - кол-во спектрально-временных отчетов дискретного преобразования Фурье
    %       SampleRate         - частота семплирования [Гц]
    %       CyclicPrefixLengths/SymbolLengths - длины циклического преффикса и OFDM символов [кол-во временных отчетов]
    %       SymbolsCount/SymbolsPerSlot       - кол-во символов на слот радиокадра
    %       subCarriersCount   - кол-во поднесущих
    %       payloadSymbols     - информационные символы
    %       payloadSymbolsIdxs - индексы ресурсных элементов отведенные для передачи payloadSymbols
    %       Windowing -  размер перекрытия OFDM  символов в слоте во
    %       временной области
    %       SymbolPhases - not implemented
    % Структура processedData:
    %       payloadData - последовательность QAM символов расположенная в
    %       соответствии с payloadSymbolsIdxs, если номера нет в
    %       payloadSymbolsIdxs то ноль
    %       snr_array - массив определенных ОСШ на каждый слот
    %       e_sig_per_subcarrier - массив средних энергий сигнала в поднесущей в каждом
    %       слоте после демодуляции
    %       e_noise_per_subcarrier - массив средних энергих шума в
    %       поднесущей в каждом слоте после демодуляции
    %       demodulatedData - демодулированные (с неизвестной начальной фазой, поскольку нет пилотов)  информационные QAM символы
    %       для каждого слота
    %       phaseShift - определенные набеги фазы из-за доплеровского
    %       сдвига
    % Поля класса:
    %
    %       rmsEvm            - среднеквадратичное значение модуля вектора ошибки
    %       waveformMeanPower - среднеквадратичное значение мощности сигнала
    %       channelBandwidth  - ширина полосы канала
    %       noiseMeanPower    - среднеквадратичное значение мощности шума
    %       modulationType    - тип модуляционной схемы
    %       waveformDuration  - длина анализируемого сигнала
    %       inputData - структура с параметрами OFDM модулятора и пейлоуда
    %       и массив содержащий отчеты baseband сигнала
    %       processedData - структура с данными полученными в результате
    %       обработки
    %       isLoaded - флаг наличия загруженных данных, объект может быть
    %       создан однократно, но данные могут быть загрежены много раз
    %       isProcessed - флаг обработки загруженных данных

    properties
        rmsEvm
        waveformMeanPower
        channelBandwidth
        noiseMeanPower
        modulationType
        waveformDuration
        dopplershift

        inputData
        processedData
        isLoaded
        isProcessed
    end

    methods
        function this = WaveformAnalyzer(inputData)
            % Конструктор класса. Чтение waveform-ы во временной области и структуры с информацией
            % необходимой для дальнейшей обработки данных и заполнения полей класса
            % структура с информацией необязательна и может быть загружена
            % позже
            if nargin == 0
             this.isLoaded = 0;
             this.isProcessed = 0;
            else
             this.inputData = inputData;
             this.isLoaded = 1;
             this.isProcessed = 0;
            end 
        end

        function load_inputData(this,inputData)
            % Чтение waveform-ы во временной области и структуры с информацией
            % необходимой для дальнейшей обработки данных и заполнения полей класса
            this.inputData = inputData;
            this.isLoaded = 1;
            this.isProcessed = 0;  
        end

        function validate_inputData(this)
            % проверяет на допустистимость длины массивов в загруженных
            % данных
            %
            subCarriersCount = this.inputData.info.subCarriersCount;
            symbolsCount = this.inputData.info.symbolsCount;
            wav_length = numel(this.inputData.rxWaveform);
            payload_length = max(this.inputData.info.payloadSymbolsIdxs);
            l2 = sum(this.inputData.info.SymbolLengths);
            l3 = sum(this.inputData.info.CyclicPrefixLengths);
            Nfft = this.inputData.info.Nfft;
            if symbolsCount*subCarriersCount == payload_length & l2 == wav_length & l3+Nfft*symbolsCount == wav_length
                this.isLoaded = 1;
                
                disp('Data are valid');
            else
               this.isLoaded = 0;
               this.isProcessed = 0; 
               disp('Data are not valid');
            end
        end 

        function [channelBandwidth,waveformMeanPower,waveformDuration] = calcWaveformParameters(this)
            % вычисляет легко вычислимые параметры загруженной формы
            if this.isLoaded == 0
                disp('Data not loaded!');
                return
            end
            channelBandwidth=this.inputData.info.subCarriersCount/this.inputData.info.Nfft*this.inputData.info.SampleRate;
            this.channelBandwidth = channelBandwidth;
            x1=this.inputData.rxWaveform;
            waveformMeanPower=mean(x1.*conj(x1));
            this.waveformMeanPower = waveformMeanPower;
            waveformDuration = numel(x1)/this.inputData.info.SampleRate;
            this.waveformDuration = waveformDuration

        end

        function [f_dopler speed] = calcdopplerSHift(this)
            if this.isProcessed == 0
                disp('Data are not processed!');
                return
            end
            phaseShift = mean(this.processedData.phaseShift)
            Nfft= this.inputData.info.Nfft;
            SampleRate = this.inputData.info.SampleRate;
            %dopler shift ih hz
            f_dopler = phaseShift/(2*pi*Nfft)*SampleRate
            speed = f_dopler/SampleRate*physconst('LightSpeed')
            this.dopplershift = f_dopler
        end

        function plotPowerSpectrumDensity(this)
            if this.isLoaded == 0
                disp('Data not loaded!');
                return
            end
            rxWaveform = this.inputData.rxWaveform;
            SampleRate=this.inputData.info.SampleRate;
            figure(1);
            periodogram(rxWaveform,[],[],SampleRate,[],[],'centered',"psd");
        end

        function plotPayloadConstellation(this,num_frame,count_points_to_display_in_constellation)
            if this.isProcessed == 0
                count_of_payloads=max(this.inputData.info.payloadSymbolsIdxs);
                payloadData=zeros(count_of_payloads,1);
                payloadData(this.inputData.info.payloadSymbolsIdxs)=this.inputData.info.payloadSymbols;
            else
                payloadData = this.processedData.payloadData;
            end
            subCarriersCount = this.inputData.info.subCarriersCount;
            if nargin == 2
                count_points_to_display_in_constellation = subCarriersCount;
            end    
            stpay = (num_frame-1)*subCarriersCount+1;
            enpay = stpay + subCarriersCount-1;
            payload = payloadData(stpay:enpay);
            
            isPlotted=0;
            if(isempty(this.modulationType))
                figure();
                plot(payload(1:count_points_to_display_in_constellation),'b*');isPlotted=1;
                title({['Payload: ',num2str(num_frame)], ['Constellation points:',num2str(count_points_to_display_in_constellation)]});
            else
                str=this.modulationType;
                len=length(str);
                if len<3
                    disp('Modulation Type error');
                    return;
                end
                str1=str(len-2:len);
                if strcmpi(str1,'QAM') && len>=5
                    M=str2num(str(1:(len-3)));
                    x=(0:M-1);rc = qammod(x,M);
                    rc=rc./sqrt(mean(rc.*conj(rc)));
                    diag = comm.ConstellationDiagram(ReferenceConstellation=rc,EnableMeasurements=true);
                    x1=payload(1:count_points_to_display_in_constellation);
                    [a,b]=find(x1 ~= 0);
                    x1=x1(a);
                    x1=x1/sqrt(mean(x1.*conj(x1)));
                   
                    diag(x1); isPlotted=0;
                    disp('Press any key in command window');
                    pause;

                end
            end
            if isPlotted == 0
                h=scatterplot(payload(1:count_points_to_display_in_constellation));
                ax = h.CurrentAxes;
                title(ax, {['Payload: ',num2str(num_frame),' Constellation points:',num2str(count_points_to_display_in_constellation)]})
            end

        end

        function plotDemodulatedConstellation(this,num_frame,count_points_to_display_in_constellation)
            if this.isProcessed == 0
                disp('Data should be processed first!');
                return
            end
            if nargin == 2
                count_points_to_display_in_constellation = this.inputData.info.subCarriersCount;
            end
            frame_IQ = this.processedData.demodulatedData(:,1);
            figure();
            plot(frame_IQ(1:count_points_to_display_in_constellation),'r*');
            title({['Frame: ',num2str(num_frame)], ['Constelation points:',num2str(count_points_to_display_in_constellation)]});

        end

        function calcEvmPerformance(this)

        end
        function process(this,silent_mode)
            if this.isLoaded == 0
                disp('Load the data!');
                return;
            end    
            if(nargin<2)
                silent_mode=1;
            end    
            info = this.inputData.info;
            rxWaveform = this.inputData.rxWaveform;
            count_points_to_display_in_constellation = info.subCarriersCount;%3168
            nfft=info.Nfft;
            points_Number = zeros(1,info.symbolsCount);
            snr_array= zeros(1,info.symbolsCount);
            e_noise_per_subcarrier = zeros(1,info.symbolsCount);
            e_sig_per_subcarrier = zeros(1,info.symbolsCount);
            phaseShift = zeros(1,info.symbolsCount);
            demodulatedData=[];
            for num_frame=1:info.symbolsCount
                if num_frame==1
                    stpoint = 1;
                else
                    stpoint =  sum(info.SymbolLengths(1:(num_frame-1)))+1;
                end 
            endpoint = stpoint+info.SymbolLengths(num_frame)-1;
            frame_rx=rxWaveform(stpoint: endpoint);
            n1=(nfft - info.subCarriersCount)/2+1;
            n2=n1+info.subCarriersCount;
            nullidx = [1:n1 (n2+1):nfft]';
            cplen = info.CyclicPrefixLengths(num_frame);
            symOffset = cplen - info.Windowing;
            xx1=frame_rx(1:cplen-info.Windowing);
            xx2=frame_rx(nfft+1:nfft+cplen-info.Windowing);
            Phi = wrapTo2Pi(angle(mean(xx1.*conj(xx2))));%3.665191429188099
            %info.SymbolPhases(num_frame) = Phi;
            phaseShift(num_frame) = Phi;
            w=0;
            Phase_Correction=exp(-(1:length(frame_rx)).*((Phi+2*w*pi)*1i)/nfft);
            frame_rx=frame_rx.*Phase_Correction';
            if num_frame==1 & silent_mode == 0
                figure()
                plot(1:cplen,abs(frame_rx(1:cplen)-frame_rx(nfft+1:end)));
                title({'Abs value of the diffirence between the dopler shift';['corrected cyclic prefixes and windowing. cplen=',num2str(cplen),'windowing=',num2str(info.Windowing)]});
            end 
            xx1=frame_rx(1:cplen-info.Windowing);
            xx2=frame_rx(nfft+1:nfft+cplen-info.Windowing);
            ave_noise_power = mean((xx1-xx2).*conj(xx1-xx2))/2;
            xtmp=frame_rx(symOffset:symOffset+nfft);
            sig_and_noise_power = mean(xtmp.*conj(xtmp));
            snr = 10*log10((sig_and_noise_power-ave_noise_power)/ave_noise_power);

            y1 = ofdmdemod(frame_rx,nfft,cplen,symOffset);%,nullidx
            ny1=mean(y1(1:n1).*conj(y1(1:n1)));
            ey1=mean(y1(n1+1:n2).*conj(y1(n1+1:n2)));
            snr_after_demod=10*log10((ey1-ny1)/ny1);
            snr_array(num_frame) = snr_after_demod;
            e_noise_per_subcarrier(num_frame) = ny1;
            e_sig_per_subcarrier(num_frame) = ey1-ny1;
            frame_IQ=y1(n1+1:n2);
            demodulatedData=[demodulatedData, frame_IQ];
            if silent_mode == 0
                figure()
                plot(frame_IQ(1:count_points_to_display_in_constellation),'r*');
                title({['Frame: ',num2str(num_frame)], ['Constelation points:',num2str(count_points_to_display_in_constellation)]});
            end 
            threshold=max(abs(frame_IQ))-4*sqrt(ny1);
            [corner_pos_y1,b]=find(abs(frame_IQ)>threshold);
            count_points_in_corners_in_frame_IQ = length(corner_pos_y1);
            %num_frame;
            points_Number(num_frame) =count_points_in_corners_in_frame_IQ;
            end


            num_frame=1;
            count_of_payloads=max(info.payloadSymbolsIdxs);
            payloadData=zeros(count_of_payloads,1);
            payloadData(info.payloadSymbolsIdxs)=info.payloadSymbols;
            stpay = (num_frame-1)*info.subCarriersCount+1;
            enpay = stpay + info.subCarriersCount-1;
            payload = payloadData(stpay:enpay);
            if silent_mode == 0
                figure();
                plot(payload(1:count_points_to_display_in_constellation),'b*');
                title({['Payload: ',num2str(num_frame)], ['Constelation points:',num2str(count_points_to_display_in_constellation)]});
                threshold=max(abs(payload))-4*sqrt(ny1);
                [corner_pos_payload,b]=find(abs(payload)>threshold);
                count_points_in_corners_in_payload_1 = size(corner_pos_payload);
                points_Number;
                 % J.-J. van de Beek, M. Sandell and P. O. Borjesson, "ML estimation of time and frequency offset in OFDM systems", IEEE Trans. Signal Process., vol. 45, no. 7, pp. 1800-1805, Jul. 19
            end
            %inputData = struct('info',info,'rxWaveform',rxWaveform);
            this.isProcessed = 1;
            this.processedData = struct('payloadData',payloadData,'snr_array', snr_array,'e_sig_per_subcarrier', e_sig_per_subcarrier,'e_noise_per_subcarrier', e_noise_per_subcarrier,'phaseShift',phaseShift,'demodulatedData',demodulatedData);
            %this.modulationType='64QAM';
        end
        function calcModulationType(this,num_frame)
            %Kumar A. et al. A survey of blind modulation classification techniques for ofdm signals //Sensors. – 2022. – Т. 22. – №. 3. – С. 1020.
            % M=4;
            % qamC4=qammod((0:M-1),M);
            % M=16;
            % qamC16=qammod((0:M-1),M);
            % M=64;
            % qamC64=qammod((0:M-1),M);
            % q=qamC64;
            % E=mean(q.*conj(q));
            % q=q/sqrt(E);
            % std(abs(q)-mean(abs(q)))
            % p1=0.25;
            qamFlag=0;
            if this.isProcessed == 0
                disp('Data should be processed first!');
                return
            end
            frame_IQ = this.processedData.demodulatedData(:,num_frame);
            q=frame_IQ;E=mean(q.*conj(q));q=q/sqrt(E);
            if(std(abs(q)-mean(abs(q)))<0.1)
                this.modulationType='PSK';
            end
            if(std(abs(q)-mean(abs(q)))>0.25)
                this.modulationType='QAM';
                qamFlag=1;
            end
            if qamFlag==1
                X1=q;
                c42x1=mean(abs(q).^4)-abs(mean(q.*q))*abs(mean(q.*q))-2*mean(abs(q).^2)*mean(abs(q).^2);
                c21x1=mean(abs(q).*abs(q));
                if c42x1/c21x1 > 0.65
                    this.modulationType='16QAM';
                end
                if c42x1/c21x1 < 0.65
                    this.modulationType='64QAM';
                end
            end
        end
    end
end