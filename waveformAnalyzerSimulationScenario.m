% Скрипт для запуска waveformAnalyzer
close all
clear all
clc

load(['.' filesep 'waveform' filesep 'waveformSource.mat']);
load(['.' filesep 'waveform' filesep 'waveformInfo.mat']);

waveformAnalyzerObject = WaveformAnalyzer(rxWaveform, info);

%% Расчет и заполнение полей класса WaveformAnalyzer и метода calcDopplerShift
% Список полей:
% -waveformMeanPower
% -channelBandwidth
% -modulationType
% -waveformDuration
% -dopplerShift

waveformAnalyzerObject.calcWaveformParameters();

fprintf('Поле waveformMeanPower: %f \n', waveformAnalyzerObject.waveformMeanPower)

fprintf('Поле channelBandwidth в МГц: %f \n', waveformAnalyzerObject.channelBandwidth*1e-6)

fprintf('Поле modulationType: %s \n', waveformAnalyzerObject.modulationType)

fprintf('Поле waveformDuration: %f \n', waveformAnalyzerObject.waveformDuration)

fprintf('Поле dopplerShift в Гц: %f \n', waveformAnalyzerObject.dopplerShift)

%% Отображение СПМ сигнала
waveformAnalyzerObject.plotPowerSpectrumDensity();

