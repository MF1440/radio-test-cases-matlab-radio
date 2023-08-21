% Скрипт для запуска waveformAnalyxer
clc
clear
close

% Загрузка тестовых данных
load('waveform/waveformSource.mat')
load('waveform/waveformInfo.mat')

% Вызов конструктора класса WaveformAnalyzer объекта 1
waveformAnalyzerObject1 = WaveformAnalyzer(rxWaveform, info);
% Вывод графика PSD
waveformAnalyzerObject1.plotPowerSpectrumDensity();

% Частота доплеровского сдвига
dopplerShiftFs = 1.5e+6;
% Временной интервал символа OFDM
timeAxis = (0 : 1 / info.SampleRate : sum(info.SymbolLengths) / info.SampleRate-1 / info.SampleRate);
% Построение искажающей последовательности доплеровского сдвига
dopplerDistortionSequence = exp( - 2 * pi * 1j * dopplerShiftFs .* timeAxis) .';

% Вызов конструктора класса WaveformAnalyzer объекта 2
waveformAnalyzerObject2 = WaveformAnalyzer(rxWaveform .* dopplerDistortionSequence, info);
% Расчёт доплеровского сдвига класса WaveformAnalyzer объекта 2
waveformAnalyzerObject2.calcDopplerShift(rxWaveform);

%Вывод результатов оценки доплеровского сдвига
disp(['Ожидаемый доплеровского сдвига:', num2str(round(dopplerShiftFs / 1e+3)), ' кГц']);
disp(['Оценка доплеровского сдвига:', num2str(round(waveformAnalyzerObject2.dopplerShift / 1e+3)), ' кГц']);