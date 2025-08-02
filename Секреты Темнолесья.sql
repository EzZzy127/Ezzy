
-- Часть 1. Исследовательский анализ данных
	-- Задача 1. Исследование доли платящих игроков
		-- 1.1. Доля платящих пользователей по всем данным:
			
			SELECT  COUNT(*) AS total_users,     ---Общее количество игроков, зарегистрированных в игре
					SUM(payer) AS paying_players,   ---Количество платящих игроков
					ROUND(SUM(payer)/ COUNT(*)::NUMERIC, 3) AS SHARE  ---доля платящих игроков от общего количества пользователей, зарегистрированных в игре
			FROM fantasy.users;
			
		-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
			SELECT  DISTINCT r.race,                  ---Раса персонажа
				    SUM(u.payer) AS paying_players,   ---Количество платящих игроков этой расы
				    COUNT(u.race_id) AS total_players,  ---Общее количество зарегистрированных игроков этой расы
					ROUND(AVG(u.payer),3) AS share ---доля платящих игроков среди всех зарегистрированных игроков этой расы
			FROM fantasy.users AS u
			JOIN fantasy.race AS r USING(race_id)
			GROUP BY r.race_id
			ORDER BY share DESC;
			
	-- Задача 2. Исследование внутриигровых покупок
		-- 2.1. Статистические показатели по полю amount:
			SELECT 	COUNT(amount) AS total_count,   ---Общее количество покупок
					SUM(amount) AS total_sum,   ---Суммарную стоимость всех покупок
					MIN(amount) AS min,   ---Минимальную стоимость покупки
					MAX(amount) AS max,   ---Максимальную стоимость покупки
					AVG(amount)::NUMERIC(5,2) AS avg,   ---среднее значение стоимости покупки
					PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY ROUND(amount::NUMERIC,2)) AS median,  ---Медиана стоимости покупки
					STDDEV(amount)::NUMERIC(10,3) AS standard_deviation   ---стандартное отклонение стоимости покупки
			FROM fantasy.events;
			
		-- 2.2: Аномальные нулевые покупки:
				SELECT  COUNT(amount) AS total_count,    ---Общее количество покупок
						COUNT(transaction_id) FILTER (WHERE amount = 0) AS zero_purchase,   ---количество покупкок с нулевой стоимостью
						ROUND(COUNT(transaction_id) FILTER (WHERE amount = 0)::NUMERIC/COUNT(amount::NUMERIC),4)*100 AS PERCENT   ---Долю от общего числа покупок
				FROM fantasy.events;
		
			
				SELECT  e.item_code,
						i.game_items,
						COUNT(e.item_code)              -- Предметы проданные по стоимости 0
				FROM fantasy.events AS e
				JOIN fantasy.items AS i USING(item_code)
				WHERE e.amount=0
				GROUP BY e.item_code, i.game_items;
				
				SELECT  DISTINCT id,
						COUNT(transaction_id) FILTER (WHERE amount = 0) AS count_items    ---сколько раз игроки получили предмет бесплатно
				FROM fantasy.events
				GROUP BY id
				ORDER BY count_items DESC;
				
				
		-- 2.3: Популярные эпические предметы:
			
				SELECT	e.item_code,
						i.game_items,    ---Название эпических предметов
						COUNT(*) AS count,   ---Общее количество внутриигровых продаж
						ROUND(COUNT(*)/(SELECT COUNT(*) FROM fantasy.events WHERE amount>0)::NUMERIC,4) AS share,   ---Относительное значение внутриигровых продаж 
						ROUND(COUNT(DISTINCT e.id)::NUMERIC/(SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount>0), 3) AS players_share   ---долю игроков, которые хотя бы раз покупали этот предмет, от общего числа внутриигровых покупателей
				FROM fantasy.events AS e                                                                                                          ---разделил количество купивших игроков на сумму всех покупателей
				JOIN fantasy.items AS i USING(item_code)
				WHERE amount>0
				GROUP BY e.item_code, i.item_code
				ORDER BY count DESC;
		
				
				SELECT COUNT(i.game_items) AS items_not            ---проверка: предметы, которые не купили         
				FROM fantasy.events AS e
				JOIN fantasy.items AS i USING(item_code)
				WHERE amount >0
				HAVING COUNT(transaction_id) = 0;
				
				
				
-- Часть 2. Решение ad hoc-задачbи
	-- Задача: Зависимость активности игроков от расы персонажа:
	WITH race AS(
			SELECT  u.race_id,
					r.race AS race,
					COUNT(u.id) AS total_players
			FROM fantasy.users AS u
			JOIN fantasy.race AS r USING(race_id)
			GROUP BY u.race_id, r.race
		),
		s_p_p AS (                           ---Игроки, которые совершили внутриигровые покупки
			SELECT  u.race_id,
					COUNT(DISTINCT e.id) AS share_players_payer 
			FROM fantasy.users AS u 
			JOIN fantasy.events AS e USING(id)
			WHERE payer=1
			GROUP BY u.race_id
		),
		share_players AS (
			SELECT 	ra.race_id,                         ---ID расы
					ra.race,                            ---Раса
					ra.total_players,					---Количество зарегистрированных игроков этой расы
					COUNT(DISTINCT e.id) AS players_payer,   ---Количество игроков, которые совершают внутриигровые покупки 
					ROUND(COUNT(DISTINCT e.id)::NUMERIC / ra.total_players,3) AS share_payer,  ---Доля от общего количества зарегистрированных игроков
					ROUND(s_p_p.share_players_payer::NUMERIC / COUNT(DISTINCT e.id), 3) AS share_player_payer ---Доля платящих игроков среди игроков, которые совершили внутриигровые покупки
			FROM race AS ra
			JOIN fantasy.users AS u USING(race_id)
			JOIN fantasy.events AS e USING(id)
			JOIN s_p_p USING(race_id)
			WHERE e.amount>0
			GROUP BY ra.race_id, ra.race, ra.total_players,s_p_p.share_players_payer
		),	
		avg AS (
			SELECT  u.race_id,
					ROUND(COUNT(e.transaction_id)::NUMERIC / COUNT(DISTINCT e.id),3) AS avg_purchases, ---cреднее количество покупок на одного игрока
					ROUND(SUM(e.amount)::NUMERIC / COUNT(e.transaction_id),3) AS avg_bill, ---Cредняя стоимость одной покупки на одного игрока
					ROUND(SUM(e.amount)::NUMERIC / COUNT(DISTINCT e.id),3) AS avg_cost_purchases_person --Cредняя суммарная стоимость всех покупок на одного игрока
			FROM fantasy.events AS e
			JOIN fantasy.users AS u USING(id)
			WHERE e.amount>0
			GROUP BY u.race_id
		)
		SELECT  sp.race_id,
				sp.race,
				sp.total_players,
				sp.players_payer,
				sp.share_payer,
				sp.share_player_payer,
				avg.avg_purchases,
				avg.avg_bill,
				avg.avg_cost_purchases_person
		FROM share_players AS sp
		JOIN avg USING(race_id);
		