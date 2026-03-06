CREATE DATABASE hospital_db;
USE hospital_db;

CREATE TABLE hospital_billing (
    patient_id VARCHAR(20),
    department_referral VARCHAR(100),
    doctor_name VARCHAR(100),
    appointment_fees INT,
    total_bill DECIMAL(12,2),
    doctor_id VARCHAR(20)
);



CREATE TABLE patient_details (
    visit_datetime DATETIME,
    patient_id VARCHAR(20),
    patient_gender VARCHAR(10),
    patient_age INT,
    patient_sat_score INT NULL,
    patient_first_initial CHAR(1),
    patient_last_name VARCHAR(100),
    patient_race VARCHAR(100),
    patient_admin_flag VARCHAR(5),
    patient_waittime INT,
    department_referral VARCHAR(100)
);




LOAD DATA INFILE 
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Hospital ER.csv'
INTO TABLE patient_details
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@date, patient_id, patient_gender, patient_age, @sat_score,
 patient_first_initial, patient_last_name, patient_race,
 patient_admin_flag, patient_waittime, department_referral)
SET 
visit_datetime = STR_TO_DATE(@date, '%d-%m-%Y %H:%i'),
patient_sat_score = NULLIF(@sat_score, '');



ALTER TABLE patient_details 
MODIFY patient_gender VARCHAR(30);


Select count(*) from patient_details;
select count(*) from hospital_billing;



Select * from patient_details;
select * from hospital_billing;



-- 15.	Identify the top 5 doctors who generated the most revenue but had the fewest patients. (SQL) --
WITH doctor_summary AS (
    SELECT
        doctor_id,
        doctor_name,
        SUM(total_bill) AS total_revenue,
        COUNT(DISTINCT patient_id) AS total_patients
    FROM hospital_billing 
    GROUP BY doctor_id, doctor_name
),

ranked_doctors AS (
    SELECT
        doctor_id,
        doctor_name,
        total_revenue,
        total_patients,
        RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
        RANK() OVER (ORDER BY total_patients ASC) AS patient_rank
    FROM doctor_summary
)

SELECT *
FROM ranked_doctors
WHERE revenue_rank <= 5
ORDER BY total_revenue DESC;








--  16.	Find the department where the average waiting time has decreased over three consecutive months. (SQL) --
WITH monthly_avg_wait AS (
    SELECT
        department_referral,
        DATE_FORMAT(visit_datetime, '%Y-%m-01') AS month_start,
        AVG(patient_waittime) AS avg_wait_time
    FROM patient_details
    GROUP BY department_referral, DATE_FORMAT(visit_datetime, '%Y-%m-01')
),

lagged_data AS (
    SELECT
        department_referral,
        month_start,
        avg_wait_time,
        LAG(avg_wait_time, 1) OVER (
            PARTITION BY department_referral
            ORDER BY month_start
        ) AS prev_month_1,
        LAG(avg_wait_time, 2) OVER (
            PARTITION BY department_referral
            ORDER BY month_start
        ) AS prev_month_2
    FROM monthly_avg_wait
)

SELECT DISTINCT department_referral
FROM lagged_data
WHERE avg_wait_time < prev_month_1
  AND prev_month_1 < prev_month_2;





-- 17.	Determine the ratio of male to female patients for each doctor and rank the doctors based on this ratio. (SQL) -- 
WITH doctor_gender_counts AS (
    SELECT
        hb.doctor_id,
        hb.doctor_name,
        COUNT(CASE WHEN pd.patient_gender = 'Male' THEN 1 END) AS male_count,
        COUNT(CASE WHEN pd.patient_gender = 'Female' THEN 1 END) AS female_count
    FROM hospital_billing hb
    JOIN patient_details pd
        ON hb.patient_id = pd.patient_id
    GROUP BY hb.doctor_id, hb.doctor_name
),

ratio_calculation AS (
    SELECT
        doctor_id,
        doctor_name,
        male_count,
        female_count,
        CASE 
            WHEN female_count = 0 THEN NULL
            ELSE CAST(male_count AS DECIMAL(10,2)) / female_count
        END AS male_female_ratio
    FROM doctor_gender_counts
)

SELECT *,
       RANK() OVER (ORDER BY male_female_ratio DESC) AS ratio_rank
FROM ratio_calculation
ORDER BY ratio_rank;


















-- 18.	Calculate the average satisfaction score of patients for each doctor based on their visits. (SQL) --
WITH doctor_satisfaction AS (
    SELECT
        hb.doctor_id,
        hb.doctor_name,
        AVG(pd.patient_sat_score) AS avg_satisfaction
    FROM hospital_billing hb
    JOIN patient_details pd
        ON hb.patient_id = pd.patient_id
    WHERE pd.patient_sat_score IS NOT NULL
    GROUP BY hb.doctor_id, hb.doctor_name
)

SELECT *
FROM doctor_satisfaction
ORDER BY avg_satisfaction DESC;











-- 19.	Find doctors who have treated patients from different races and calculate the diversity of their patient base. (SQL) --
WITH doctor_race_diversity AS (
    SELECT
        hb.doctor_id,
        hb.doctor_name,
        COUNT(DISTINCT pd.patient_race) AS distinct_race_count
    FROM hospital_billing hb
    JOIN patient_details pd
        ON hb.patient_id = pd.patient_id
    GROUP BY hb.doctor_id, hb.doctor_name
)

SELECT *,
       RANK() OVER (ORDER BY distinct_race_count DESC) AS diversity_rank
FROM doctor_race_diversity
WHERE distinct_race_count > 1
ORDER BY diversity_rank;


























-- 20.	Calculate the ratio of total bills generated by male patients to female patients for each department. (SQL) -- 
WITH department_revenue AS (
    SELECT
        hb.department_referral,
        SUM(CASE WHEN pd.patient_gender = 'Male' THEN hb.total_bill ELSE 0 END) AS male_revenue,
        SUM(CASE WHEN pd.patient_gender = 'Female' THEN hb.total_bill ELSE 0 END) AS female_revenue
    FROM hospital_billing hb
    JOIN patient_details pd
        ON hb.patient_id = pd.patient_id
    GROUP BY hb.department_referral
)

SELECT
    department_referral,
    male_revenue,
    female_revenue,
    CASE 
        WHEN female_revenue = 0 THEN NULL
        ELSE ROUND(male_revenue / female_revenue, 2)
    END AS male_to_female_bill_ratio
FROM department_revenue
ORDER BY male_to_female_bill_ratio DESC;




-- 21.	Update the patient satisfaction score for all patients who visited the "General Practice" department and 
-- had a waiting time of more than 30 minutes. Increase their satisfaction score by 2 points,
--  but ensure that the satisfaction score does not exceed 10. (SQL)

UPDATE patient_details
SET patient_sat_score = 
    CASE
        WHEN patient_sat_score IS NOT NULL THEN
            LEAST(patient_sat_score + 2, 10)
        ELSE NULL
    END
WHERE department_referral = 'General Practice'
  AND patient_waittime > 30;
  
SELECT *
FROM patient_details
WHERE department_referral = 'General Practice'
  AND patient_waittime > 30;
  
  




SELECT department_referral, COUNT(*)
FROM patient_details
WHERE patient_waittime > 30
GROUP BY department_referral;


SELECT COUNT(*)
FROM patient_details
WHERE department_referral = 'General Practice'
  AND patient_waittime > 30
  AND patient_sat_score IS NOT NULL;



