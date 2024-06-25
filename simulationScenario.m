clc
clear
addpath quadriga_src/

% ���� 1 ������� ���������� ��� �������
        simulationParams1.horizontalElementsCount = 8;
        simulationParams1.verticalElementsCount = 8;
        simulationParams1.nUsers = 8;
        simulationParams1.beamformerMethod = 'MRT';
        simulationParams1.radAllocationMatrix = [];
% ������ ������������ ������ 1
beamformerObject1 = Beamformer(simulationParams1);
% ������ ��������� �������������
beamformerObject1.calcChannelRealization
% ������ ������ ��������������
beamformerObject1.calcBeamformerWeights
% ������ ������������ �������������
beamformerObject1.calcSpectralPerformance

% ���� 2 ������� ���������� ��� �������
        simulationParams2.horizontalElementsCount = 8;
        simulationParams2.verticalElementsCount = 8;
        simulationParams2.nUsers = 8;
        simulationParams2.beamformerMethod = 'ZF';
        simulationParams2.radAllocationMatrix = [];
% ������ ������������ ������ 2
beamformerObject2 = Beamformer(simulationParams2);
% ������ ��������� �������������
beamformerObject2.calcChannelRealization
% ������ ������ ��������������
beamformerObject2.calcBeamformerWeights
% ������ ������������ �������������
beamformerObject2.calcSpectralPerformance

% �������� ������� �������� �� ������ ������ ������� ����������
beamformerObjects = [beamformerObject1, beamformerObject2];

% ����� ������������ ������������ ������������� �� ���
beamformerObjects.vuzailizeSpectralPerformance
