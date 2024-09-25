% Скрипт для запуска LeastMeanSquare

close all
clear all
clc

% Задать имя файла для сохранения результатов
resultsFilename = "res";

% Задать общие параметры симуляции
simulationParams = struct;
simulationParams.signalType = 'random 2x upsampled';
simulationParams.seed = 1;
simulationParams.iterCount = 100000;

% Задать параметры LMS
simulationParams.updateMethod = 'Normalized LMS';
simulationParams.mu = 0.1;
simulationParams.leakageFactor = 1;

% Задать параметры модели для линеаризации целевой системы
simulationParams.model = 'memory polynomial';
simulationParams.modelOrder = [5 3];

% Создать объект класса LeastMeanSquare
lmsModel = LeastMeanSquare(simulationParams);

% Сгенерировать входной сигнал
inputSignal = lmsModel.generateInput();

% Прогнать входной сигнал через целевую нелинейную систему
nonlinearSignal = lmsModel.processInputThroughSystem(inputSignal);

% Зафитить коэффициенты второй модели для линеаризации целевой системы
linearizedSignal = lmsModel.findModelCoeffs(inputSignal, nonlinearSignal);

% Построить кривую обучения
figObj = lmsModel.plotLearningGraph();

% Сохранить результат в файл
saveas(figObj, resultsFilename+"_learning.png");

% Проанализировать спектры сигналов
figObj = lmsModel.plotSpectra(inputSignal, nonlinearSignal, linearizedSignal);

% Сохранить результат в файл
saveas(figObj, resultsFilename+"_spectra.png");
