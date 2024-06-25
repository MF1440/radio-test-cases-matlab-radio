clc
clear
addpath waveform/

% ������ baseband ������� �� ��������� ������� � ��������� � ���
% �����������
waveformSource = load('waveformSource.mat');
waveformInfo = load('waveformInfo.mat');

% ������ ������������ ������
waveformAnalyserObject = WaveformAnalyzer(waveformSource, waveformInfo);
% ������ � ����� � ������� ���������� ����������
waveformAnalyserObject.calcWaveformParameters();
waveformAnalyserObject.printParametrs();
% ���������� ������������ ��������� �������
waveformAnalyserObject.plotPowerSpectrumDensity();
% ���������� ��������� ���������� ��������
waveformAnalyserObject.plotPayloadConstellation();
disp("-----End Programm-----");