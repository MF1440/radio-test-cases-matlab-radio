# Моделирование (Радио) #
Тестовое задание для выполнения в MATLAB или совместимых средах.

## Требования к выполнению ##
- Написание текстового отчета по алгоритму решения не требуется. Хороший код документирует сам себя - крайне рекомендуется использовать понятные названия переменных и комментарии, поясняющие основные шаги при решении (документ с требованиями и рекомендациями, приложенный к заданию, в точности соблюдать не требуется, но он может помочь для структуризации и улучшения качества кода);
- Ожидаемая форма предоставления результата - mearge request в исходный репозиторий; при отсутствии достаточного опыта работы с git - допускаются другие, удобные для исполнителя формы;

## Содержание репозитория ##
Для выполнения задания нами предоставляется исходный код в составе:
- LeasеtMeanSquare.m – файл, реализующий класс Beamformer
- simulationScenario.m – файл "сценария"

## Задание: ##

1. Сделайте fork репозитория

2. Перейдите на ветку "least-mean-square-algorithm"

2. Code review – предложите правки по логике и оформлению предоставленного вам кода (StyleGuide прилагается). Внимание только в указанных файлах

3. Реализуйте методы класса LeasеtMeanSquare.m. Необходимо для приведенной нельнейной системы найти коэффициенты адаптивной модели методом LMS 

4. На свое усмотрение выберите порядок модели, масщтаб входного воздейтсвия, скорость обучения и кол-во итераций LMS

5. Реализуйте скрипт для демострации работы программы с функционалом описанным в пункте 3 и 4

6. Сделайте МР