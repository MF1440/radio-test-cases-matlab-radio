% Скрипт для запуска waveformAnalyxer

%%
clc
clear
addpath waveform/
%%
filePathInfo = "waveform/waveformInfo.mat";
filePathSource = "waveform/waveformSource.mat";

load(filePathInfo) 
load(filePathSource)

% Запуск конструктора класса
waveformAnalyzerObject = WaveformAnalyzer(info, rxWaveform);

% Определяем центральную частоту спектра (Гц)
centralFrequency = 11.7e9;

% Определяем скорость приемника отностительно передатчика (м/с)
radialSpeed = 100 * 1e3 / 3600;

% Расчет Доплеровского сдвига 
waveformAnalyzerObject.calcDopplerShift(centralFrequency, radialSpeed);

% построение psd
waveformAnalyzerObject.plotPowerSpectrumDensity(rxWaveform, info.SampleRate);
