classdef WaveformAnalyzer < handle
    %% �������� ������
    %
    % 1. ����� ������ ������ (�� ��������� �������) �� ������ OFDM ���������� �������, � ����� ���������� � ���������� �������������
    %
    % 2. ������ �������: ������������ ��������� �������� � ��������� �������, ����������� ������������� ��������� �� ����������� ���������,
    % ������������������ �������� ������ ������� ������ (EVM)
    %
    % ������� ������:
    %
    % waveformSource - ������ ���������� ������ baseband ������� �� ��������� ������� �� ������ OFDM ����������
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
        function this = WaveformAnalyzer()
            % ����������� ������. ������ waveform-� �� ��������� ������� � ��������� � �����������
            % ����������� ��� ���������� ��������� ������ � ���������� ����� ������
        end

        function calcWaveformParameters(this)

        end

        function calcdopplerSHift

        end

        function plotPowerSpectrumDensity(this)

        end

        function plotPayloadConstellation(this)

        end

        function calcEvmPerformance(this)

        end
    end
end