classdef WaveformAnalyzer < handle
    %% �������� ������
    %
    % 1. ����� ������ ������ (�� ��������� �������) �� ������ OFDM 
    % ���������� �������, � ����� ���������� � ���������� �������������
    %
    % 2. ������ �������: ������������ ��������� �������� � ��������� �������, 
    % ����������� ������������� ��������� �� ����������� ���������,
    % ������������������ �������� ������ ������� ������ (EVM)
    %
    % ������� ������:
    %
    % waveformSource - ������ ���������� ������ baseband ������� �� ��������� ������� 
    % �� ������ OFDM ����������
    %
    % waveformInfo - ��������� � ����������� OFDM ���������� � ��������:
    %       Nfft               - ���-�� �����������-��������� ������� ����������� �������������� �����
    %       SampleRate         - ������� ������������� [��]
    %       CyclicPrefixLengths/SymbolLengths - ����� ������������ ��������� � OFDM �������� [���-�� ��������� �������]
    %       SymbolsCount       - ���-�� �������� �� ���� ����������
    %       subCarriersCount   - ���-�� ����������
    %       payloadSymbols     - �������������� �������
    %       payloadSymbolsIdxs - ������� ��������� ��������� ���������� ��� �������� payloadSymbols
    %
    % ���� ������:
    %
    %       rmsEvm            - ������������������ �������� ������ ������� ������
    %       waveformMeanPower - ������������������ �������� �������� �������
    %       channelBandwidth  - ������ ������ ������
    %       noiseMeanPower    - ������������������ �������� �������� ����
    %       modulationType    - ��� ������������� �����
    %       waveformDuration  - ����� �������������� �������
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
            % ����������� ������. ������ waveform-� �� ��������� ������� � ��������� 
            % � ����������� ����������� ��� ���������� ��������� ������ � 
            % ���������� ����� ������
            
            this.waveformSourse = waveformSourse.rxWaveform;
            this.waveformInfo = waveformInfo.info;
            this.Nscs = this.waveformInfo.subCarriersCount;
            this.Nfft = this.waveformInfo.Nfft;
            this.Nsymbols = this.waveformInfo.symbolsCount;
            
            % ������� ������� ��������� � ����������� ������
            this.parseSignal()
        end
        
        function calcWaveformParameters(this)
            % ����� ������, ����������� ������ ���������� �������������
            % �������: ������ ������ ���������, ������������ ��������
            % �������, ������ ������ ������, ������� �������� ����,
            % ��� ���������, ����� �������������� �������
            
            % ������ ������� ������
            this.calcEvmPerformance();
            % ������ �������� �������
            this.waveformMeanPower = mean(rms(this.yTimeSamples, 2).^2);
            % ������ ������ ������ ������
            this.calcNumerology();
            this.channelBandwidth = this.Nscs * 15000 * 2 ^ (this.numerology);
            % ������ ������������������� �������� ����
            this.noiseMeanPower = mean(rms(this.yFreqSamples - this.xTimeSamples, 2).^2);
            % ������ ������������� �����
            this.getmodulationType()
            % ������ ����� ������������� �������
            this.waveformDuration = size(this.waveformSourse, 1) / ...
                this.waveformInfo.SampleRate;
            % ������� �������������� ������
            this.calcdopplerShift();
        end % ����� function calcWaveformParameters(this)
        
        
        function printParametrs(this)
            % ������� ���������, ������������ � calcWaveformParameters �
            % �������
            
            fprintf('RmsEVM              = %f\n', this.rmsEvm);
            fprintf('Mean Waveform power = %f\n', this.waveformMeanPower);
            fprintf('Bandwidth           = %f, MHz\n', this.channelBandwidth/1e6);
            fprintf('Mean Noise power    = %f\n', this.noiseMeanPower);
            fprintf('Modulation Type     = %s\n', this.modulationType);
            fprintf('Waveform duration   = %f, sec\n', this.waveformDuration);
            fprintf('Mean doppler shift  = %f, Hz\n', mean(this.dopplerShift));
        end
        
        function plotPowerSpectrumDensity(this)
            % ����� ������, ������� ������ ������ ������������ ��������� 
            % �������� �� ���������� ��������
           
            psdx = (1/(this.Nfft)) * mean(abs(this.yFreqSamples).^2, 1);
            freq = 0:this.Nfft-1;
            plot(freq,pow2db(psdx))
            grid on
            title("Power Spectral densiy")
            xlabel("Subcarrier")
            ylabel("Power/Frequency (dB/Scs)")
        end

        function plotPayloadConstellation(this)
            % ����� ������, ����������� ����������� ����������� 
            % ��������� �������������� ��������
            
            scatterplot(this.waveformInfo.payloadSymbols);
            title(['Payload Constellation, Modulation = ', this.modulationType]);
            xticks('auto');
            yticks('auto');
            grid on;
        end
        
    end % ����� Methods � public ��������
    
    methods (Access = private)
        function parseSignal(this)
            % ����� ������� ������������� ������� 1-d ������� ����������� 
            % � �������� ������ � 2-d [SymbolsCount x Nfft] 
            % xTimeSamples, yTimeSamples, yFreqSamples [SymbolsCount x Nfft]
            % prefixTimeSamples [SymbolsCount x max(CyclicPrefixLengths)]
            
            % ���������� ��� �������� OFDM �������� �� ��������� ������
            % � ��������� ������� [SymbolsCount x Nfft]
            xTime = zeros(this.Nfft, 1);
            yTime = zeros(this.Nfft, 1);
            
            % ������ ������ �������� ��� ������� �������������� ������
            prefixTime = zeros(max(this.waveformInfo.CyclicPrefixLengths), 1);
            
            % ������� ��� �������� ���������������� ��������
            % �� ��������� �������
            yFreq = zeros(this.Nfft, 1);
            
            yIdx = 0;
            xIdx = 0;
            % ������� ������� ���������, ���������� �� ������������
            % �������� � ������� � ������. 
            for symbIdx = 1:this.Nsymbols
                prefixLen = this.waveformInfo.CyclicPrefixLengths(symbIdx);
                % ������� ������� �� ������ ������� ����������
                yIdx = sum(this.waveformInfo.SymbolLengths(1:symbIdx-1)) + ...
                    prefixLen;
                yTime = this.waveformSourse(yIdx+1:yIdx+this.Nfft);
                prefixTime = this.waveformSourse(yIdx+1-prefixLen:yIdx);
                % ������ ��������� ������� � ��������� �������
                yFreq = fftshift(fft(yTime, this.Nfft));
                
                % ��� X ������� � 3 � 12 ������� ���������� ������ ������
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
            
        end % ����� ������ parseSignal(this)

        function calcdopplerShift(this)
            % ����� ������, ����������� ������ �������������� ������ ��
            % �������. ��� ������� ������������ ���������� � ������ ��������
            % �����: ������ [Nymbs] �� ���������� ������� �� ������� ���
            % ������� �������
            
            windowShift = this.waveformInfo.Windowing;
            this.dopplerShift = zeros(this.Nsymbols, 1);
            % ����� ������ �������
            deltaT = this.waveformInfo.Nfft / this.waveformInfo.SampleRate;
            
            % ���� �� ���� ��������: ��������� ��� ������� dopplerShift
            for symbIdx = 1:this.Nsymbols
                % ������� �� ��������� ������� ��������� prefixLen ������� �
                % ��� �������
                prefixLen = this.waveformInfo.CyclicPrefixLengths(symbIdx);
                currSymbol = this.yTimeSamples(symbIdx, :);
                prefix = this.prefixTimeSamples(symbIdx, 1:prefixLen);

                % ������ guard ���� �� �������� � �������
                currSymbol = currSymbol(end-prefixLen+1:end-windowShift);
                prefix = prefix(1:end-windowShift);
                
                % ��������� ����������� ���� �������� ����
                deltaPhase = angle(sum(currSymbol .* conj(prefix)));
                % ������� �������������� ������ �� �������� ����
                this.dopplerShift(symbIdx, :) = (deltaPhase) / (2 * pi * deltaT);
            end
        end % ����� calcdopplerShift(this)
        
        function calcNumerology(this)
            % ����� ��� ������� ����������� ��� ��������� ���������
            % ���������� �� �������� ������ ����������� this���������
            % ������� ��� ������� ����� �� 3GPP TS 138.211 ������ 5.3.1
            
            firstprefixLen = this.waveformInfo.CyclicPrefixLengths(1);
            secondprefixLen = this.waveformInfo.CyclicPrefixLengths(2);
            
            if(firstprefixLen ~= secondprefixLen)
                divFactor = secondprefixLen / 144;
                k = (firstprefixLen - 144 * divFactor) / 16;
                this.numerology = log2(k / divFactor);
            else % �������� �� extended �������
                this.numerology = 2;
            end
        end % calcNumerology(this)
        
        function getmodulationType(this)
            % ����� ��� ����������� ���� ���������
            
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
                    error('��������� ��� ��������� �� ������!');
            end
        end 

        function calcEvmPerformance(this)
            % ����� ������, ����������� ������ ��������� ������
            % ����������������� �������
            
            this.rmsEvm = 0;
            % ������ ������ �������� �� ������� �������
            for symbIdx = 1:this.Nsymbols
                % ������ �������� �������� ��������� �������   
                rmsVal = rms(this.xTimeSamples(symbIdx,1:this.Nscs));
                % ������ ������������������ ������ ����� �������� �
                % �������� ��������
                diff = (this.yFreqSamples(symbIdx,1:this.Nscs) - ...
                    this.xTimeSamples(symbIdx,1:this.Nscs)).^2;
                % ������������ ������ �� �������� ������� � ����������
                % �������� �������� ��� ���� ���������� ������
                diff = abs(mean(sqrt(diff) / rmsVal));
                this.rmsEvm = this.rmsEvm + diff;
            end
            % ���������� ������� ������ ��� ���� ��������
            this.rmsEvm = this.rmsEvm / this.Nsymbols;
        end % ����� function calcEvmPerformance
        
    end % ����� methods � private ��������
    
end % ����� class WaveformAnalyzer