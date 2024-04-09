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
        
        % additional properties for conveinience
        dopplerShiftAllSym
        waveformInfo
        waveformSource
        uniqueSymbols
    end

    methods
        function this = WaveformAnalyzer(waveformInfoFile, waveformSourceFile)
            % read information about data
            this.waveformInfo = load('waveform/waveformInfo.mat').info;
            % read data waveform
            this.waveformSource = load('waveform/waveformSource.mat').rxWaveform;
        end

        function calcWaveformParameters(this)
            % mean power
            this.waveformMeanPower = mean(abs(this.waveformSource).^2);

            % find channel bandwidth [Hz]
            scs = this.waveformInfo.SampleRate / this.waveformInfo.Nfft; % subcarrier spacing [Hz]
            this.channelBandwidth = scs * this.waveformInfo.subCarriersCount;

            % detect modulation type
            % assume that all symbols are presented in payloadSymbols)
            this.uniqueSymbols = unique(this.waveformInfo.payloadSymbols);
            numOfUniqueSymbols = length(this.uniqueSymbols);

            switch numOfUniqueSymbols
               case 4
                  this.modulationType = 'QPSK';
               case 16
                  this.modulationType = 'QAM16';
                case 64
                  this.modulationType = 'QAM64';
                case 256
                  this.modulationType = 'QAM256';
                case 1024
                  this.modulationType = 'QAM1024';
               otherwise
                  this.modulationType = 'Unknown modulation type';
                  print('Unknown modulation type');
            end

            % calculate doppler shift
            this.calcDopplerSHift();

            % calculate waveform duration [s]
            this.waveformDuration = length(this.waveformSource) / this.waveformInfo.SampleRate;
        end
        
        function calcDopplerSHift(this)
            % cyclic prefix correlation-based Doppler Frequency shift estimation

            Nfft = this.waveformInfo.Nfft;
            Fs = this.waveformInfo.SampleRate;
            slotCorr = 0;
            for symIdx = 1:length(this.waveformInfo.CyclicPrefixLengths)
                lenCP = this.waveformInfo.CyclicPrefixLengths(symIdx);

                % cyclic prefix for the current OFDM symbol
                prefixStart = 1 + Nfft * (symIdx - 1);
                prefixEnd = prefixStart + lenCP - 1;
                symCPrefix = this.waveformSource(prefixStart:prefixEnd);

                % tail for the current OFDM symbol
                tailStart = 1 + Nfft * symIdx - lenCP;
                tailEnd = Nfft * symIdx;
                symTail = this.waveformSource(tailStart:tailEnd);

                % correlation within OFDM symbol (tail and CP)
                symCorr = sum(symTail .* conj(symCPrefix));
                slotCorr = slotCorr + symCorr;

                % doppler shift for the current symbol
                this.dopplerShiftAllSym{symIdx} = - Fs * (angle(symCorr) / (2 * pi * Nfft));
            end
            % doppler shift for the whole slot
            this.dopplerShift = -Fs * (angle(slotCorr) / (2 * pi * Nfft));
        end

        function plotPowerSpectrumDensity(this, fc)
            % read parameters
            Nfft = this.waveformInfo.Nfft;
            Fs = this.waveformInfo.SampleRate;

            % estimate PSD [linear scale]
            [psd,f] = pwelch(this.waveformSource, Nfft, Nfft/2, Nfft, Fs);

            % go to [dB] scale
            psd_dB = pow2db(psd);

            % visualize PSD
            figure(1);
            plot((f - Fs/2) / 1e6, fftshift(psd_dB));
            grid;
            xlabel('Frequency [MHz]');
            ylabel('Power [dB]');
            ylim([min(psd_dB), max(psd_dB) / 1.25]);
            xlim([-Fs/2e6, Fs/2e6]);
            title('Power Spectral Density (PSD)');
        end

        function plotPayloadConstellation(this)
            figure(2);
            scatter(real(this.uniqueSymbols),imag(this.uniqueSymbols));
            max_val = 1.5*round(max(abs(this.uniqueSymbols)))/2;
            grid;
            xlim([-max_val,max_val]);
            ylim([-max_val,max_val]);
            xticks([-max_val:0.25:max_val]);
            yticks([-max_val:0.25:max_val]);
            axis('equal');
            title([this.modulationType,' constellation']);
        end

        function calcEvmPerformance(this)

        end
    end
end