% Скрипт для запуска waveformAnalyxer
clc
clear all

addpath waveform/
% Загрузка исходных данных
load waveformInfo
load waveformSource
paramWaveformInfo=info;
waveformSource=txWaveform;

% Запуск конструктора класса
objectWaveformAnalyzer = WaveformAnalyzer(paramWaveformInfo,waveformSource);

% Рассчет параметров сигнала (средняя мощность, полоса пропускания,тип модуляции,длительность сигнала)
objectWaveformAnalyzer.calcWaveformParameters();

% Построение графика мощности
objectWaveformAnalyzer.plotPowerSpectrumDensity();

% Вывод параметров сигнала 
fprintf("Среднеквадратичная мощность сигнала:" + objectWaveformAnalyzer.waveformMeanPower + " Гц \n" );
fprintf("Ширина полосы канала:" + objectWaveformAnalyzer.channelBandwidth + " Гц \n");
fprintf("Тип модуляционной схемы: " + objectWaveformAnalyzer.modulationType + "\n");
fprintf("Длина анализируемого сигнала:"+ objectWaveformAnalyzer.waveformDuration + " c\n");