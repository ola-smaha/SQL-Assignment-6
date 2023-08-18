-- Exercise 1
-- Applying SELF JOIN
WITH CTE_RENTAL_DURATION AS
(
	SELECT 
		rental_id,
		EXTRACT(DAY FROM  (return_date - rental_date)) * 24 + EXTRACT(HOUR FROM (return_date - rental_date)) AS duration_hours
	FROM public.rental
),

CTE_TOTAL_REVENUE AS
(
	SELECT 
		rental_id,
		SUM(amount) AS total_revenue
	FROM public.payment
	GROUP BY 
		rental_id
),

CTE_TOP3_CATEGORIES AS
(	
	SELECT 
		se_rental.customer_id,
		se_category.name,
		COUNT(se_rental.rental_id) AS total_rentals
	FROM public.rental AS se_rental
	INNER JOIN public.inventory AS se_inventory
	ON se_inventory.inventory_id = se_rental.inventory_id
	INNER JOIN public.film AS se_film
	ON se_film.film_id = se_inventory.film_id
	INNER JOIN public.film_category AS se_film_category
	ON se_film_category.film_id = se_film.film_id
	INNER JOIN public.category AS se_category
	ON se_category.category_id = se_film_category.category_id
	GROUP BY
		se_rental.customer_id,
		se_category.name
	ORDER BY customer_id, COUNT(se_rental.rental_id) DESC
),

CTE_TOP3_CATEGORIES_PER_CUSTOMER AS
(
	SELECT DISTINCT ON (cte1.customer_id) -- DISTINCT ON returns a single row for each customer_id, the row returned is specified with WHERE clause
		cte1.customer_id,
		cte1.name AS Cat1,
		cte2.name AS Cat2,
		cte3.name AS Cat3
	FROM CTE_TOP3_CATEGORIES AS cte1
	INNER JOIN CTE_TOP3_CATEGORIES AS cte2
		ON cte1.customer_id = cte2.customer_id
	INNER JOIN CTE_TOP3_CATEGORIES AS cte3
		ON cte3.customer_id = cte2.customer_id
	WHERE
		cte1.total_rentals >= cte2.total_rentals
		AND cte1.name <> cte2.name
		AND cte2.total_rentals >= cte3.total_rentals
		AND cte2.name <> cte3.name
		AND cte3.name <> cte1.name
)
SELECT
	se_rental.customer_id,
	ROUND(AVG(CTE_RENTAL_DURATION.duration_hours),2) AS average_duration_hours,
	SUM(CTE_TOTAL_REVENUE.total_revenue) AS total_revenue,
	cte4.Cat1,
	cte4.Cat2,
	cte4.Cat3
FROM public.rental se_rental
INNER JOIN CTE_RENTAL_DURATION
ON CTE_RENTAL_DURATION.rental_id = se_rental.rental_id
INNER JOIN CTE_TOTAL_REVENUE
ON CTE_TOTAL_REVENUE.rental_id = se_rental.rental_id
INNER JOIN CTE_TOP3_CATEGORIES_PER_CUSTOMER AS cte4
	ON cte4.customer_id = se_rental.customer_id
GROUP BY
	se_rental.customer_id,
	cte4.Cat1,
	cte4.Cat2,
	cte4.Cat3


-- Second method: using row_number()
WITH CTE_RENTAL_DURATION AS
(
	SELECT 
		rental_id,
		EXTRACT(DAY FROM  (return_date - rental_date)) * 24 + EXTRACT(HOUR FROM (return_date - rental_date)) AS duration_hours
	FROM public.rental
),

CTE_TOTAL_REVENUE AS
(
	SELECT 
		rental_id,
		SUM(amount) AS total_revenue
	FROM public.payment
	GROUP BY 
		rental_id
),
CTE_TOP3_CATEGORIES AS
(
	SELECT 
		se_rental.customer_id,
		se_category.name,
		COUNT(se_rental.rental_id) AS total_rentals
	FROM public.rental AS se_rental
	INNER JOIN public.inventory AS se_inventory
	ON se_inventory.inventory_id = se_rental.inventory_id
	INNER JOIN public.film AS se_film
	ON se_film.film_id = se_inventory.film_id
	INNER JOIN public.film_category AS se_film_category
	ON se_film_category.film_id = se_film.film_id
	INNER JOIN public.category AS se_category
	ON se_category.category_id = se_film_category.category_id
	GROUP BY
		se_rental.customer_id,
		se_category.name
	ORDER BY customer_id, COUNT(se_rental.rental_id) DESC
),
CTE_TOP3_BY_CUSTOMER AS
(
SELECT * FROM
	(SELECT
		customer_id,
		name,
		total_rentals,
		ROW_NUMBER() OVER (PARTITION by customer_id ORDER BY total_rentals DESC) 
FROM CTE_TOP3_CATEGORIES) AS partioned
WHERE row_number IN (1,2,3)
)
SELECT
	se_rental.customer_id,
	cte4.name,
	ROUND(AVG(CTE_RENTAL_DURATION.duration_hours),2) AS average_duration_hours,
	SUM(CTE_TOTAL_REVENUE.total_revenue) AS total_revenue
FROM public.rental se_rental
INNER JOIN CTE_RENTAL_DURATION
ON CTE_RENTAL_DURATION.rental_id = se_rental.rental_id
INNER JOIN CTE_TOTAL_REVENUE
ON CTE_TOTAL_REVENUE.rental_id = se_rental.rental_id
INNER JOIN CTE_TOP3_BY_CUSTOMER AS cte4
ON cte4.customer_id = se_rental.customer_id
GROUP BY
	se_rental.customer_id,
	cte4.name
ORDER BY se_rental.customer_id


-- Exercise 2
-- Determine whether the total rentals for each film is above or below the average,
--you can first compute the average count of rentals across all films.
--Then, you can compare each film's rental count to this average.

WITH CTE_RENTAL_COUNT AS
(
SELECT
	i.film_id,
	COUNT(rental_id) AS rental_count
FROM rental r
INNER JOIN inventory i
	ON r.inventory_id = i.inventory_id
GROUP BY i.film_id
),

CTE_AVG_RENTALS AS
(
SELECT ROUND(AVG(rental_count),2) AS avg_count
FROM CTE_RENTAL_COUNT
)
SELECT
	film.film_id,
	CTE_RENTAL_COUNT.rental_count,
		CASE
			WHEN CTE_RENTAL_COUNT.rental_count >= CTE_AVG_RENTALS.avg_count THEN 'Above average'
			WHEN CTE_RENTAL_COUNT.rental_count < CTE_AVG_RENTALS.avg_count THEN 'Below average'
		END AS rental_status
FROM film
INNER JOIN CTE_RENTAL_COUNT 
	ON CTE_RENTAL_COUNT.film_id = film.film_id
CROSS JOIN CTE_AVG_RENTALS
ORDER BY film.film_id
