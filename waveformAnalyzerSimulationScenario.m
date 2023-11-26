% Скрипт для запуска waveformAnalyxer
clc
clear 
close all

addpath waveform/
infoWaveform = load('waveformInfo.mat').info;
samplesWaveform = load('waveformSource.mat').rxWaveform;

waveformAnalyzerObj = WaveformAnalyzer(infoWaveform,samplesWaveform);

waveformAnalyzerObj.calcWaveformParameters();
waveformAnalyzerObj.plotPowerSpectrumDensity();

fprintf('Далее приведены параметры сигнала rxWaveform и их числовые значения \n');
fprintf('Среднеквадратическая мощность сигнала: %2.5f \n',waveformAnalyzerObj.waveformMeanPower);
fprintf('Ширина полосы сигнала %2.5f Мгц \n', waveformAnalyzerObj.channelBandwidth*1e-6);
fprintf('Тип модуляции: %s \n', waveformAnalyzerObj.modulationType);
fprintf('Длительность сигнала: %1.6f мс \n',waveformAnalyzerObj.waveformDuration*1e3);
fprintf('Доплеровский сдвиг: %d Гц \n',waveformAnalyzerObj.dopplershift);


