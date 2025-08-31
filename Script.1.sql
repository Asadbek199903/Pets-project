SELECT *
FROM pet_owners

SELECT *
FROM pets

SELECT kind, COUNT(kind) AS kind_num, gender
FROM pet_owners AS p1
INNER JOIN pets AS p2
USING (owner_id)
GROUP BY kind, gender 

SELECT kind, COUNT(kind) AS kind_num, gender, ROUND(AVG(age), 2) AS avrege_age
FROM pet_owners AS p1
INNER JOIN pets AS p2
USING (owner_id)
GROUP BY gender, kind

SELECT kind, COUNT(kind) AS kind_num, gender, ROUND(AVG(age), 2) AS avrege_age, (SELECT AVG(age) FROM pets) AS avrage_age_of_all_kind
FROM pet_owners AS p1
INNER JOIN pets AS p2
USING (owner_id) 
GROUP BY kind, gender 

SELECT street_address, COUNT(kind) AS kind_num
FROM pet_owners AS p1
INNER JOIN pets AS p2
USING (owner_id)
GROUP BY street_address

SELECT city, COUNT(kind) AS kind_num
FROM pet_owners AS p1
INNER JOIN pets AS p2
USING (owner_id)
GROUP BY city

SELECT 
    kind, 
    COUNT(kind) AS kind_num, 
    CASE 
        WHEN age > 7 THEN 'Old' 
        WHEN age < 7 THEN 'Young' 
        ELSE 'Middle' 
    END AS age_level
FROM pet_owners AS p1
INNER JOIN pets AS p2
USING (owner_id)
GROUP BY kind, age_level
ORDER BY kind_num DESC



