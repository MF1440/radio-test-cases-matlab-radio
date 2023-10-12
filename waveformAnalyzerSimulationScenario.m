% Скрипт для запуска waveformAnalyxer
clc
clear
addpath waveform/

% Запуск конструктора класса WaveformAnalyzer
waveformAnalyzerObject = WaveformAnalyzer('waveformSource.mat', 'waveformInfo.mat');

% вычисляем параметры сигнала
waveformAnalyzerObject.calcWaveformParameters();
sprintf('waveformMeanPower: %f',waveformAnalyzerObject.waveformMeanPower)
sprintf('channelBandwidth_Hz: %9.0f',waveformAnalyzerObject.channelBandwidth_Hz)
sprintf('modulationType: %s', waveformAnalyzerObject.modulationType)
sprintf('waveformDuration_mcs: %f', waveformAnalyzerObject.waveformDuration_mcs)

% вычисляем доплеровский сдвиг 
waveformAnalyzerObject.calcDopplerShift();
sprintf('dopplerShift_Hz: %5.1f',waveformAnalyzerObject.dopplerShift_Hz)

% вывод графика спектральной плотности мощности
waveformAnalyzerObject.plotPowerSpectrumDensity();



