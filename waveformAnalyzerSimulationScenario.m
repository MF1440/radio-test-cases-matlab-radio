% Скрипт для запуска waveformAnalyzer
clc
clear
addpath waveform/

% Запуск конструктора класса WaveformAnalyzer
waveformAnalyzerObject = WaveformAnalyzer('waveformSource.mat', 'waveformInfo.mat');

% вычисляем параметры сигнала
waveformAnalyzerObject.calcWaveformParameters();
sprintf('waveformMeanPower: %f', waveformAnalyzerObject.waveformMeanPower)
sprintf('channelBandwidthHz: %9.0f', waveformAnalyzerObject.channelBandwidthHz)
sprintf('modulationType: %s', waveformAnalyzerObject.modulationType)
sprintf('waveformDurationMcs: %f', waveformAnalyzerObject.waveformDurationMcs)

% вычисляем доплеровский сдвиг 
waveformAnalyzerObject.calcDopplerShift();
sprintf('dopplerShiftHz: %5.1f', waveformAnalyzerObject.dopplerShiftHz)

% вывод графика спектральной плотности мощности
waveformAnalyzerObject.plotPowerSpectrumDensity();



