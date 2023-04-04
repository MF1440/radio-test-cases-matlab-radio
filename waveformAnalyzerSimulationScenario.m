% Скрипт для запуска waveformAnalyxer

clc
clear

load('./waveform/waveformInfo.mat');
load('./waveform/waveformSource.mat');

info.modulationType = 'QAM-64';

waveformAnalyzer = WaveformAnalyzer(info, rxWaveform);
waveformAnalyzer.calcWaveformParameters();
waveformAnalyzer.plotPowerSpectrumDensity();
waveformAnalyzer.plotPayloadConstellation();
