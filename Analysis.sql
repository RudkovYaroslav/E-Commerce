--1. Проверки данных:
--1.1 Наличие заказов с одинаковым идентификатором
		SELECT 
		    COUNT(*) AS total_rows,
		    COUNT(DISTINCT order_id) AS unique_orders
		FROM orders;
		
--1.2 Наличие пропусков в данных
		SELECT
		    COUNT(*) - COUNT(order_id) AS missing_orders,
		    COUNT(*) - COUNT(order_date) AS missing_dates,
		    COUNT(*) - COUNT(revenue) AS missing_revenue
		FROM orders;
		
--1.3 Наличие аномальных заказов
		SELECT
		    MIN(revenue) AS min_revenue,
		    MAX(revenue) AS max_revenue,
		    AVG(revenue) AS avg_revenue
		FROM orders;
		
--1.4 Медианные значения и перцентили
		SELECT
		    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue) AS median,
		    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY revenue) AS p90,
		    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY revenue) AS p99,
		    MAX(revenue) AS max
		FROM orders;

--2. Таблица для сверки всех метрик между отчетными периодами.
		WITH yearly_metrics AS (SELECT extract (year from order_date) as date_year,
				sum(revenue) as total_revenue,
				count(distinct order_id)::NUMERIC(10,2) as orders_count,
				round(avg(revenue), 2) as average_revenue,
				percentile_cont(0.5) within group (order by revenue) as median_revenue
			from orders
			where (order_date BETWEEN '2024-01-01' and '2024-08-31')
				or (order_date BETWEEN '2025-01-01' and '2025-08-31')
			group by extract(year from order_date))
						
		SELECT date_year,
				total_revenue,
				round(total_revenue / LAG(total_revenue) over (order by date_year) - 1, 2) as revenue_growth,
				orders_count,
				round(orders_count / LAG(orders_count) over (order by date_year) - 1, 2) as orders_growth,
				average_revenue,
				median_revenue
		from yearly_metrics 


--3. Проверка выручки по регионам за отчетные периоды
		SELECT date_year, date_month,
			   round(west_orders / LAG(west_orders) over (PARTITION BY date_year ORDER BY date_month) - 1, 2) as west_growth,
			   round(east_orders / LAG(east_orders) over (PARTITION BY date_year ORDER BY date_month) - 1, 2) as east_growth,
			   round(north_orders / LAG(north_orders) over (PARTITION BY date_year ORDER BY date_month) - 1, 2) as north_growth,
			   round(south_orders / LAG(south_orders) over (PARTITION BY date_year ORDER BY date_month) - 1, 2) as south_growth,
			   round(central_orders / LAG(central_orders) over (PARTITION BY date_year ORDER BY date_month) - 1, 2) as central_growth
		from  (select extract (year from order_date) as date_year,
					  extract (month from order_date) as date_month,
			   COUNT(distinct order_id) filter (where region = 'West')::NUMERIC(10,2) as west_orders,
			   COUNT(distinct order_id) filter (where region = 'East')::NUMERIC(10,2) as east_orders,
			   COUNT(distinct order_id) filter (where region = 'North')::NUMERIC(10,2) as north_orders,
			   COUNT(distinct order_id) filter (where region = 'South')::NUMERIC(10,2) as south_orders,
			   COUNT(distinct order_id) filter (where region = 'Central')::NUMERIC(10,2) as central_orders
		from orders
				where (order_date BETWEEN '2024-01-01' and '2024-08-31')
					or (order_date BETWEEN '2025-01-01' and '2025-08-31')
		group by extract (year from order_date), extract (month from order_date)
		)
		order by date_year, date_month

-- 4. Создание финальной таблицы с метриками
		SELECT extract (year from order_date) as date_year,
		extract (month from order_date) as date_month,
			sum(revenue) as total_revenue,
			count(distinct order_id)::NUMERIC(10,2) as orders_count,
			round(avg(revenue), 2) as average_revenue,
			percentile_cont(0.5) within group (order by revenue) as median_revenue
		from orders
		where (order_date BETWEEN '2024-01-01' and '2024-08-31')
			or (order_date BETWEEN '2025-01-01' and '2025-08-31')
		group by 1, 2
		order by 1, 2;

