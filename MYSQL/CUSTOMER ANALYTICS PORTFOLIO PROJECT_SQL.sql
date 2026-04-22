-- =====================================================
-- CUSTOMER ANALYTICS PORTFOLIO PROJECT (MYSQL)
-- =====================================================

USE churn_db;

-- =====================================================
-- 1. DATA EXPLORATION
-- =====================================================

SELECT COUNT(*) AS total_customers FROM customers;
SELECT COUNT(*) AS total_transactions FROM transactions;
SELECT COUNT(*) AS total_subscriptions FROM subscriptions;
SELECT COUNT(*) AS total_activity FROM user_activity;

-- =====================================================
-- 2. REVENUE ANALYSIS
-- =====================================================

-- Total Revenue
SELECT SUM(amount) AS total_revenue FROM transactions;

-- Average Revenue per Customer (ARPU)
SELECT 
    SUM(amount) / COUNT(DISTINCT customer_id) AS ARPU
FROM transactions;

-- Monthly Revenue Trend
SELECT 
    DATE_FORMAT(transaction_date, '%Y-%m') AS month,
    SUM(amount) AS revenue
FROM transactions
GROUP BY month
ORDER BY month;

-- =====================================================
-- 3. CUSTOMER ACTIVITY ANALYSIS
-- =====================================================

-- Active Days per Customer
SELECT 
    customer_id,
    COUNT(DISTINCT event_date) AS active_days
FROM user_activity
GROUP BY customer_id;

-- Activity Breakdown
SELECT 
    event_type,
    COUNT(*) AS total_events
FROM user_activity
GROUP BY event_type;

-- =====================================================
-- 4. CUSTOMER LIFETIME VALUE (LTV)
-- =====================================================

SELECT 
    customer_id,
    SUM(amount) AS customer_revenue
FROM transactions
GROUP BY customer_id;

-- Average LTV
SELECT 
    AVG(customer_revenue) AS avg_ltv
FROM (
    SELECT customer_id, SUM(amount) AS customer_revenue
    FROM transactions
    GROUP BY customer_id
) t;

-- =====================================================
-- 5. CUSTOMER SEGMENTATION
-- =====================================================

SELECT 
    customer_id,
    SUM(amount) AS total_revenue,
    CASE
        WHEN SUM(amount) > 150 THEN 'High Value'
        WHEN SUM(amount) > 50 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS customer_segment
FROM transactions
GROUP BY customer_id;

-- =====================================================
-- 6. CHURN ANALYSIS
-- =====================================================

-- Financial Churn (No payment in last 90 days)
WITH financial_churn AS (
    SELECT customer_id
    FROM transactions
    GROUP BY customer_id
    HAVING MAX(transaction_date) < CURRENT_DATE - INTERVAL 90 DAY
),

-- Engagement Churn (No login in last 90 days)
engagement_churn AS (
    SELECT customer_id
    FROM user_activity
    WHERE event_type = 'Login'
    GROUP BY customer_id
    HAVING MAX(event_date) < CURRENT_DATE - INTERVAL 90 DAY
),

-- Silent Churn (Paying but inactive)
silent_churn AS (
    SELECT t.customer_id
    FROM transactions t
    LEFT JOIN user_activity ua ON t.customer_id = ua.customer_id
    GROUP BY t.customer_id
    HAVING 
        MAX(t.transaction_date) >= CURRENT_DATE - INTERVAL 90 DAY
        AND MAX(ua.event_date) < CURRENT_DATE - INTERVAL 90 DAY
)

-- Final Churn Classification
SELECT 
    c.customer_id,
    c.name,
    CASE
        WHEN fc.customer_id IS NOT NULL THEN 'Financial Churn'
        WHEN ec.customer_id IS NOT NULL THEN 'Engagement Churn'
        WHEN sc.customer_id IS NOT NULL THEN 'Silent Churn'
        ELSE 'Active'
    END AS churn_type
FROM customers c
LEFT JOIN financial_churn fc ON c.customer_id = fc.customer_id
LEFT JOIN engagement_churn ec ON c.customer_id = ec.customer_id
LEFT JOIN silent_churn sc ON c.customer_id = sc.customer_id;

-- =====================================================
-- 7. CHURN SUMMARY
-- =====================================================

SELECT churn_type, COUNT(*) AS customer_count
FROM (
    SELECT 
        c.customer_id,
        CASE
            WHEN fc.customer_id IS NOT NULL THEN 'Financial Churn'
            WHEN ec.customer_id IS NOT NULL THEN 'Engagement Churn'
            WHEN sc.customer_id IS NOT NULL THEN 'Silent Churn'
            ELSE 'Active'
        END AS churn_type
    FROM customers c
    LEFT JOIN (
        SELECT customer_id
        FROM transactions
        GROUP BY customer_id
        HAVING MAX(transaction_date) < CURRENT_DATE - INTERVAL 90 DAY
    ) fc ON c.customer_id = fc.customer_id
    LEFT JOIN (
        SELECT customer_id
        FROM user_activity
        WHERE event_type = 'Login'
        GROUP BY customer_id
        HAVING MAX(event_date) < CURRENT_DATE - INTERVAL 90 DAY
    ) ec ON c.customer_id = ec.customer_id
    LEFT JOIN (
        SELECT t.customer_id
        FROM transactions t
        LEFT JOIN user_activity ua ON t.customer_id = ua.customer_id
        GROUP BY t.customer_id
        HAVING 
            MAX(t.transaction_date) >= CURRENT_DATE - INTERVAL 90 DAY
            AND MAX(ua.event_date) < CURRENT_DATE - INTERVAL 90 DAY
    ) sc ON c.customer_id = sc.customer_id
) t
GROUP BY churn_type;

-- =====================================================
-- END OF SCRIPT
-- =====================================================