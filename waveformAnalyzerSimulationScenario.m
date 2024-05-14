% Скрипт для запуска waveformAnalyzer
clc
clear
load('waveform/waveformInfo.mat');
load('waveform/waveformSource.mat');

% Запуск конструктора класса
WaveformAnalyzerObject1 = WaveformAnalyzer(rxWaveform,info);

% подсчет параметров
WaveformAnalyzerObject1.calcWaveformParameters;

% Построение графиков спектральной плотности мощности и созвездия payload 
% сигнала
WaveformAnalyzerObject1.plotPowerSpectrumDensity;
WaveformAnalyzerObject1.plotPayloadConstellation;

% вывод параметров
disp('тип модуляции:')
disp(WaveformAnalyzerObject1.modulationType)
disp('длительность (сек):')
disp(WaveformAnalyzerObject1.waveformDuration)
disp('среднеквадратическое значение мощности:')
disp(WaveformAnalyzerObject1.waveformMeanPower)

