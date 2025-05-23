# Проект общественного питания по городу Москва

### Цели и задачи проекта

Цель проекта: Провести исследовательский анализ рынка заведений общественного питания Москвы, чтобы помочь инвесторам определить оптимальный тип заведения, его местоположение и ценовую политику.

Задачи:

- Загрузить и изучить данные о заведениях общественного питания Москвы.

- Провести предобработку данных: обработка пропусков, дубликатов, преобразование типов данных.

- Исследовать распределение заведений по категориям и административным районам.

- Проанализировать соотношение сетевых и несетевых заведений.

- Изучить количество посадочных мест и рейтинги заведений.

- Исследовать зависимость среднего чека от района.

- Сформулировать рекомендации для инвесторов на основе анализа данных.

### Описание данных

*Датасет 1:* /datasets/rest_info.csv

name — название заведения.

address — адрес заведения.

district — административный район Москвы.

category — категория заведения (кафе, ресторан, бар и др.).

hours — информация о днях и часах работы.

rating — рейтинг заведения (от 0 до 5).

chain — является ли заведение сетевым (0 — нет, 1 — да).

seats — количество посадочных мест.

*Датасет 2:* /datasets/rest_price.csv

price — категория цен (например, "средние", "ниже среднего").

avg_bill — строка с информацией о среднем чеке или цене напитка.

middle_avg_bill — числовая оценка среднего чека (если указан диапазон, берется медиана).

middle_coffee_cup — числовая оценка цены чашки капучино.

### Содержимое проекта
  
1. Загрузка и первичный анализ данных
- Изучение структуры данных.
- Проверка на пропуски и дубликаты.
- Объединение датасетов.

2. Предобработка данных
- Обработка пропусков.
- Проверка и удаление дубликатов.
- Создание новых признаков (например, is_24_7).
    
3. Исследовательский анализ данных
- Распределение заведений по категориям.
- Анализ по административным районам.
- Соотношение сетевых и несетевых заведений.
- Исследование количества посадочных мест.
- Анализ рейтингов заведений.
- Корреляционный анализ.
- Топ-15 популярных сетей.
- Влияние района на средний чек.

4. Выводы и рекомендации
- Обобщение результатов.
- Рекомендации по типу заведения, локации и ценовой политике.    
