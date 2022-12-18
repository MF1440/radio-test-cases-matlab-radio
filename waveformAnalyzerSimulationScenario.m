% Скрипт для запуска waveformAnalyxer
clc
clear

wfDirPath = 'waveform';
wfInfoFName = 'waveformInfo.mat';
wfSourseFName = 'waveformSource.mat';

wfStorage = WaveformStorage([wfDirPath filesep wfInfoFName], ...
                            [wfDirPath filesep wfSourseFName]);

wfAnalyzer = WaveformAnalyzer(wfStorage);
wfAnalyzer.calcWaveformParameters();
wfAnalyzer.showAnalyzeResult();
wfAnalyzer.plotPowerSpectrumDensity();