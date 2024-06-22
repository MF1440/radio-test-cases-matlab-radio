classdef Beamformer < handle
    %% �������� ������
    % 1. ����� ���������� ��������� ��������� ������������� ������� MIMO
    % ������� [nTransmitAntennas x nUsers].
    %
    % 2. �� ������ ��������� ������������� � ��������� ������� ����������
    % ������ ������� �������������� ��������� ������ "MRT" ��� "ZF".
    %
    % 3. �������� ������������� ����������� �������������� ���������
    % ������������������ ������������� - ������������ �������������.
    %
    % 4. �� ����� �� ����� ��������������� ���� � ����������� ���������
    % �� ����������� "horizontalElementsCount" � �� ���������
    % "verticalElementsCount".
    %
    % 5. ����������� ���������� ����� ����������� ������� �� ������
    % �������������� ���������� �������.

    properties (Access = private)
        horizontalElementsCount
        verticalElementsCount
        allocationMatrix
        multiuserLayout
        nUsers
        snrdB
    end

    properties
        beamformerWeights
        beamformerMethod
        channelCoeffs
        spectralPerformance
    end

    methods

        function this = Beamformer(simulationParams)
            % ����������� ������
            % ������� ������� ���������
            this.horizontalElementsCount = simulationParams.horizontalElementsCount;
            this.verticalElementsCount = simulationParams.verticalElementsCount;
            this.nUsers = simulationParams.nUsers;
            this.beamformerMethod = simulationParams.beamformerMethod;
            this.allocationMatrix = simulationParams.radAllocationMatrix;

            % ��������� ��������� �������������
            this.calcChannelRealization;

            % ������ ������ ��������������
            this.calcBeamformerWeights;

            % ������ ������������ ������������� ������������� � ������
            % ������� ��������������
            this.calcSpectralPerformance;
        end

        function calcChannelRealization(this)
            % ����� ������, ����������� ��������� ��������� ������������� �
            % ��������� �������. ���������:
            % ������� [nUsers x (horizontalElementsCount x verticalElementsCount)]

            % ������������� ������
            s = qd_simulation_parameters;
            % ������� �� ������� ������������ ��������� ������������ [11.7 ���]
            s.center_frequency = 11.7e9;
            % ��������� ������ ����������
            s.show_progress_bars = 0;
            % ������ �������������
            layout = qd_layout(s);
            % ���������� ������� �� �� �� ������ 500 ��
            layout.tx_position = [0 0 500e3]';
            % �������� ������� �� ����� ������� ����� ��� �������� � �����
            layout.tx_track.orientation = [0; -pi/2; 0];
            % ������� ���������� �������������
            layout.no_rx = this.nUsers;
            % ����������� ���������� ������������� �� ����� � ������� 100 �� ��
            % �������������� ����� ��
            layout.randomize_rx_positions(100e3, 0, 0, 0);
            % ���������� ����������� ������ ���������������� ����������
            uePos = layout.tx_track.initial_position;
            orientation = zeros(3, 1);
            for userIdx = 1 : this.nUsers
                uePosTemp = layout.rx_track(1, userIdx).initial_position;
                rt = uePos - uePosTemp;
                rt = rt / norm(rt);
                orientation(2) = asin(rt(3));
                orientation(3) = atan2(rt(2), rt(1));
                layout.rx_track(1, userIdx).orientation = orientation;
            end
            % ������ �������� ������� �� (��������������� �������)
            % ��������������� �����
            polInd = 1;
            % ������������� ���������� (��� ����� �����)
            elementSpacing = 0.5;
            % ���������� �������
            verticalPanels = 1;
            horizontalPanels = 1;
            % ������������ ����������
            vertPanSpacing = 0;
            horizPanSpacing = 0;
            % ���������� ������� ��
            satTransmitAnt = qd_arrayant('3gpp-nr', this.horizontalElementsCount,...
                this.verticalElementsCount,...
                s.center_frequency, polInd, 0, elementSpacing, verticalPanels,...
                horizontalPanels, vertPanSpacing, horizPanSpacing);
            % �������� ������� �������������
            ueReceiveAnt = qd_arrayant('parabolic', 0.3,  s.center_frequency,...
                [], 1, 1, [], []);
            % ��������� ������� ������������� � ��
            layout.tx_array = satTransmitAnt;
            layout.rx_array = ueReceiveAnt;
            % ���������� ��������
            layout.set_scenario('Freespace');
            % ��������� ��������� �������������
            channelBuilder = layout.init_builder(1, 1, 'accurate');
            channelBuilder.gen_parameters;
            c = channelBuilder.get_channels;
            % ����� ��������� ������������
            rawChannelCoeffs = transpose(...
                reshape([ c.coeff ], [ satTransmitAnt.no_elements, layout.no_rx ]));
            % �������� �������� ������������ ��������
            averacalcransmissionGain = sum(sum(abs(rawChannelCoeffs) .^ 2))...
                / (satTransmitAnt.no_elements * layout.no_rx);
            % ������������� ������� ������ �����
            this.channelCoeffs = rawChannelCoeffs ./ sqrt(averacalcransmissionGain);
            this.multiuserLayout = layout;
        end % ����� function calcChannelRealization

        function calcBeamformerWeights(this)
            % ����� ������, ����������� ������ ������� ������������� ���
            % �������������� ������������ ����������. ����� ������������ ��� ������
            % ������� "MRT" ��� "ZF". ���������:
            % ������� [(horizontalElementsCount x verticalElementsCount) x nUsers]

            % ���������� ���������� ������
            nTransmitAntennas = size(this.channelCoeffs, 2);
            % ���� ��� ���������� ������� ����� �������� �� ����� �������������� ��
            if isempty(this.allocationMatrix)
                D = repmat(eye(nTransmitAntennas), [ 1 1 this.nUsers ]);
            end
            % ������������� ������� ��� ������� ������������
            this.beamformerWeights = zeros(size(this.channelCoeffs'));
            switch this.beamformerMethod
                case 'MRT'
                    % ����������� ������� ������������ �������
                    for userIdx = 1 : this.nUsers
                        % ������������ ������ c ������ ������� D
                        channelVector = (this.channelCoeffs(userIdx, :) * D(:, :, userIdx))';
                        % ��������� ���������
                        this.beamformerWeights(:, userIdx) = channelVector / norm(channelVector);
                    end
                case 'ZF'
                    % ����������� ������� ������������ �������
                    for userIdx = 1 : this.nUsers
                        % ������������ ������ c ������ ������� D
                        effectiveChannel = (this.channelCoeffs * D(:, :, userIdx))';
                        % ������ �������������� ��������� �������
                        channelInversion = effectiveChannel / (effectiveChannel' * effectiveChannel);
                        % ������������ ������� �������������
                        this.beamformerWeights(:,userIdx) = channelInversion(:, userIdx) / norm(channelInversion(:, userIdx));
                    end
                otherwise
                    error('��������� ��� ������� �������������� �� ������!');
            end
        end % ����� function calcBeamformerWeights(this)

        function calcPowerAllocation(this)
            % ����� ������, ����������� ������ ������������� �������� ��������� ��������������
            % ������������ �������� ������� ���������� ���������� this.snrdB.
        end

        function calcSpectralPerformance(this)
            % ����� ������, ����������� ������ ������������ �������������
            % ������������� � ������ ������� �������������� ���������� � �������
            % � ��������� ������� ������� MIMO

            % ������� ��������� ��������������� �������� ��� � dB
            this.snrdB = linspace(- 40,5,45);
            % ������ ��������� �������
            channelGains = abs(this.channelCoeffs * this.beamformerWeights) .^ 2;
            % ������ �������� ������������ ������� (������� ������ �����������)
            signalGains = diag(channelGains);
            % ������ ����������������� ������������ �������
            % (����� ���� ��������� ������ ������� �� ������� ������������� ��������)
            interferenceGains = sum(channelGains, 2) - signalGains;
            % ������ ������������ ������������� �� ������� ������� ��� k-�� ������������ 
            % � ��� ������� (������������� �� ���� �������/�������������)
            this.spectralPerformance = sum(log2(1 + signalGains ./ (db2pow(- this.snrdB) + interferenceGains)), 1);
        end % ����� function calcSpectralPerformance

        function vuzailizeLayout(this)
            % ����� ������, ����������� ����������� ����������� ���������� ������.
            % ������������ �� � ������������� ����� ������������ � ����������
            % ������� ���������.
            this.multiuserLayout.visualize();
        end

        function vuzailizeSpectralPerformance(this)
            % ����� ������, ����������� ����������� ����������� ���������� ������.
            % ��������� ����������� ������������ ������������� �� ���
            legg = {0};
            for objIdx=1:numel(this)
                plot(this(objIdx).snrdB, this(objIdx).spectralPerformance);
                legg(objIdx) = {this(objIdx).beamformerMethod};
                hold on
            end
            hold off
            legend(legg);
            title('Precoding scheme comparision');
            xlabel('SNR, dB');
            ylabel('Spectral Performance, bits/s/Hz');
            xticks('auto');
            yticks('auto');
            grid on;
        end

    end
end

