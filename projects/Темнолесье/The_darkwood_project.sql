/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT
    COUNT(u.id) AS total_players,
    COUNT(CASE WHEN u.payer = 1 THEN u.id END) AS paying_players,
    ROUND(CAST(COUNT(CASE WHEN u.payer = 1 THEN u.id END) AS numeric) / COUNT(u.id), 2) AS percentag_Of_paying
FROM
    fantasy.users AS u;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT
    r.race AS раса_персонажа,
    COUNT(CASE WHEN u.payer = 1 THEN u.id END) AS количество_платящих_игроков,
    COUNT(u.id) AS общее_количество_игроков,
    ROUND(CAST(COUNT(CASE WHEN u.payer = 1 THEN u.id END) AS numeric) / COUNT(u.id), 2) AS доля_платящих_игроков
FROM
    fantasy.users AS u
JOIN
    fantasy.race AS r ON u.race_id = r.race_id
GROUP BY
    r.race;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT
  COUNT(*) AS total_purchases,
  SUM(amount) AS total_amount,
  MIN(amount) AS min_amount,
  MAX(amount) AS max_amount,
  AVG(amount) AS avg_amount,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount,  -- Median calculation (PostgreSQL specific)
  STDDEV(amount) AS stddev_amount
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:
SELECT
  COUNT(*) AS zero_cost_purchases,
  ROUND(CAST(COUNT(*) AS NUMERIC) * 100 / (SELECT COUNT(*) FROM fantasy.events),2) AS zero_cost_percentage
FROM fantasy.events
WHERE amount = 0;


-- **2.3: Сравнительный анализ активности платящих и неплатящих игроков: **КОРРЕКТИРОВКА**
WITH PlayerPurchaseSummary AS (
    SELECT
        CASE 
            WHEN u.payer = 1 THEN 'Платящий' 
            ELSE 'Неплатящий' 
        END AS payer,
        u.id,
        COALESCE(COUNT(e.transaction_id), 0) AS num_purchases,
        COALESCE(SUM(e.amount), 0) AS total_spent
    FROM fantasy.users u
    LEFT JOIN (SELECT * FROM fantasy.events WHERE amount > 0) e ON u.id = e.id
    GROUP BY u.id, u.payer
)
SELECT
  payer,
  COUNT(*) AS total_players,
  ROUND(AVG(num_purchases::numeric), 2) AS avg_purchases_per_player,
  ROUND(AVG(total_spent::numeric), 2) AS avg_spent_per_player
FROM PlayerPurchaseSummary
GROUP BY payer;


-- **2.4: Популярные эпические предметы:** **КОРРЕКТИРОВКА**
WITH ItemSales AS (
    SELECT
        i.game_items AS item_name,
        COUNT(e.transaction_id) AS total_sales,
        COUNT(DISTINCT e.id) AS unique_buyers
    FROM
        fantasy.items AS i
    JOIN
        fantasy.events AS e ON i.item_code = e.item_code
   WHERE e.amount > 0
    GROUP BY
        i.game_items
),
TotalSales AS (
    SELECT SUM(total_sales) AS total FROM ItemSales
),
TotalUniqueBuyers AS (
    SELECT COUNT(DISTINCT id) AS total_unique_buyers
    FROM fantasy.events
    WHERE amount > 0
)
SELECT
    isales.item_name,
    isales.total_sales AS общее_количество_продаж,
    ROUND(CAST(isales.total_sales AS NUMERIC) / ts.total, 2)  AS доля_от_всех_продаж,
    isales.unique_buyers AS количество_покупавших_игроков,
    ROUND(CAST(isales.unique_buyers AS NUMERIC) / tub.total_unique_buyers, 2) AS доля_игроков
FROM
    ItemSales AS isales
    CROSS JOIN TotalSales AS ts
    CROSS JOIN TotalUniqueBuyers AS tub
ORDER BY
   isales.unique_buyers DESC;

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа: **КОРРЕКТИРОВКА**
WITH gamers_stat AS (
  -- Считаем статистику по игрокам
    SELECT
        r.race_id,
        r.race AS раса,
        COUNT(u.id) AS общее_количество_игроков,
        COUNT(CASE WHEN u.payer = 1 THEN u.id END) AS общее_количество_платящих_игроков
    FROM fantasy.users u
    JOIN fantasy.race r ON u.race_id = r.race_id
    GROUP BY r.race_id, r.race
),
buyers_stat AS (
  -- Считаем статистику по покупателям с фильтрацией нулевых покупок
    SELECT
        r.race_id,
        COUNT(DISTINCT e.id) AS общее_количество_покупателей,
        COUNT(CASE WHEN u.payer = 1 THEN e.id END) AS общее_количество_платящих_покупателей
    FROM fantasy.events e
    JOIN fantasy.users u ON e.id = u.id
    JOIN fantasy.race r ON u.race_id = r.race_id
    WHERE e.amount > 0
    GROUP BY r.race_id
),
orders_stat AS (

  -- Считаем статистику по покупкам с фильтрацией нулевых покупок
    SELECT
        r.race_id,
        COUNT(e.transaction_id) AS общее_количество_заказов,
        SUM(e.amount) AS общая_сумма_покупок
    FROM fantasy.events e
    JOIN fantasy.users u ON e.id = u.id
    JOIN fantasy.race r ON u.race_id = r.race_id
    WHERE e.amount > 0
    GROUP BY r.race_id
)
SELECT
    gs.раса,
    gs.общее_количество_игроков,
    COALESCE(bs.общее_количество_покупателей, 0) AS общее_количество_покупателей,
    COALESCE(bs.общее_количество_платящих_покупателей, 0) AS общее_количество_платящих_покупателей,
    CASE 
        WHEN gs.общее_количество_игроков = 0 THEN 0
        ELSE ROUND((COALESCE(bs.общее_количество_покупателей, 0)::numeric / gs.общее_количество_игроков), 2) 
    END AS доля_покупателей,    
    CASE 
        WHEN COALESCE(bs.общее_количество_покупателей, 0) = 0 THEN 0
        ELSE ROUND((COALESCE(bs.общее_количество_платящих_покупателей,0)::numeric / COALESCE(bs.общее_количество_покупателей,0)), 2) 
    END AS доля_платящих_покупателей,    
    CASE 
        WHEN COALESCE(bs.общее_количество_покупателей, 0) = 0 THEN 0
        ELSE ROUND((os.общее_количество_заказов::numeric / bs.общее_количество_покупателей), 2)
    END AS заказов_на_покупателя,
    CASE
        WHEN COALESCE(bs.общее_количество_покупателей, 0) = 0 THEN 0
        ELSE ROUND((os.общая_сумма_покупок::numeric / bs.общее_количество_покупателей), 2)
    END AS общая_сумма_покупок_на_покупателя,
   CASE
        WHEN os.общее_количество_заказов = 0 THEN 0
        ELSE ROUND((os.общая_сумма_покупок::numeric / os.общее_количество_заказов), 2)
    END AS средняя_сумма_заказа
FROM gamers_stat gs
LEFT JOIN buyers_stat bs USING(race_id)
LEFT JOIN orders_stat os USING(race_id)
ORDER BY общее_количество_игроков DESC;
