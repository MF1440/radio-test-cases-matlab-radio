% Скрипт для запуска waveformAnalyxer
close all
clear all
silentMode = 1;
fname1='waveformInfo.mat';% должны лежать в подпапке waveform
fname2='waveformSource.mat';
[ProcessedData,inputData]  = load_and_process(silentMode,fname1,fname2);
%функциональный аналог проектируемого класса, если поставить silentMode = 0 больше картинок
waveA=WaveformAnalyzer();
waveA.load_inputData(inputData);
waveA.validate_inputData();
[channelBandwidth,waveformMeanPower,waveformDuration] = waveA.calcWaveformParameters()
waveA.process();%обязательная функция после которой можно рисовать графики
waveA.plotPowerSpectrumDensity();

num_frame =1;
% строит демодулированные созвездия с неизвестной начальной фазой
waveA.plotDemodulatedConstellation(num_frame);


[f_dopler speed] = waveA.calcdopplerSHift()
waveA.calcModulationType(num_frame);%определяет тип модуляции в первом принятом созвездии
waveA.plotPayloadConstellation(num_frame);


