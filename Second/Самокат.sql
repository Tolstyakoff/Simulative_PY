-- создаем таблицы для импорта csv
CREATE TABLE sam_products (
	product_id	int,
	level1	varchar,
	level2	varchar,
	name varchar
);

CREATE TABLE sam_orders (
	order_id		int,
	accepted_at		timestamp,
	product_id		int,
	quantity		NUMERIC,
	regular_price 	NUMERIC,
	price			NUMERIC,
	cost_price 		NUMERIC
);

-- оценить количество запсией в таблицах
SELECT 'orders' AS "table", count(*) AS records 
FROM sam_orders
UNION ALL 
SELECT 'products' AS "table", count(*) AS records 
FROM sam_products

 
-- проверяем является ли id_products ключом
SELECT 
	count(*) AS records,
	count(DISTINCT p.product_id ) AS cnt_unuque_id,
	count (DISTINCT p.name ) AS cnt_products 
FROM sam_products p


-- количество подкатегорий в категриях (вложенность)
SELECT 
	sp.level1,
	count( DISTINCT sp.level2 ) AS cnt_level2
FROM sam_products sp 
GROUP BY sp.level1
ORDER BY cnt_level2 DESC


-- проверяем продукт всегда в одной категории всегда представлен или может быть в разных
SELECT 
	count (DISTINCT p.name ) AS cnt_products, 
	count (DISTINCT p.name || p.level1 || p.level2   ) AS cnt_products
FROM sam_products p

-- ищем продукты у которых две и более подкатегории / категории
WITH product_cat AS (
	SELECT distinct
		sp.name, sp.level1 ||' \ '||sp.level2  AS level1_2
	FROM  sam_products sp
)
SELECT 
	name, count(level1_2) AS cnt_category
FROM product_cat
GROUP BY name
HAVING count(level1_2) >1
ORDER BY cnt_category desc

-- оцениваем бегло юезымянные товары
SELECT count(*)
FROM sam_products sp 
WHERE sp.name = '#VALUE!'

-- в каких категориях сколько товаров (с названиями)
SELECT 
  name, level1, level2,
  COUNT(name) AS cnt_product_id
FROM sam_products 
WHERE name != '#VALUE!'
GROUP BY name, level1, level2
ORDER BY name

-- паралельные категории (товар с одним и тем же названием встречается в разных категориях)
WITH product_cat AS (
	SELECT distinct
		sp.name, sp.level1 ||' \ '||sp.level2  AS level1_2
	FROM  sam_products sp
	WHERE sp.name != '#VALUE!'
),
duble_product AS (
	SELECT 
		name, count(level1_2) AS cnt_category
	FROM product_cat
	GROUP BY name
	HAVING count(level1_2) >1
	ORDER BY cnt_category DESC
)
SELECT distinct
	sp.name, sp.level1, sp.level2
FROM sam_products sp 
WHERE sp.name IN (SELECT name FROM duble_product)
ORDER BY sp.name

-- количество id у товаров по разным категориям
SELECT 
	sp.name, sp.level1, sp.level2,
	count(sp.name) AS cnt_product_id
FROM sam_products sp 
WHERE sp.name != '#VALUE!'
GROUP BY sp.name, sp.level1, sp.level2
ORDER BY sp.name


-- бардак в категориях (LIMIT)
SELECT level1, count(name) AS cnt_noname
FROM sam_products
WHERE name = '#VALUE!'
GROUP BY level1
ORDER BY cnt_noname DESC
LIMIT 3

-- бардак в категориях (РАНЖИРОВАНИЕ)
WITH ranked_ctategory AS (
	SELECT 
		level1, count(name) AS cnt_noname,
		DENSE_RANK() OVER (ORDER BY count(name) desc) AS rnk_cat
	FROM sam_products
	WHERE name = '#VALUE!'
	GROUP BY level1
)
SELECT  level1, cnt_noname
FROM ranked_ctategory
WHERE rnk_cat <= 3
ORDER BY cnt_noname DESC 

-- уникальность в заказах
SELECT so.order_id, count(product_id)
FROM sam_orders so 
GROUP BY order_id
ORDER BY count(product_id) DESC
LIMIT 30

-- проверка на примере одного id
SELECT 
	so.product_id,
	sp.level1 ,
	sp.level2 ,
	sp.name AS product,
	round (so.quantity *so.price, 2) AS amount 
FROM sam_orders so 
LEFT JOIN sam_products sp ON so.product_id  =   sp.product_id 
WHERE order_id =1517600286
ORDER BY sp.level1, sp.level2, amount


/************* КЕЙС**********************/
-- задача 1
SELECT 
	coalesce (p.level1,'!!! Категория отсутствует') AS category,
	sum(o.quantity) AS total_sale,
	count (DISTINCT o.order_id) AS cnt_orders
FROM sam_orders o LEFT JOIN sam_products p ON o.product_id =p.product_id 
GROUP BY p.level1
ORDER BY total_sale  DESC

-- задача 2
SELECT 
	p.level1,
	p.level2,
	sum(o.quantity) AS total_sale 
FROM sam_orders o JOIN sam_products p ON o.product_id =p.product_id 
GROUP BY p.level1, p.level2
ORDER BY p.level1,  total_sale DESC

-- задача 2 *
WITH marked_category AS (
	SELECT 
		p.level1,
		sum(o.quantity) AS total_sale
	FROM sam_orders o JOIN sam_products p ON o.product_id =p.product_id 
	GROUP BY p.level1
)
SELECT 
	p.level1,
	p.level2,
	sum(o.quantity) AS total_sale 
FROM sam_orders o JOIN sam_products p ON o.product_id =p.product_id 
JOIN marked_category mc ON mc.level1 = p.level1
GROUP BY p.level1, p.level2, mc.total_sale 
ORDER BY mc.total_sale DESC,  total_sale DESC


-- задача 3
SELECT round(sum(price * quantity) / count(DISTINCT order_id),2) avg_chek
FROM sam_orders
WHERE accepted_at::date = '2022-01-13'

SELECT 915.64 AS avg_chek


-- задача 4
SELECT 
	sum(CASE WHEN o.price = o.regular_price  THEN o.quantity END) AS normal,
	sum(CASE WHEN o.price != o.regular_price THEN o.quantity END) AS promo	
FROM sam_orders o 
JOIN sam_products p ON o.product_id =p.product_id 
WHERE p.level1 = 'Сыры'

SELECT 79 AS normal, 35 AS promo

-- задача 4*
SELECT 
	p.level1 AS category,
	round(COALESCE (sum(CASE WHEN o.price = o.regular_price  THEN o.quantity END)*100.0 / sum(o.quantity),0),1) AS normal,
	round(COALESCE (sum(CASE WHEN o.price != o.regular_price THEN o.quantity END)*100.0 / sum(o.quantity),0),1) AS promo	
FROM sam_orders o 
JOIN sam_products p ON o.product_id =p.product_id 
GROUP BY p.level1
ORDER BY promo desc

-- задача 5
SELECT 
	level1 AS category,
	sum((price-cost_price)*quantity) AS margin_abs,
	round(sum((price-cost_price)*quantity)*100.0 / sum(price*quantity),2)  AS margin_pct
FROM sam_orders o 
JOIN sam_products p ON o.product_id =p.product_id
GROUP BY level1
ORDER BY margin_abs desc 


-- ABC
WITH sales AS (
	SELECT 
		level2,
		sum(quantity) AS sum_quantity,
		sum(price*quantity) AS amount
	FROM sam_orders o JOIN sam_products p ON o.product_id =p.product_id
	GROUP BY level2
	ORDER BY sum_quantity desc
),
abs_quant AS (
	SELECT 
		level2 AS sub_category,
		CASE
			WHEN sum(sum_quantity) over(ORDER BY sum_quantity desc)/ sum(sum_quantity) over() <0.85 
			THEN 'A'
			WHEN sum(sum_quantity) over(ORDER BY sum_quantity desc)/ sum(sum_quantity) over() <0.95 
			THEN 'B'
			ELSE 'C'
		END AS ABC_quantity
	FROM sales
	ORDER BY  ABC_quantity
),
abs_sum AS (
	SELECT 
		level2 AS sub_category,
		CASE
			WHEN sum(amount) over(ORDER BY amount desc)/ sum(amount) over() <0.85 
			THEN 'A'
			WHEN sum(amount) over(ORDER BY amount desc)/ sum(amount) over() <0.95 
			THEN 'B'
			ELSE 'C'
		END AS ABC_summa
	FROM sales
	ORDER BY  ABC_summa
)
SELECT 
  abs_quant.sub_category,
  ABC_quantity, 
  ABC_summa
FROM abs_quant JOIN abs_sum ON abs_quant.sub_category = abs_sum.sub_category
ORDER BY ABC_quantity,  ABC_summa
