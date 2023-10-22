% Скрипт для запуска waveformAnalyxer
clc
clear
close all

% Загрузка исходных данных
addpath waveform/
info = load('waveformInfo.mat').info;
waveform = load("waveformSource.mat").rxWaveform;

% Запуск конструктора класса WaveformAnalyzer
waveformAnalyzerObj = WaveformAnalyzer(waveform, info);

% Очищаем исходные данные
clear info waveform

% Расчет параметров сигнала
waveformAnalyzerObj.calcWaveformParameters();
fprintf('Waveform Parameters: \n');
fprintf('Mean Power: %f \n', waveformAnalyzerObj.waveformMeanPower);
fprintf('Bandwidth: %.0f Hz \n', waveformAnalyzerObj.channelBandwidth);
fprintf('Modulation Type: %s \n', waveformAnalyzerObj.modulationType);
fprintf('Duration: %.2f mcs \n', waveformAnalyzerObj.waveformDuration * 1e6);
fprintf('Doppler Shift: %f Hz \n', waveformAnalyzerObj.dopplerShift);

% Вывод спектральной плотности средней мощности в частотной области
waveformAnalyzerObj.plotPowerSpectrumDensity();

% Вывод созвездия на комплексной плоскости
waveformAnalyzerObj.plotPayloadConstellation();
