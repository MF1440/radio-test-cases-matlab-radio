classdef LeastMeanSquare < handle
    %% Описание класса
    
    properties (Access = private)
        
        % Параметры целевой нелинейной системы
        systemCoeffs = [1, 0.2]     % коэффициенты анализируемой системы
        
        % Параметры модели для линеаризации целевой системы
        model                       % тип модели: polynomial, memory polynomial, hammestein, etc
        modelOrder              % порядок модели: [Nx1] for polynomial, [NxM] for memory polynomial, etc
        modelCoeffs                 % коэффициенты модели
        mseArray               % массив значений mse
        accumulatedSquaredError % накопленная мощность ошибки
        
        % Параметры LMS
        updateMethod = 'LMS'  % метод обновления коэффициентов
        mu = 0.1                         % скорость обучения LMS
        leakageFactor = 1               % leakage factor LMS
        
        % Параметры симуляции
        signalType = 'random'  % тип входного сигнала
        seed = 1                       % зерно инициализации генератора случайных чисел
        inputScaleCoeffs = 0.2      % коэффициент масщтабирования входного воздействия на систему
        iterCount = 1000                   % кол-во итераций LMS
        
    end
    
    methods
        
        function this = LeastMeanSquare(simulationParams)
            % Конструктор класса
            
            % Проверить, что обязательные параметры заданы и сохранить их
            obligatoryFieldList = ["model"; "modelOrder"];
            for obligatoryFieldIdx = 1:length(obligatoryFieldList)
                obligatoryFieldThis = obligatoryFieldList(obligatoryFieldIdx);
                if isfield(simulationParams, obligatoryFieldThis)
                    this.(obligatoryFieldThis) = simulationParams.(obligatoryFieldThis);
                else
                    error("Miss obligatory field "+obligatoryFieldThis);
                end
            end
            
            % Проинициализировать коэф модели в зависимости от её типа
            switch this.model
                
                case 'polynomial'
                    
                    assert(length(this.modelOrder) == 1, "Wrong order for polynomial model");
                    
                    this.modelCoeffs = zeros(this.modelOrder(1), 1);
                    
                case 'memory polynomial'
                    
                    assert(length(this.modelOrder) == 2, "Wrong order for memory polynomial model");
                    
                    this.modelCoeffs = zeros(this.modelOrder(1) * this.modelOrder(2), 1);
                    
                otherwise
                    
                    error("Not supported model");
                    
            end
            
            % Сохраняем необязательные параметры, если они заданы
            optionalFieldList = ["updateMethod"; "mu"; "leakageFactor"; "signalType"; "seed";"inputScaleCoeffs";"iterCount"];
            for optionalFieldIdx = 1:length(optionalFieldList)
                optionalFieldThis = optionalFieldList(optionalFieldIdx);
                if isfield(simulationParams, optionalFieldThis)
                    this.(optionalFieldThis) = simulationParams.(optionalFieldThis);
                else
                    warning("Default "+optionalFieldThis+"="+string(this.(optionalFieldThis))+" is used");
                end
            end
            
            % Наконец, инициализируем память для расчета ошибок
            this.mseArray = zeros(1, this.iterCount);
            this.accumulatedSquaredError = 0;
        end
        
        function inputSignal = generateInput(this)
            % Сгенерировать входной сигнал (линейный)
            
            % Инициализировать генератор случайных чисел
            rng(this.seed);
            
            switch this.signalType
                
                case 'random'
                    
                    % Сгенерировать входной сигнал из CN(0, s^2), где s = inputScaleCoeffs
                    inputSignal = this.inputScaleCoeffs / sqrt(2) * (randn(1, this.iterCount) + 1i * randn(1, this.iterCount));
                    
                case 'random 2x upsampled'
                    
                    % Хардкодим upsampling factor
                    upsamplingFactor = 2;
                    
                    % Сгенерировать входной сигнал из CN(0, s^2), где s = inputScaleCoeffs
                    inputSignal = this.inputScaleCoeffs / sqrt(2) * (randn(1, this.iterCount) + 1i * randn(1, this.iterCount));
                    
                    % Апсемплировать, чтобы получить прямоугольный спектр
                    inputSignal = resample(inputSignal, upsamplingFactor, 1);
                    
                    inputSignal = inputSignal(1:this.iterCount);
                    
                otherwise
                    
                    error("Unsupported signal type");
                    
            end
            
        end
        
        function nonlinearSignal = processInputThroughSystem(this, inputSignal)
            % Прогнать входной сигнал через целевую нелинейную систему
            
            % Проверить валидность входного вектора
            assert(isrow(inputSignal), "Input signal must be row vector");
            assert(length(inputSignal) == this.iterCount, "Input signal must have size [1x"+string(this.iterCount)+"]");
            
            % Инициализировать массив для выходного сигнала
            nonlinearSignal = zeros(size(inputSignal));
            
            % Итеративно применить нелинейность каждого порядка
            for systemOrderIdx = 1:length(this.systemCoeffs)
                nonlinearSignal = nonlinearSignal + this.systemCoeffs(systemOrderIdx) * inputSignal .* abs(inputSignal).^(systemOrderIdx-1);
            end
            
        end
        
        function linearizedSignal = findModelCoeffs(this, desiredSignal, nonlinearSignal)
            % Зафитить коэффициенты второй модели для линеаризации целевой системы
            
            % Проверить валидность входных векторов
            assert(isrow(desiredSignal), "Desired signal must be row vector");
            assert(length(desiredSignal) == this.iterCount, "Desired signal must have size [1x"+string(this.iterCount)+"]");
            assert(isrow(nonlinearSignal), "Non-linear signal must be row vector");
            assert(length(nonlinearSignal) == this.iterCount, "Non-linear signal must have size [1x"+string(this.iterCount)+"]");
            
            switch this.model
                
                case 'polynomial'
                    
                    % Сформировать входные сигналы для LMS
                    modelInput = zeros(this.modelOrder(1), this.iterCount);
                    for systemOrderIdx = 1:this.modelOrder(1)
                        modelInput(systemOrderIdx,:) = nonlinearSignal .* abs(nonlinearSignal).^(systemOrderIdx-1);
                    end
                    
                case 'memory polynomial'
                    
                    % Сформировать входные сигналы для LMS
                    modelInput = zeros(this.modelOrder(1) * this.modelOrder(2), this.iterCount);
                    for memoryOrderIdx = 1:this.modelOrder(2)
                        for systemOrderIdx = 1:this.modelOrder(1)
                            % Рассчитать обобщенный индекс
                            generalizedIndex = systemOrderIdx+this.modelOrder(1)*(memoryOrderIdx-1);
                            
                            % Рассчитать нелинейность
                            nonlinearity = nonlinearSignal .* abs(nonlinearSignal).^(systemOrderIdx-1);
                            
                            % Учесть память
                            modelInput(generalizedIndex,:) = [zeros(1, memoryOrderIdx-1) nonlinearity(1:end-memoryOrderIdx+1)];
                        end
                    end
                    
                otherwise
                    
                    error("Not implemented yet");
                    
            end
            
            % Инициализировать массив под линеаризованный сигнал
            linearizedSignal = zeros(size(desiredSignal));
            
            for iterIdx = 1:this.iterCount
                % Посчитать линеаризованный сигнал
                linearizedSignal(iterIdx) = this.modelCoeffs.' * modelInput(:, iterIdx);
                
                % Посчитать ошибку
                estimationError = desiredSignal(iterIdx) - linearizedSignal(iterIdx);
                
                % Обновить накопленную ошибку
                this.accumulatedSquaredError = this.accumulatedSquaredError + abs(estimationError)^2;
                
                % Сохранить MSE на текущей итерации
                this.mseArray(iterIdx) = this.accumulatedSquaredError / iterIdx;
                
                % Посчитать обновление весов
                switch this.updateMethod
                    
                    case 'LMS'
                        
                        % Посчитать update
                        update = this.mu * estimationError * conj(modelInput(:, iterIdx));
                        
                    case 'Normalized LMS'
                        
                        % Посчитать нормировку
                        normalization = modelInput(:, iterIdx)' * modelInput(:, iterIdx);
                        
                        % Посчитать update
                        update = this.mu * estimationError * conj(modelInput(:, iterIdx)) / (eps + normalization);
                        
                    otherwise
                        
                        error("Unsupported updateMethod");
                        
                end
                
                % Обновить веса
                this.modelCoeffs = this.leakageFactor * this.modelCoeffs + update;
            end
            
        end
        
        function figObj = plotLearningGraph(this)
            % Построить кривую обучения
            
            % Создать объект
            figObj = figure;
            
            % Построить кривую
            semilogy(this.mseArray);
            
            % Навести марафет
            grid on; title(["Learning graph"; string(this.updateMethod)+", model "+string(this.model)]);
            xlabel("Iteration index"); ylabel("MSE");
            
        end
        
        function figObj = plotSpectra(this, inputSignal, nonlinearSignal, linearizedSignal)
            % Построить спектры
            
            % Проверить валидность входных векторов
            assert(isrow(inputSignal), "Input signal must be row vector");
            assert(length(inputSignal) == this.iterCount, "Input signal must have size [1x"+string(this.iterCount)+"]");
            assert(isrow(nonlinearSignal), "Non-linear signal must be row vector");
            assert(length(nonlinearSignal) == this.iterCount, "Non-linear signal must have size [1x"+string(this.iterCount)+"]");
            assert(isrow(linearizedSignal), "Linearized signal must be row vector");
            assert(length(linearizedSignal) == this.iterCount, "Linearized signal must have size [1x"+string(this.iterCount)+"]");
            
            % Взять индексы для последних 10% сигналов
            firstIndex = round(0.9 * this.iterCount)+1;
            selectedIndices = firstIndex:this.iterCount;
            
            % Взять размер окна как 10% от длины вейвформы
            windowLen = round(length(selectedIndices)*0.1);
            
            % Взять размер overlap'а как половину размера окна
            windowOvlp = round(windowLen/2);
            
            % Получить нормализованный частоты
            normalizedFrequencies = (-windowLen/2:windowLen/2-1)*(1/windowLen);
            
            % Оценить спектр сигналов по Welch
            inputSignalSpectrum = pwelch(inputSignal(selectedIndices),  chebwin(windowLen),  windowOvlp, windowLen);
            nonlinearSignalSpectrum = pwelch(nonlinearSignal(selectedIndices),  chebwin(windowLen),  windowOvlp, windowLen);
            linearizedSignalSpectrum = pwelch(linearizedSignal(selectedIndices),  chebwin(windowLen),  windowOvlp, windowLen);
            
            % Создать объект
            figObj = figure;
            
            % Построить спектры
            plot(normalizedFrequencies, mag2db(abs(fftshift(inputSignalSpectrum)))); hold on;
            plot(normalizedFrequencies, mag2db(abs(fftshift(nonlinearSignalSpectrum)))); hold on;
            plot(normalizedFrequencies, mag2db(abs(fftshift(linearizedSignalSpectrum)))); hold on;
            
            % Навести марафет
            legend(["Input";"Non-linear";"Linearized"])
            grid on; title(["Amplitude spectra of signals"; string(this.updateMethod)+", model "+string(this.model)]);
            xlabel("Frequency / Fs"); ylabel("Power, dB");
            
        end
        
    end
    
end
