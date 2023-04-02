% Скрипт для запуска waveformAnalyxer

clc
clear

load('./waveform/waveformInfo.mat');
load('./waveform/waveformSource.mat');

waveformAnalyzer = WaveformAnalyzer(info, rxWaveform);
waveformAnalyzer.calcWaveformParameters();
waveformAnalyzer.plotPowerSpectrumDensity();
waveformAnalyzer.plotPayloadConstellation();
