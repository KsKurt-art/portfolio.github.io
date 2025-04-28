 * Цель проекта: анализ объявлений о продаже жилой недвижимости в Санкт-Петербурге и Ленинградской области, чтобы найти самые перспективные сегменты недвижимости.
 * 
*/

--  Время активности объявлений

WITH limits AS (
SELECT  
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
	PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
FROM real_estate.flats
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND (
            (ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) 
            OR ceiling_height IS NULL
        )
),
FilteredData AS (
    SELECT 
        a.id AS advertisement_id,
        a.days_exposition,
        a.last_price,
        f.total_area,
        f.rooms,
        f.ceiling_height,
        f.balcony,
        c.city,
        CASE 
            WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
            ELSE 'ЛенОбл'
        END AS region,
        CASE 
            WHEN a.days_exposition BETWEEN 1 AND 30 THEN '1 месяц'
            WHEN a.days_exposition BETWEEN 31 AND 90 THEN '1 квартал'
            WHEN a.days_exposition BETWEEN 91 AND 180 THEN '6 месяцев'
            ELSE 'более полугода'
        END AS activity_period
    FROM 
        real_estate.advertisement a
    JOIN 
        real_estate.flats f ON a.id = f.id
    JOIN 
        real_estate.city c ON f.city_id = c.city_id
    JOIN 
        real_estate.type t ON f.type_id = t.type_id 
    WHERE 
        a.days_exposition IS NOT NULL
        AND a.last_price > 0
        AND f.total_area > 0
        AND f.id IN (SELECT id FROM filtered_id)  -- Фильтрация выбросов
        AND t.type = 'город'  -- Фильтрация по типу населенного пункта (оставляем только города)
),
Analysis AS (
    SELECT 
        region,
        activity_period,
        COUNT(advertisement_id) AS total_ads,
        ROUND(AVG(last_price / total_area)::numeric, 2) AS avg_price_per_sqm,
        ROUND(AVG(total_area)::numeric, 2) AS avg_total_area,
        ROUND(AVG(rooms)) AS avg_rooms,
        ROUND(AVG(balcony)) AS avg_balcony
    FROM 
        FilteredData
    GROUP BY 
        region, activity_period
)
SELECT 
    region,
    activity_period,
    total_ads,
    avg_price_per_sqm,
    avg_total_area,
    avg_rooms,
    avg_balcony
FROM 
    Analysis
ORDER BY 
    region, activity_period;

-- Сезонность объявлений

WITH limits AS (
SELECT  
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
	PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
FROM real_estate.flats
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND (
            (ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) 
            OR ceiling_height IS NULL
        )
),
PreparedData AS (
    SELECT 
        a.id AS advertisement_id,
        a.first_day_exposition AS publication_date,
        (a.first_day_exposition + INTERVAL '1 day' * a.days_exposition) AS removal_date,
        TO_CHAR(a.first_day_exposition, 'Month') AS publication_month,  -- Используем TO_CHAR для названия месяца
        TO_CHAR((a.first_day_exposition + INTERVAL '1 day' * a.days_exposition), 'Month') AS removal_month,  -- Используем TO_CHAR для названия месяца
        f.total_area,
        a.last_price,
        a.days_exposition  -- Добавляем days_exposition в выборку
    FROM 
        real_estate.advertisement a
    JOIN 
        real_estate.flats f USING (id)
    JOIN 
        real_estate.city c ON f.city_id = c.city_id
    JOIN 
        real_estate.type t ON f.type_id = t.type_id 
    WHERE 
        AND a.last_price > 0
        AND f.total_area > 0
        AND f.id IN (SELECT id FROM filtered_id)  -- Фильтрация выбросов
        AND t.type = 'город'  -- Фильтрация по типу населенного пункта (оставляем только города)
),
MonthlyActivity AS (
    SELECT 
        publication_month AS month,
        COUNT(advertisement_id) AS published_ads,
        0 AS removed_ads,
        SUM(total_area) AS published_area,
        0 AS removed_area,
        SUM(last_price) AS published_price,
        0 AS removed_price
    FROM 
        PreparedData
    GROUP BY 
        publication_month
    UNION ALL
    SELECT 
        removal_month AS month,
        0 AS published_ads,
        COUNT(advertisement_id) AS removed_ads,
        0 AS published_area,
        SUM(total_area) AS removed_area,
        0 AS published_price,
        SUM(last_price) AS removed_price
    FROM 
        PreparedData
    WHERE 
        days_exposition IS NOT NULL  -- Фильтрация по дням экспозиции для удаленных объявлений
    GROUP BY 
        removal_month
),
SummedActivity AS (
    SELECT 
        month,
        SUM(published_ads) AS total_published,
        SUM(removed_ads) AS total_removed,
        SUM(published_area) AS total_published_area,
        SUM(removed_area) AS total_removed_area,
        SUM(published_price) AS total_published_price,
        SUM(removed_price) AS total_removed_price
    FROM 
        MonthlyActivity
    GROUP BY 
        month
),
RankedActivity AS (
    SELECT 
        month,
        total_published,
        total_removed,
        total_published_area,
        total_removed_area,
        total_published_price,
        total_removed_price,
        RANK() OVER (ORDER BY total_published DESC) AS rank_published,
        RANK() OVER (ORDER BY total_removed DESC) AS rank_removed
    FROM 
        SummedActivity
)
SELECT 
    month,
    total_published,
    total_removed,
    total_published_area,
    total_removed_area,
    total_published_price,
    total_removed_price,
    rank_published,
    rank_removed
FROM 
    RankedActivity
ORDER BY 
    month;

-- Задача 3. Анализ рынка недвижимости Ленобласти
WITH limits AS (
SELECT  
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
	PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
FROM real_estate.flats
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
LeningradOblastData AS (
    SELECT 
        a.id AS advertisement_id,
        a.days_exposition,
        a.last_price,
        f.total_area,
        f.rooms,
        f.balcony,
        c.city,
        CASE 
            WHEN a.days_exposition > 0 THEN 1  -- Объявление снято
            ELSE 0  -- Объявление активно
        END AS is_removed
    FROM 
        real_estate.advertisement a
    JOIN 
        real_estate.flats f ON a.id = f.id
    JOIN 
        real_estate.city c ON f.city_id = c.city_id
    WHERE 
        c.city != 'Санкт-Петербург' AND
        a.last_price > 0 AND
        f.total_area > 0 AND
        f.id IN (SELECT id FROM filtered_id)
),
CityStats AS (
    SELECT 
        city,
        COUNT(advertisement_id) AS total_ads,
        SUM(is_removed) AS removed_ads,
        ROUND(AVG(last_price / total_area)) AS avg_price_per_sqm,
        ROUND(AVG(total_area)) AS avg_total_area,
        ROUND(AVG(rooms)) AS avg_rooms,
        ROUND(AVG(balcony)) AS avg_balcony
    FROM 
        LeningradOblastData
    GROUP BY 
        city
),
FilteredCities AS (
    SELECT 
        city,
        total_ads,
        removed_ads,
        avg_price_per_sqm,
        avg_total_area,
        avg_rooms,
        avg_balcony
    FROM 
        CityStats
    WHERE 
        total_ads > 50
),
RankedCities AS (
    SELECT 
        city,
        total_ads,
        removed_ads,
        avg_price_per_sqm,
        avg_total_area,
        avg_rooms,
        avg_balcony,
        RANK() OVER (ORDER BY total_ads DESC) AS rank_by_ads,
        RANK() OVER (ORDER BY removed_ads DESC) AS rank_by_removed_ads
    FROM 
        FilteredCities
)

SELECT 
    city,
    total_ads,
    removed_ads,
    avg_price_per_sqm,
    avg_total_area,
    avg_rooms,
    avg_balcony,
    rank_by_ads,
    rank_by_removed_ads,
    ROUND((removed_ads * 1.0 / total_ads) * 100, 2) AS removal_rate_percent  
FROM 
    RankedCities
ORDER BY 
    rank_by_ads
LIMIT 15;
