clc
clear
addpath waveform/

% Чтение baseband сигнала во временной области и структуры с его
% параметрами
waveformSource = load('waveformSource.mat');
waveformInfo = load('waveformInfo.mat');

% Запуск конструктора класса
waveformAnalyserObject = WaveformAnalyzer(waveformSource, waveformInfo);
% расчет и вывод в консоль параметров радиоволны
waveformAnalyserObject.calcWaveformParameters();
waveformAnalyserObject.printParametrs();
% построение спектральной плотности сигнала
waveformAnalyserObject.plotPowerSpectrumDensity();
% построение созвездия переданных символов
waveformAnalyserObject.plotPayloadConstellation();
disp("-----End Programm-----");