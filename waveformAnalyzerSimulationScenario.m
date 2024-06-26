% Скрипт для демонстрации работы класса WaveformAnalyzer для дальнейшей 
% обработки данных и заполнения полей класса
clc
clear
close all

% Загрузка сигнала во временной области и структуры информации,
% используемой классом WaveformAnalyzer
load('waveform\waveformInfo.mat')
load('waveform\waveformSource.mat')

% Внесение дополнительного частотного сдвига:
freqOffset = 1e3; % значение дополнительного частотного сдвига [Гц]
t = 0: 1 / info.SampleRate: (length(rxWaveform) - 1) * 1 / info.SampleRate;
rxWaveform = rxWaveform .* exp(1i * 2 * pi * freqOffset * t).';

% Выбор метода измерения ширины полосы пропускания:
measInfo.channelBandwidth.mode = "obw";
% Задание процента от общей передаваемой мощности, используемый при расчете
% полосы пропускания:
measInfo.channelBandwidth.powerPercentage = 99.5; % [%]

% Создание объекта класса и вычисление параметров сигнала
WaveformAnalyzerObject1 = WaveformAnalyzer(rxWaveform,info, measInfo);
WaveformAnalyzerObject1.calcWaveformParameters()

% Вывод рассчитанных значений параметров сигнала и пострение спектральной
% плотности мощности
disp(WaveformAnalyzerObject1)
WaveformAnalyzerObject1.plotPowerSpectrumDensity()

%%
% Вывод рассчитанной ширины полосы пропускания:
fprintf("ChannelBandwidth (obw mode): %0.3f Гц\n",WaveformAnalyzerObject1.channelBandwidth)

% Изменение метода расчета ширины полосы пропускания:
clear measInfo
measInfo.channelBandwidth.mode = "subCarrierCount";

% Вычисление параметров сигнала
WaveformAnalyzerObject2 = WaveformAnalyzer(rxWaveform, info, measInfo);
WaveformAnalyzerObject2.calcWaveformParameters()

% Вывод рассчитанной ширины полосы пропускания:
fprintf("ChannelBandwidth (subCarrierCount mode): %0.3f Гц\n",WaveformAnalyzerObject2.channelBandwidth)