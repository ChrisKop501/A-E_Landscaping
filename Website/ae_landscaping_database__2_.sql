-- ============================================================
-- A&E Landscaping & Hauling - MySQL Database
-- Based on Proposed ERD, Reports, Queries, and Forms
-- ============================================================

CREATE DATABASE IF NOT EXISTS ae_landscaping;
USE ae_landscaping;

-- ============================================================
-- TABLE: Client
-- Supports: Customer Information Form, ERD
-- ============================================================
CREATE TABLE Client (
    Client_ID       INT AUTO_INCREMENT PRIMARY KEY,
    Client_Name     VARCHAR(100) NOT NULL,
    Client_Phone    VARCHAR(20),
    Client_Email    VARCHAR(100),
    Property_Address VARCHAR(255)
);

-- ============================================================
-- TABLE: Employee
-- Supports: Estimate Employees Query, Service Employees Query
-- ============================================================
CREATE TABLE Employee (
    Employee_ID     INT AUTO_INCREMENT PRIMARY KEY,
    Employee_Name   VARCHAR(100) NOT NULL,
    Employee_Role   VARCHAR(50),
    Employee_Phone  VARCHAR(20),
    Employee_Email  VARCHAR(100),
    Is_Available    TINYINT(1) DEFAULT 1  -- 1 = available, 0 = unavailable
);

-- ============================================================
-- TABLE: Estimate
-- Supports: Estimate Request Form, ERD
-- ============================================================
CREATE TABLE Estimate (
    Estimate_ID         INT AUTO_INCREMENT PRIMARY KEY,
    Client_ID           INT NOT NULL,
    Employee_ID         INT,
    Property_Address    VARCHAR(255),
    Service_Description TEXT,
    Estimated_Cost      DECIMAL(10, 2),
    Estimated_Labor_Hours DECIMAL(6, 2),
    Estimate_Date       DATE,
    FOREIGN KEY (Client_ID)   REFERENCES Client(Client_ID),
    FOREIGN KEY (Employee_ID) REFERENCES Employee(Employee_ID)
);

-- ============================================================
-- TABLE: Contract
-- Supports: Contract Entry Form, ERD
-- ============================================================
CREATE TABLE Contract (
    Contract_ID         INT AUTO_INCREMENT PRIMARY KEY,
    Estimate_ID         INT NOT NULL,
    Client_ID           INT NOT NULL,
    Contract_StartDate  DATE,
    Contract_EndDate    DATE,
    Pricing             DECIMAL(10, 2),
    Service_Scope       TEXT,
    Contract_Duration   VARCHAR(50),
    FOREIGN KEY (Estimate_ID) REFERENCES Estimate(Estimate_ID),
    FOREIGN KEY (Client_ID)   REFERENCES Client(Client_ID)
);

-- ============================================================
-- TABLE: Service
-- Supports: Service Employees Query, Revenue by Service Type Query, ERD
-- ============================================================
CREATE TABLE Service (
    Service_ID      INT AUTO_INCREMENT PRIMARY KEY,
    Client_ID       INT NOT NULL,
    Contract_ID     INT,
    Service_Type    VARCHAR(100),
    Service_Date    DATE,
    Property_Location VARCHAR(255),
    FOREIGN KEY (Client_ID)   REFERENCES Client(Client_ID),
    FOREIGN KEY (Contract_ID) REFERENCES Contract(Contract_ID)
);

-- ============================================================
-- TABLE: Service_Employee (Junction: Service <-> Employee)
-- Supports: Service Employees Query, Schedule and Workload Report
-- ============================================================
CREATE TABLE Service_Employee (
    Service_ID      INT NOT NULL,
    Employee_ID     INT NOT NULL,
    PRIMARY KEY (Service_ID, Employee_ID),
    FOREIGN KEY (Service_ID)  REFERENCES Service(Service_ID),
    FOREIGN KEY (Employee_ID) REFERENCES Employee(Employee_ID)
);

-- ============================================================
-- TABLE: Payment
-- Supports: Payment Entry and Invoice Review Form, Payments This Month Query, ERD
-- ============================================================
CREATE TABLE Payment (
    Payment_ID      INT AUTO_INCREMENT PRIMARY KEY,
    Contract_ID     INT NOT NULL,
    Invoice_ID      INT,                  -- links to Invoice table below
    Payment_Amount  DECIMAL(10, 2),
    Payment_Method  VARCHAR(50),
    Due_Date        DATE,
    Payment_Date    DATE,
    Payment_Status  VARCHAR(20) DEFAULT 'Pending',  -- Pending, Paid, Overdue
    FOREIGN KEY (Contract_ID) REFERENCES Contract(Contract_ID)
);

-- ============================================================
-- TABLE: Invoice
-- Supports: Outstanding Invoice (Aging) Report, Payment Entry Form
-- ============================================================
CREATE TABLE Invoice (
    Invoice_ID          INT AUTO_INCREMENT PRIMARY KEY,
    Contract_ID         INT NOT NULL,
    Client_ID           INT NOT NULL,
    Invoice_Date        DATE,
    Due_Date            DATE,
    Total_Amount        DECIMAL(10, 2),
    Amount_Paid         DECIMAL(10, 2) DEFAULT 0.00,
    Invoice_Status      VARCHAR(20) DEFAULT 'Unpaid',  -- Unpaid, Partial, Paid
    Days_Outstanding    INT GENERATED ALWAYS AS (DATEDIFF(CURDATE(), Due_Date)) VIRTUAL,
    FOREIGN KEY (Contract_ID) REFERENCES Contract(Contract_ID),
    FOREIGN KEY (Client_ID)   REFERENCES Client(Client_ID)
);

-- Add FK from Payment to Invoice now that Invoice exists
ALTER TABLE Payment
    ADD CONSTRAINT fk_payment_invoice
    FOREIGN KEY (Invoice_ID) REFERENCES Invoice(Invoice_ID);

-- ============================================================
-- TABLE: Client_Feedback
-- Supports: Customer Feedback Form, Find Client Feedback Query
-- ============================================================
CREATE TABLE Client_Feedback (
    Feedback_ID     INT AUTO_INCREMENT PRIMARY KEY,
    Client_ID       INT NOT NULL,
    Service_ID      INT,
    Rating          TINYINT CHECK (Rating BETWEEN 1 AND 5),
    Comments        TEXT,
    Suggestions     TEXT,
    Feedback_Date   DATE,
    FOREIGN KEY (Client_ID)  REFERENCES Client(Client_ID),
    FOREIGN KEY (Service_ID) REFERENCES Service(Service_ID)
);

-- ============================================================
-- TABLE: Referral
-- Supports: DFD 7.0 Refer Client — Process 7.1 Collect Customer
-- Information / 7.2 Prompt Estimate Schedule
-- Fields per data dictionary:
--   Referral_ID  — unique identifier for this referral instance
--   Referrer_ID  — Client_ID of the person sharing the link (Referrer)
--   Referee_ID   — Client_ID of the new user being referred (Referee)
--   Referee_Name — Name submitted by the new referral (required; only
--                  field the public form writes to the DB)
--   Referral_Date — date the referral was submitted
--   Status        — tracks the referral from invitation to verification
-- ============================================================
CREATE TABLE Referral (
    Referral_ID     INT AUTO_INCREMENT PRIMARY KEY,
    Referrer_ID     INT,                           -- existing client who referred
    Referee_ID      INT,                           -- assigned once new client is created
    Referee_Name    VARCHAR(100) NOT NULL,         -- only field added from public form
    Referral_Date   DATE NOT NULL,
    Status          ENUM('Pending','Contacted','Verified') DEFAULT 'Pending',
    FOREIGN KEY (Referrer_ID) REFERENCES Client(Client_ID),
    FOREIGN KEY (Referee_ID)  REFERENCES Client(Client_ID)
);

-- ============================================================
-- TABLE: Job_Costing
-- Supports: Job Costing Report
-- ============================================================
CREATE TABLE Job_Costing (
    Job_Cost_ID         INT AUTO_INCREMENT PRIMARY KEY,
    Service_ID          INT NOT NULL,
    Estimate_ID         INT,
    Actual_Labor_Hours  DECIMAL(6, 2),
    Actual_Labor_Cost   DECIMAL(10, 2),
    Actual_Materials    DECIMAL(10, 2),
    Total_Actual_Cost   DECIMAL(10, 2),
    Total_Estimated_Cost DECIMAL(10, 2),
    Variance            DECIMAL(10, 2) GENERATED ALWAYS AS (Total_Actual_Cost - Total_Estimated_Cost) VIRTUAL,
    FOREIGN KEY (Service_ID) REFERENCES Service(Service_ID),
    FOREIGN KEY (Estimate_ID) REFERENCES Estimate(Estimate_ID)
);


-- ============================================================
-- ROUTINE QUERIES
-- ============================================================

-- 1. Find Client Feedback
-- Retrieves comments, ratings, or survey responses by client
CREATE OR REPLACE VIEW vw_ClientFeedback AS
SELECT
    cf.Feedback_ID,
    c.Client_ID,
    c.Client_Name,
    s.Service_ID,
    s.Service_Type,
    cf.Rating,
    cf.Comments,
    cf.Suggestions,
    cf.Feedback_Date
FROM Client_Feedback cf
JOIN Client  c ON cf.Client_ID  = c.Client_ID
LEFT JOIN Service s ON cf.Service_ID = s.Service_ID
ORDER BY cf.Feedback_Date DESC;

-- 2. Estimate Employees
-- Shows employees assigned to produce an estimate
CREATE OR REPLACE VIEW vw_EstimateEmployees AS
SELECT
    e.Estimate_ID,
    e.Estimate_Date,
    c.Client_Name,
    e.Property_Address,
    e.Service_Description,
    e.Estimated_Cost,
    emp.Employee_ID,
    emp.Employee_Name,
    emp.Employee_Role
FROM Estimate e
JOIN Client   c   ON e.Client_ID   = c.Client_ID
LEFT JOIN Employee emp ON e.Employee_ID = emp.Employee_ID;

-- 3. Service Employees
-- Shows employees available to perform a service
CREATE OR REPLACE VIEW vw_ServiceEmployees AS
SELECT
    emp.Employee_ID,
    emp.Employee_Name,
    emp.Employee_Role,
    emp.Employee_Phone,
    emp.Is_Available
FROM Employee emp
WHERE emp.Is_Available = 1
ORDER BY emp.Employee_Name;

-- 4. Payments This Month
-- Shows payments received in the current month
CREATE OR REPLACE VIEW vw_PaymentsThisMonth AS
SELECT
    p.Payment_ID,
    c.Client_Name,
    con.Contract_ID,
    p.Payment_Amount,
    p.Payment_Method,
    p.Payment_Date,
    p.Payment_Status,
    i.Invoice_ID,
    i.Total_Amount AS Invoice_Total
FROM Payment p
JOIN Contract con ON p.Contract_ID = con.Contract_ID
JOIN Client   c   ON con.Client_ID  = c.Client_ID
LEFT JOIN Invoice i ON p.Invoice_ID = i.Invoice_ID
WHERE MONTH(p.Payment_Date) = MONTH(CURDATE())
  AND YEAR(p.Payment_Date)  = YEAR(CURDATE())
ORDER BY p.Payment_Date DESC;


-- ============================================================
-- AD-HOC QUERIES
-- ============================================================

-- 1. Revenue by Service Type Query
-- Analyzes revenue across different service categories with time filtering
CREATE OR REPLACE VIEW vw_RevenueByServiceType AS
SELECT
    s.Service_Type,
    COUNT(s.Service_ID)         AS Total_Services,
    SUM(i.Total_Amount)         AS Total_Revenue,
    AVG(i.Total_Amount)         AS Avg_Revenue_Per_Service,
    MIN(s.Service_Date)         AS Earliest_Service,
    MAX(s.Service_Date)         AS Latest_Service
FROM Service s
JOIN Contract con ON s.Contract_ID = con.Contract_ID
JOIN Invoice  i   ON con.Contract_ID = i.Contract_ID
GROUP BY s.Service_Type
ORDER BY Total_Revenue DESC;

-- 2. Top Clients by Revenue Query
-- Identifies clients generating the highest revenue
CREATE OR REPLACE VIEW vw_TopClientsByRevenue AS
SELECT
    c.Client_ID,
    c.Client_Name,
    c.Client_Email,
    c.Client_Phone,
    COUNT(DISTINCT con.Contract_ID) AS Total_Contracts,
    SUM(i.Total_Amount)             AS Total_Billed,
    SUM(i.Amount_Paid)              AS Total_Collected,
    (SUM(i.Total_Amount) - SUM(i.Amount_Paid)) AS Outstanding_Balance
FROM Client   c
JOIN Contract con ON c.Client_ID   = con.Client_ID
JOIN Invoice  i   ON con.Contract_ID = i.Contract_ID
GROUP BY c.Client_ID, c.Client_Name, c.Client_Email, c.Client_Phone
ORDER BY Total_Collected DESC;

-- 3. Revenue by Property Location Query
-- Analyzes revenue from services at specific property locations
CREATE OR REPLACE VIEW vw_RevenueByLocation AS
SELECT
    s.Property_Location,
    COUNT(s.Service_ID)     AS Total_Services,
    SUM(i.Total_Amount)     AS Total_Revenue,
    AVG(i.Total_Amount)     AS Avg_Revenue
FROM Service  s
JOIN Contract con ON s.Contract_ID  = con.Contract_ID
JOIN Invoice  i   ON con.Contract_ID = i.Contract_ID
WHERE s.Property_Location IS NOT NULL
GROUP BY s.Property_Location
ORDER BY Total_Revenue DESC;


-- ============================================================
-- REPORTS
-- ============================================================

-- 1. Monthly Revenue Report
-- Summary of total revenue grouped by client, property, or service type
CREATE OR REPLACE VIEW vw_MonthlyRevenueReport AS
SELECT
    YEAR(s.Service_Date)    AS Revenue_Year,
    MONTH(s.Service_Date)   AS Revenue_Month,
    s.Service_Type,
    c.Client_Name,
    s.Property_Location,
    SUM(i.Total_Amount)     AS Total_Revenue,
    SUM(i.Amount_Paid)      AS Total_Received,
    COUNT(s.Service_ID)     AS Services_Rendered
FROM Service  s
JOIN Client   c   ON s.Client_ID    = c.Client_ID
JOIN Contract con ON s.Contract_ID  = con.Contract_ID
JOIN Invoice  i   ON con.Contract_ID = i.Contract_ID
GROUP BY Revenue_Year, Revenue_Month, s.Service_Type, c.Client_Name, s.Property_Location
ORDER BY Revenue_Year DESC, Revenue_Month DESC;

-- 2. Outstanding Invoice (Aging) Report
-- Displays all unpaid invoices with due dates and time outstanding
CREATE OR REPLACE VIEW vw_OutstandingInvoices AS
SELECT
    i.Invoice_ID,
    c.Client_ID,
    c.Client_Name,
    c.Client_Email,
    i.Invoice_Date,
    i.Due_Date,
    i.Total_Amount,
    i.Amount_Paid,
    (i.Total_Amount - i.Amount_Paid) AS Balance_Due,
    DATEDIFF(CURDATE(), i.Due_Date)  AS Days_Overdue,
    CASE
        WHEN DATEDIFF(CURDATE(), i.Due_Date) <= 0   THEN 'Current'
        WHEN DATEDIFF(CURDATE(), i.Due_Date) <= 30  THEN '1-30 Days'
        WHEN DATEDIFF(CURDATE(), i.Due_Date) <= 60  THEN '31-60 Days'
        WHEN DATEDIFF(CURDATE(), i.Due_Date) <= 90  THEN '61-90 Days'
        ELSE 'Over 90 Days'
    END AS Aging_Bucket
FROM Invoice i
JOIN Contract con ON i.Contract_ID = con.Contract_ID
JOIN Client   c   ON i.Client_ID   = c.Client_ID
WHERE i.Invoice_Status <> 'Paid'
ORDER BY Days_Overdue DESC;

-- 3. Client Service History Report
-- Comprehensive overview of all client interactions
CREATE OR REPLACE VIEW vw_ClientServiceHistory AS
SELECT
    c.Client_ID,
    c.Client_Name,
    c.Property_Address,
    e.Estimate_ID,
    e.Estimate_Date,
    e.Estimated_Cost,
    con.Contract_ID,
    con.Contract_StartDate,
    con.Contract_EndDate,
    s.Service_ID,
    s.Service_Type,
    s.Service_Date,
    s.Property_Location,
    i.Invoice_ID,
    i.Total_Amount,
    i.Invoice_Status,
    p.Payment_ID,
    p.Payment_Amount,
    p.Payment_Date
FROM Client   c
LEFT JOIN Estimate e   ON c.Client_ID    = e.Client_ID
LEFT JOIN Contract con ON e.Estimate_ID  = con.Estimate_ID
LEFT JOIN Service  s   ON con.Contract_ID = s.Contract_ID
LEFT JOIN Invoice  i   ON con.Contract_ID = i.Contract_ID
LEFT JOIN Payment  p   ON i.Invoice_ID   = p.Invoice_ID
ORDER BY c.Client_Name, s.Service_Date DESC;

-- 4. Job Costing Report
-- Compares estimated vs actual costs for completed jobs
CREATE OR REPLACE VIEW vw_JobCostingReport AS
SELECT
    jc.Job_Cost_ID,
    s.Service_ID,
    s.Service_Type,
    s.Service_Date,
    c.Client_Name,
    s.Property_Location,
    jc.Total_Estimated_Cost,
    jc.Total_Actual_Cost,
    jc.Actual_Labor_Hours,
    jc.Actual_Labor_Cost,
    jc.Actual_Materials,
    jc.Variance,
    CASE
        WHEN jc.Variance > 0  THEN 'Over Budget'
        WHEN jc.Variance < 0  THEN 'Under Budget'
        ELSE 'On Budget'
    END AS Budget_Status
FROM Job_Costing jc
JOIN Service s ON jc.Service_ID = s.Service_ID
JOIN Client  c ON s.Client_ID   = c.Client_ID
ORDER BY s.Service_Date DESC;

-- 5. Schedule and Workload Report
-- Overview of upcoming and completed services with employee assignments
CREATE OR REPLACE VIEW vw_ScheduleWorkload AS
SELECT
    s.Service_ID,
    s.Service_Date,
    s.Service_Type,
    c.Client_Name,
    s.Property_Location,
    emp.Employee_Name,
    emp.Employee_Role,
    CASE
        WHEN s.Service_Date < CURDATE()  THEN 'Completed'
        WHEN s.Service_Date = CURDATE()  THEN 'Today'
        ELSE 'Upcoming'
    END AS Status
FROM Service          s
JOIN Client           c   ON s.Client_ID   = c.Client_ID
JOIN Service_Employee se  ON s.Service_ID  = se.Service_ID
JOIN Employee         emp ON se.Employee_ID = emp.Employee_ID
ORDER BY s.Service_Date ASC;


-- ============================================================
-- VIEW: vw_Employee_Clients
-- Shows every unique client each employee has served.
-- Used by: Employee Portal → My Clients section
-- ============================================================
CREATE OR REPLACE VIEW vw_Employee_Clients AS
SELECT
    se.Employee_ID,
    e.Employee_Name,
    c.Client_ID,
    c.Client_Name,
    c.Client_Phone,
    c.Client_Email,
    c.Property_Address,
    MAX(s.Service_Date)            AS Last_Service_Date,
    COUNT(DISTINCT s.Service_ID)   AS Times_Served,
    MAX(s.Service_Description)     AS Last_Description
FROM Service_Employee se
JOIN Employee e ON se.Employee_ID = e.Employee_ID
JOIN Service  s ON se.Service_ID  = s.Service_ID
JOIN Client   c ON s.Client_ID    = c.Client_ID
GROUP BY
    se.Employee_ID, e.Employee_Name,
    c.Client_ID, c.Client_Name, c.Client_Phone,
    c.Client_Email, c.Property_Address;


-- ============================================================
-- SAMPLE DATA
-- ============================================================

-- 10 Clients (IDs 1-10; several will repeat across contracts/invoices as returning clients)
INSERT INTO Client (Client_Name, Client_Phone, Client_Email, Property_Address) VALUES
('John Rivera',        '808-555-0101', 'jrivera@email.com',      '123 Palm Ave, Honolulu, HI'),       -- 1 (returning)
('Maria Santos',       '808-555-0202', 'msantos@email.com',      '456 Orchid St, Kailua, HI'),        -- 2 (returning)
('Pacific Props LLC',  '808-555-0303', 'info@pacificprops.com',  '789 Coral Rd, Kaneohe, HI'),        -- 3 (returning)
('Kevin Nakamura',     '808-555-0404', 'knakamura@email.com',    '22 Banyan Dr, Hilo, HI'),           -- 4 (returning)
('Lani Akana',         '808-555-0505', 'lakana@email.com',       '88 Plumeria Ln, Aiea, HI'),         -- 5 (returning)
('Sunset Rentals Inc', '808-555-0606', 'ops@sunsetrentals.com',  '300 Sunset Blvd, Waipahu, HI'),     -- 6 (returning)
('Tom Ferreira',       '808-555-0707', 'tferreira@email.com',    '14 Hibiscus Way, Pearl City, HI'),  -- 7
('Grace Yamamoto',     '808-555-0808', 'gyamamoto@email.com',    '55 Maile St, Mililani, HI'),        -- 8 (returning)
('Blue Sky HOA',       '808-555-0909', 'admin@blueskyHOA.com',   '200 Skyline Dr, Ewa Beach, HI'),    -- 9 (returning)
('Derek Chun',         '808-555-1010', 'dchun@email.com',        '9 Kukui Ave, Kailua, HI');          -- 10

INSERT INTO Employee (Employee_Name, Employee_Role, Employee_Phone, Employee_Email, Is_Available) VALUES
('Carlos Mendez', 'Lead Landscaper', '808-555-1001', 'cmendez@ae.com', 1),
('Diana Lam',     'Estimator',       '808-555-1002', 'dlam@ae.com',    1),
('Eric Torres',   'Hauling Driver',  '808-555-1003', 'etorres@ae.com', 1),
('Fiona Kahale',  'Sprinkler Tech',  '808-555-1004', 'fkahale@ae.com', 0),
('Ray Souza',     'Lead Landscaper', '808-555-1005', 'rsouza@ae.com',  1),
('Mia Tran',      'Hauling Driver',  '808-555-1006', 'mtran@ae.com',   1);

-- 25 Estimates spread across returning clients
INSERT INTO Estimate (Client_ID, Employee_ID, Property_Address, Service_Description, Estimated_Cost, Estimated_Labor_Hours, Estimate_Date) VALUES
(1,  2, '123 Palm Ave, Honolulu, HI',    'Full lawn care and edging',           450.00,  8.0,  '2024-01-10'),
(2,  2, '456 Orchid St, Kailua, HI',    'Sprinkler system repair',             280.00,  4.0,  '2024-01-15'),
(3,  2, '789 Coral Rd, Kaneohe, HI',    'Debris hauling - backyard',           600.00, 10.0,  '2024-01-20'),
(4,  2, '22 Banyan Dr, Hilo, HI',       'Hedge trimming and cleanup',          320.00,  6.0,  '2024-02-01'),
(5,  2, '88 Plumeria Ln, Aiea, HI',     'Sprinkler installation',              750.00, 12.0,  '2024-02-10'),
(6,  2, '300 Sunset Blvd, Waipahu, HI', 'Commercial grounds maintenance',     1200.00, 20.0,  '2024-02-15'),
(7,  2, '14 Hibiscus Way, Pearl City, HI','Tree trimming and removal',          500.00,  9.0,  '2024-03-01'),
(8,  2, '55 Maile St, Mililani, HI',    'Lawn aeration and fertilization',     380.00,  7.0,  '2024-03-10'),
(9,  2, '200 Skyline Dr, Ewa Beach, HI','HOA common area landscaping',        1500.00, 25.0,  '2024-03-15'),
(10, 2, '9 Kukui Ave, Kailua, HI',      'Yard debris hauling',                 420.00,  8.0,  '2024-03-20'),
-- Returning clients - new estimates
(1,  2, '123 Palm Ave, Honolulu, HI',   'Monthly lawn maintenance Q2',         450.00,  8.0,  '2024-04-05'),
(2,  2, '456 Orchid St, Kailua, HI',   'Sprinkler head replacement',          180.00,  3.0,  '2024-04-12'),
(3,  2, '789 Coral Rd, Kaneohe, HI',   'Large junk hauling - garage',         700.00, 11.0,  '2024-05-01'),
(4,  2, '22 Banyan Dr, Hilo, HI',      'Lawn resodding - front yard',         900.00, 15.0,  '2024-05-10'),
(5,  2, '88 Plumeria Ln, Aiea, HI',    'Sprinkler valve repair',              220.00,  4.0,  '2024-06-01'),
(6,  2, '300 Sunset Blvd, Waipahu, HI','Parking lot weed removal',            650.00, 11.0,  '2024-06-15'),
(8,  2, '55 Maile St, Mililani, HI',   'Garden bed redesign',                 560.00,  9.0,  '2024-07-01'),
(9,  2, '200 Skyline Dr, Ewa Beach, HI','HOA quarterly cleanup',              1100.00, 18.0,  '2024-07-10'),
(1,  2, '123 Palm Ave, Honolulu, HI',  'Fall cleanup and mulching',            390.00,  7.0,  '2024-09-01'),
(2,  2, '456 Orchid St, Kailua, HI',  'Backflow preventer inspection',        150.00,  2.0,  '2024-09-15'),
(6,  2, '300 Sunset Blvd, Waipahu, HI','End-of-year grounds overhaul',       1400.00, 22.0,  '2024-10-01'),
(9,  2, '200 Skyline Dr, Ewa Beach, HI','Holiday lighting install - common',   800.00, 13.0,  '2024-10-20'),
(5,  2, '88 Plumeria Ln, Aiea, HI',   'Drip irrigation installation',         680.00, 11.0,  '2024-11-01'),
(3,  2, '789 Coral Rd, Kaneohe, HI',  'Post-storm debris removal',            850.00, 14.0,  '2024-11-15'),
(4,  2, '22 Banyan Dr, Hilo, HI',     'Year-end lawn treatment',              410.00,  7.0,  '2024-12-01');

-- 25 Contracts (one per estimate, IDs align 1-25)
INSERT INTO Contract (Estimate_ID, Client_ID, Contract_StartDate, Contract_EndDate, Pricing, Service_Scope, Contract_Duration) VALUES
(1,  1,  '2024-01-15', '2024-04-15',  450.00, 'Lawn care and edging monthly',          '3 months'),
(2,  2,  '2024-01-20', '2024-02-20',  280.00, 'Sprinkler repair one-time',             '1 month'),
(3,  3,  '2024-01-25', '2024-03-25',  600.00, 'Hauling and debris removal',            '2 months'),
(4,  4,  '2024-02-05', '2024-03-05',  320.00, 'Hedge trimming service',                '1 month'),
(5,  5,  '2024-02-15', '2024-05-15',  750.00, 'Sprinkler installation project',        '3 months'),
(6,  6,  '2024-02-20', '2024-08-20', 1200.00, 'Commercial grounds - bimonthly',        '6 months'),
(7,  7,  '2024-03-05', '2024-04-05',  500.00, 'Tree trimming and stump removal',       '1 month'),
(8,  8,  '2024-03-15', '2024-06-15',  380.00, 'Lawn aeration and fert program',        '3 months'),
(9,  9,  '2024-03-20', '2024-09-20', 1500.00, 'HOA landscaping - quarterly',           '6 months'),
(10, 10, '2024-03-25', '2024-04-25',  420.00, 'Yard debris removal one-time',          '1 month'),
(11, 1,  '2024-04-10', '2024-07-10',  450.00, 'Monthly lawn maintenance Q2',           '3 months'),
(12, 2,  '2024-04-15', '2024-05-15',  180.00, 'Sprinkler head replacement',            '1 month'),
(13, 3,  '2024-05-05', '2024-06-05',  700.00, 'Large junk hauling project',            '1 month'),
(14, 4,  '2024-05-15', '2024-07-15',  900.00, 'Front yard resodding',                  '2 months'),
(15, 5,  '2024-06-05', '2024-07-05',  220.00, 'Sprinkler valve repair',                '1 month'),
(16, 6,  '2024-06-20', '2024-08-20',  650.00, 'Parking lot weed control',              '2 months'),
(17, 8,  '2024-07-05', '2024-09-05',  560.00, 'Garden bed redesign and planting',      '2 months'),
(18, 9,  '2024-07-15', '2024-10-15', 1100.00, 'HOA quarterly cleanup and trim',        '3 months'),
(19, 1,  '2024-09-05', '2024-10-05',  390.00, 'Fall cleanup and mulch application',    '1 month'),
(20, 2,  '2024-09-20', '2024-10-20',  150.00, 'Backflow preventer inspection',         '1 month'),
(21, 6,  '2024-10-05', '2025-01-05', 1400.00, 'Year-end grounds overhaul',             '3 months'),
(22, 9,  '2024-10-25', '2024-12-25',  800.00, 'Holiday lighting installation',         '2 months'),
(23, 5,  '2024-11-05', '2025-02-05',  680.00, 'Drip irrigation system install',        '3 months'),
(24, 3,  '2024-11-20', '2024-12-20',  850.00, 'Post-storm debris cleanup',             '1 month'),
(25, 4,  '2024-12-05', '2025-01-05',  410.00, 'Year-end lawn treatment',               '1 month');

-- 30 Services spread across contracts (multiple per returning client)
INSERT INTO Service (Client_ID, Contract_ID, Service_Type, Service_Date, Property_Location) VALUES
(1,  1,  'Landscaping',      '2024-02-01', '123 Palm Ave, Honolulu, HI'),
(2,  2,  'Sprinkler Repair', '2024-01-22', '456 Orchid St, Kailua, HI'),
(3,  3,  'Hauling',          '2024-02-05', '789 Coral Rd, Kaneohe, HI'),
(4,  4,  'Landscaping',      '2024-02-10', '22 Banyan Dr, Hilo, HI'),
(5,  5,  'Sprinkler Repair', '2024-02-20', '88 Plumeria Ln, Aiea, HI'),
(6,  6,  'Landscaping',      '2024-03-01', '300 Sunset Blvd, Waipahu, HI'),
(7,  7,  'Landscaping',      '2024-03-10', '14 Hibiscus Way, Pearl City, HI'),
(8,  8,  'Landscaping',      '2024-03-20', '55 Maile St, Mililani, HI'),
(9,  9,  'Landscaping',      '2024-04-01', '200 Skyline Dr, Ewa Beach, HI'),
(10, 10, 'Hauling',          '2024-04-05', '9 Kukui Ave, Kailua, HI'),
(1,  11, 'Landscaping',      '2024-05-01', '123 Palm Ave, Honolulu, HI'),  -- returning client 1
(2,  12, 'Sprinkler Repair', '2024-05-10', '456 Orchid St, Kailua, HI'),  -- returning client 2
(3,  13, 'Hauling',          '2024-05-20', '789 Coral Rd, Kaneohe, HI'),  -- returning client 3
(4,  14, 'Landscaping',      '2024-06-01', '22 Banyan Dr, Hilo, HI'),     -- returning client 4
(5,  15, 'Sprinkler Repair', '2024-06-15', '88 Plumeria Ln, Aiea, HI'),   -- returning client 5
(6,  16, 'Landscaping',      '2024-07-01', '300 Sunset Blvd, Waipahu, HI'),-- returning client 6
(8,  17, 'Landscaping',      '2024-07-15', '55 Maile St, Mililani, HI'),  -- returning client 8
(9,  18, 'Landscaping',      '2024-08-01', '200 Skyline Dr, Ewa Beach, HI'),-- returning client 9
(1,  19, 'Landscaping',      '2024-09-10', '123 Palm Ave, Honolulu, HI'), -- returning client 1 (3rd time)
(2,  20, 'Sprinkler Repair', '2024-09-25', '456 Orchid St, Kailua, HI'),  -- returning client 2 (3rd time)
(6,  21, 'Landscaping',      '2024-10-10', '300 Sunset Blvd, Waipahu, HI'),-- returning client 6 (3rd time)
(9,  22, 'Landscaping',      '2024-11-01', '200 Skyline Dr, Ewa Beach, HI'),-- returning client 9 (3rd time)
(5,  23, 'Sprinkler Repair', '2024-11-10', '88 Plumeria Ln, Aiea, HI'),   -- returning client 5 (3rd time)
(3,  24, 'Hauling',          '2024-11-25', '789 Coral Rd, Kaneohe, HI'),  -- returning client 3 (3rd time)
(4,  25, 'Landscaping',      '2024-12-10', '22 Banyan Dr, Hilo, HI'),     -- returning client 4 (3rd time)
(1,  11, 'Landscaping',      '2024-06-01', '123 Palm Ave, Honolulu, HI'), -- client 1 Q2 follow-up
(6,  6,  'Landscaping',      '2024-05-01', '300 Sunset Blvd, Waipahu, HI'),-- client 6 mid-contract
(9,  9,  'Landscaping',      '2024-07-01', '200 Skyline Dr, Ewa Beach, HI'),-- client 9 mid-contract
(8,  17, 'Landscaping',      '2024-08-15', '55 Maile St, Mililani, HI'),  -- client 8 follow-up
(5,  5,  'Sprinkler Repair', '2024-04-15', '88 Plumeria Ln, Aiea, HI');   -- client 5 mid-contract

INSERT INTO Service_Employee (Service_ID, Employee_ID) VALUES
(1,1),(2,4),(3,3),(4,1),(5,4),(6,5),(7,1),(8,5),(9,1),(10,3),
(11,1),(12,4),(13,6),(14,5),(15,4),(16,5),(17,1),(18,1),(19,5),(20,4),
(21,5),(22,1),(23,4),(24,3),(25,5),(26,1),(27,5),(28,1),(29,5),(30,4);

-- ============================================================
-- 75 INVOICES
-- Clients 1,2,3,4,5,6,8,9 repeat heavily to show returning clients
-- Spread across 2024-2025 with varied statuses
-- ============================================================
INSERT INTO Invoice (Contract_ID, Client_ID, Invoice_Date, Due_Date, Total_Amount, Amount_Paid, Invoice_Status) VALUES
-- 2024 Q1 (original contracts)
( 1,  1, '2024-02-01', '2024-02-15',  450.00,  450.00, 'Paid'),       -- 1  client 1
( 2,  2, '2024-01-22', '2024-02-05',  280.00,    0.00, 'Unpaid'),     -- 2  client 2
( 3,  3, '2024-02-05', '2024-02-20',  600.00,  300.00, 'Partial'),    -- 3  client 3
( 4,  4, '2024-02-10', '2024-02-25',  320.00,  320.00, 'Paid'),       -- 4  client 4
( 5,  5, '2024-02-20', '2024-03-06',  750.00,  750.00, 'Paid'),       -- 5  client 5
( 6,  6, '2024-03-01', '2024-03-16', 1200.00, 1200.00, 'Paid'),       -- 6  client 6
( 7,  7, '2024-03-10', '2024-03-25',  500.00,  500.00, 'Paid'),       -- 7  client 7
( 8,  8, '2024-03-20', '2024-04-04',  380.00,  380.00, 'Paid'),       -- 8  client 8
( 9,  9, '2024-04-01', '2024-04-16', 1500.00, 1500.00, 'Paid'),       -- 9  client 9
(10, 10, '2024-04-05', '2024-04-20',  420.00,  420.00, 'Paid'),       -- 10 client 10

-- 2024 Q2 - returning clients start showing up
(11,  1, '2024-05-01', '2024-05-16',  450.00,  450.00, 'Paid'),       -- 11 client 1 (returning)
(12,  2, '2024-05-10', '2024-05-25',  180.00,  180.00, 'Paid'),       -- 12 client 2 (returning)
(13,  3, '2024-05-20', '2024-06-04',  700.00,  700.00, 'Paid'),       -- 13 client 3 (returning)
(14,  4, '2024-06-01', '2024-06-16',  900.00,  450.00, 'Partial'),    -- 14 client 4 (returning)
(15,  5, '2024-06-15', '2024-06-30',  220.00,  220.00, 'Paid'),       -- 15 client 5 (returning)
(16,  6, '2024-07-01', '2024-07-16',  650.00,  650.00, 'Paid'),       -- 16 client 6 (returning)
( 9,  9, '2024-05-01', '2024-05-16',  375.00,  375.00, 'Paid'),       -- 17 client 9 mid-contract billing
( 6,  6, '2024-05-01', '2024-05-16',  300.00,  300.00, 'Paid'),       -- 18 client 6 mid-contract billing
( 5,  5, '2024-04-15', '2024-04-30',  187.50,  187.50, 'Paid'),       -- 19 client 5 mid-contract billing
(11,  1, '2024-06-01', '2024-06-16',  450.00,  450.00, 'Paid'),       -- 20 client 1 Q2 follow-up

-- 2024 Q3
(17,  8, '2024-07-15', '2024-07-30',  560.00,  560.00, 'Paid'),       -- 21 client 8 (returning)
(18,  9, '2024-08-01', '2024-08-16', 1100.00, 1100.00, 'Paid'),       -- 22 client 9 (returning)
( 9,  9, '2024-07-01', '2024-07-16',  375.00,  375.00, 'Paid'),       -- 23 client 9 Q3 billing
( 6,  6, '2024-07-01', '2024-07-16',  300.00,  300.00, 'Paid'),       -- 24 client 6 Q3 billing
(16,  6, '2024-08-01', '2024-08-16',  325.00,  325.00, 'Paid'),       -- 25 client 6 weed control
(17,  8, '2024-08-15', '2024-08-30',  280.00,  280.00, 'Paid'),       -- 26 client 8 follow-up service
(18,  9, '2024-09-01', '2024-09-16',  550.00,  550.00, 'Paid'),       -- 27 client 9 Q3 follow-up
(14,  4, '2024-07-15', '2024-07-30',  450.00,  450.00, 'Paid'),       -- 28 client 4 resod final payment
( 1,  1, '2024-07-01', '2024-07-16',  225.00,  225.00, 'Paid'),       -- 29 client 1 add-on service
( 5,  5, '2024-07-15', '2024-07-30',  187.50,  187.50, 'Paid'),       -- 30 client 5 sprinkler Q3

-- 2024 Q4
(19,  1, '2024-09-10', '2024-09-25',  390.00,  390.00, 'Paid'),       -- 31 client 1 (returning 3rd contract)
(20,  2, '2024-09-25', '2024-10-10',  150.00,  150.00, 'Paid'),       -- 32 client 2 (returning 3rd contract)
(21,  6, '2024-10-10', '2024-10-25', 1400.00, 1400.00, 'Paid'),       -- 33 client 6 (returning 3rd contract)
(22,  9, '2024-11-01', '2024-11-16',  800.00,  800.00, 'Paid'),       -- 34 client 9 (returning - holiday)
(23,  5, '2024-11-10', '2024-11-25',  680.00,  680.00, 'Paid'),       -- 35 client 5 (returning 3rd contract)
(24,  3, '2024-11-25', '2024-12-10',  850.00,  850.00, 'Paid'),       -- 36 client 3 (returning 3rd contract)
(25,  4, '2024-12-10', '2024-12-25',  410.00,  410.00, 'Paid'),       -- 37 client 4 (returning 3rd contract)
(21,  6, '2024-11-01', '2024-11-16',  467.00,  467.00, 'Paid'),       -- 38 client 6 Q4 installment
(21,  6, '2024-12-01', '2024-12-16',  467.00,  467.00, 'Paid'),       -- 39 client 6 Q4 final
(18,  9, '2024-10-15', '2024-10-30',  550.00,  550.00, 'Paid'),       -- 40 client 9 Q4 billing

-- 2025 Q1
(23,  5, '2025-01-10', '2025-01-25',  340.00,  340.00, 'Paid'),       -- 41 client 5 drip irrigation
( 1,  1, '2025-01-15', '2025-01-30',  450.00,  450.00, 'Paid'),       -- 42 client 1 new year service
( 2,  2, '2025-01-20', '2025-02-04',  280.00,  280.00, 'Paid'),       -- 43 client 2 new year service
( 9,  9, '2025-01-05', '2025-01-20',  375.00,  375.00, 'Paid'),       -- 44 client 9 Q1 billing
( 6,  6, '2025-01-08', '2025-01-23',  600.00,  600.00, 'Paid'),       -- 45 client 6 Q1 billing
( 3,  3, '2025-01-20', '2025-02-04',  425.00,  425.00, 'Paid'),       -- 46 client 3 new service
( 8,  8, '2025-01-25', '2025-02-09',  380.00,  380.00, 'Paid'),       -- 47 client 8 new service
( 4,  4, '2025-02-01', '2025-02-16',  320.00,  320.00, 'Paid'),       -- 48 client 4 new service
( 5,  5, '2025-02-05', '2025-02-20',  220.00,  220.00, 'Paid'),       -- 49 client 5 routine
( 1,  1, '2025-02-15', '2025-03-02',  450.00,  450.00, 'Paid'),       -- 50 client 1 Q1 final

-- 2025 Q2
( 9,  9, '2025-02-01', '2025-02-16',  750.00,  750.00, 'Paid'),       -- 51 client 9 Q2 early billing
( 6,  6, '2025-02-10', '2025-02-25',  650.00,  650.00, 'Paid'),       -- 52 client 6 Q2 billing
( 2,  2, '2025-02-20', '2025-03-07',  180.00,  180.00, 'Paid'),       -- 53 client 2 sprinkler tune-up
( 8,  8, '2025-03-01', '2025-03-16',  560.00,  560.00, 'Paid'),       -- 54 client 8 spring service
( 3,  3, '2025-03-05', '2025-03-20',  600.00,  600.00, 'Paid'),       -- 55 client 3 spring hauling
( 5,  5, '2025-03-10', '2025-03-25',  340.00,  340.00, 'Paid'),       -- 56 client 5 spring irrigation
( 4,  4, '2025-03-15', '2025-03-30',  450.00,  450.00, 'Paid'),       -- 57 client 4 spring lawn
( 1,  1, '2025-03-20', '2025-04-04',  475.00,  475.00, 'Paid'),       -- 58 client 1 spring cleanup
( 9,  9, '2025-03-01', '2025-03-16',  375.00,  375.00, 'Paid'),       -- 59 client 9 Q2 mid-billing
( 6,  6, '2025-03-15', '2025-03-30',  300.00,  300.00, 'Paid'),       -- 60 client 6 Q2 mid-billing

-- 2025 Q2 (April - May) - mix of Paid, Partial, Unpaid
( 1,  1, '2025-04-01', '2025-04-16',  500.00,  500.00, 'Paid'),       -- 61 client 1
( 2,  2, '2025-04-05', '2025-04-20',  280.00,  280.00, 'Paid'),       -- 62 client 2
( 9,  9, '2025-04-01', '2025-04-16',  750.00,  375.00, 'Partial'),    -- 63 client 9
( 6,  6, '2025-04-10', '2025-04-25',  700.00,  700.00, 'Paid'),       -- 64 client 6
( 3,  3, '2025-04-15', '2025-04-30',  625.00,    0.00, 'Unpaid'),     -- 65 client 3
( 5,  5, '2025-04-20', '2025-05-05',  360.00,  360.00, 'Paid'),       -- 66 client 5
( 8,  8, '2025-04-25', '2025-05-10',  420.00,  420.00, 'Paid'),       -- 67 client 8
( 4,  4, '2025-04-30', '2025-05-15',  390.00,    0.00, 'Unpaid'),     -- 68 client 4
( 9,  9, '2025-05-01', '2025-05-16',  375.00,    0.00, 'Unpaid'),     -- 69 client 9 (most recent)
( 6,  6, '2025-05-01', '2025-05-16',  650.00,    0.00, 'Unpaid'),     -- 70 client 6 (most recent)
( 1,  1, '2025-05-01', '2025-05-16',  500.00,  250.00, 'Partial'),    -- 71 client 1 (most recent)
( 2,  2, '2025-05-05', '2025-05-20',  280.00,    0.00, 'Unpaid'),     -- 72 client 2 (most recent)
( 5,  5, '2025-05-10', '2025-05-25',  340.00,    0.00, 'Unpaid'),     -- 73 client 5 (most recent)
( 8,  8, '2025-05-10', '2025-05-25',  420.00,  210.00, 'Partial'),    -- 74 client 8 (most recent)
( 3,  3, '2025-05-15', '2025-05-30',  700.00,    0.00, 'Unpaid');     -- 75 client 3 (most recent)

-- Payments (covering paid and partial invoices)
INSERT INTO Payment (Contract_ID, Invoice_ID, Payment_Amount, Payment_Method, Due_Date, Payment_Date, Payment_Status) VALUES
( 1,  1,  450.00, 'Check',          '2024-02-15', '2024-02-10', 'Paid'),
( 3,  3,  300.00, 'Bank Transfer',  '2024-02-20', '2024-02-18', 'Paid'),
( 4,  4,  320.00, 'Credit Card',    '2024-02-25', '2024-02-20', 'Paid'),
( 5,  5,  750.00, 'Check',          '2024-03-06', '2024-03-01', 'Paid'),
( 6,  6, 1200.00, 'Bank Transfer',  '2024-03-16', '2024-03-12', 'Paid'),
( 7,  7,  500.00, 'Cash',           '2024-03-25', '2024-03-22', 'Paid'),
( 8,  8,  380.00, 'Check',          '2024-04-04', '2024-04-01', 'Paid'),
( 9,  9, 1500.00, 'Bank Transfer',  '2024-04-16', '2024-04-10', 'Paid'),
(10, 10,  420.00, 'Credit Card',    '2024-04-20', '2024-04-18', 'Paid'),
(11, 11,  450.00, 'Check',          '2024-05-16', '2024-05-12', 'Paid'),
(12, 12,  180.00, 'Cash',           '2024-05-25', '2024-05-20', 'Paid'),
(13, 13,  700.00, 'Bank Transfer',  '2024-06-04', '2024-05-30', 'Paid'),
(14, 14,  450.00, 'Check',          '2024-06-16', '2024-06-10', 'Paid'),
(15, 15,  220.00, 'Credit Card',    '2024-06-30', '2024-06-25', 'Paid'),
(16, 16,  650.00, 'Bank Transfer',  '2024-07-16', '2024-07-10', 'Paid'),
( 9, 17,  375.00, 'Check',          '2024-05-16', '2024-05-14', 'Paid'),
( 6, 18,  300.00, 'Bank Transfer',  '2024-05-16', '2024-05-13', 'Paid'),
( 5, 19,  187.50, 'Credit Card',    '2024-04-30', '2024-04-28', 'Paid'),
(11, 20,  450.00, 'Check',          '2024-06-16', '2024-06-14', 'Paid'),
(17, 21,  560.00, 'Bank Transfer',  '2024-07-30', '2024-07-25', 'Paid'),
(18, 22, 1100.00, 'Check',          '2024-08-16', '2024-08-12', 'Paid'),
( 9, 23,  375.00, 'Bank Transfer',  '2024-07-16', '2024-07-14', 'Paid'),
( 6, 24,  300.00, 'Bank Transfer',  '2024-07-16', '2024-07-13', 'Paid'),
(16, 25,  325.00, 'Credit Card',    '2024-08-16', '2024-08-14', 'Paid'),
(17, 26,  280.00, 'Check',          '2024-08-30', '2024-08-28', 'Paid'),
(18, 27,  550.00, 'Bank Transfer',  '2024-09-16', '2024-09-12', 'Paid'),
(14, 28,  450.00, 'Check',          '2024-07-30', '2024-07-28', 'Paid'),
( 1, 29,  225.00, 'Cash',           '2024-07-16', '2024-07-15', 'Paid'),
( 5, 30,  187.50, 'Credit Card',    '2024-07-30', '2024-07-28', 'Paid'),
(19, 31,  390.00, 'Check',          '2024-09-25', '2024-09-22', 'Paid'),
(20, 32,  150.00, 'Cash',           '2024-10-10', '2024-10-08', 'Paid'),
(21, 33, 1400.00, 'Bank Transfer',  '2024-10-25', '2024-10-20', 'Paid'),
(22, 34,  800.00, 'Check',          '2024-11-16', '2024-11-12', 'Paid'),
(23, 35,  680.00, 'Bank Transfer',  '2024-11-25', '2024-11-20', 'Paid'),
(24, 36,  850.00, 'Credit Card',    '2024-12-10', '2024-12-08', 'Paid'),
(25, 37,  410.00, 'Check',          '2024-12-25', '2024-12-20', 'Paid'),
(21, 38,  467.00, 'Bank Transfer',  '2024-11-16', '2024-11-14', 'Paid'),
(21, 39,  467.00, 'Bank Transfer',  '2024-12-16', '2024-12-14', 'Paid'),
(18, 40,  550.00, 'Check',          '2024-10-30', '2024-10-28', 'Paid'),
(23, 41,  340.00, 'Credit Card',    '2025-01-25', '2025-01-22', 'Paid'),
( 1, 42,  450.00, 'Check',          '2025-01-30', '2025-01-28', 'Paid'),
( 2, 43,  280.00, 'Bank Transfer',  '2025-02-04', '2025-02-01', 'Paid'),
( 9, 44,  375.00, 'Check',          '2025-01-20', '2025-01-18', 'Paid'),
( 6, 45,  600.00, 'Bank Transfer',  '2025-01-23', '2025-01-20', 'Paid'),
( 3, 46,  425.00, 'Credit Card',    '2025-02-04', '2025-02-02', 'Paid'),
( 8, 47,  380.00, 'Check',          '2025-02-09', '2025-02-06', 'Paid'),
( 4, 48,  320.00, 'Cash',           '2025-02-16', '2025-02-14', 'Paid'),
( 5, 49,  220.00, 'Credit Card',    '2025-02-20', '2025-02-18', 'Paid'),
( 1, 50,  450.00, 'Check',          '2025-03-02', '2025-02-28', 'Paid'),
( 9, 51,  750.00, 'Bank Transfer',  '2025-02-16', '2025-02-14', 'Paid'),
( 6, 52,  650.00, 'Bank Transfer',  '2025-02-25', '2025-02-22', 'Paid'),
( 2, 53,  180.00, 'Cash',           '2025-03-07', '2025-03-05', 'Paid'),
( 8, 54,  560.00, 'Check',          '2025-03-16', '2025-03-14', 'Paid'),
( 3, 55,  600.00, 'Credit Card',    '2025-03-20', '2025-03-18', 'Paid'),
( 5, 56,  340.00, 'Bank Transfer',  '2025-03-25', '2025-03-22', 'Paid'),
( 4, 57,  450.00, 'Check',          '2025-03-30', '2025-03-28', 'Paid'),
( 1, 58,  475.00, 'Credit Card',    '2025-04-04', '2025-04-01', 'Paid'),
( 9, 59,  375.00, 'Bank Transfer',  '2025-03-16', '2025-03-14', 'Paid'),
( 6, 60,  300.00, 'Bank Transfer',  '2025-03-30', '2025-03-28', 'Paid'),
( 1, 61,  500.00, 'Check',          '2025-04-16', '2025-04-14', 'Paid'),
( 2, 62,  280.00, 'Bank Transfer',  '2025-04-20', '2025-04-18', 'Paid'),
( 9, 63,  375.00, 'Check',          '2025-04-16', '2025-04-20', 'Paid'),  -- partial
( 6, 64,  700.00, 'Bank Transfer',  '2025-04-25', '2025-04-22', 'Paid'),
( 5, 66,  360.00, 'Credit Card',    '2025-05-05', '2025-05-02', 'Paid'),
( 8, 67,  420.00, 'Check',          '2025-05-10', '2025-05-08', 'Paid'),
( 1, 71,  250.00, 'Check',          '2025-05-16', '2025-05-14', 'Paid'),  -- partial payment
( 8, 74,  210.00, 'Credit Card',    '2025-05-25', '2025-05-22', 'Paid');  -- partial payment

INSERT INTO Client_Feedback (Client_ID, Service_ID, Rating, Comments, Suggestions, Feedback_Date) VALUES
(1,  1,  5, 'Excellent work, very thorough!',          'Keep up the great service.',            '2024-02-03'),
(2,  2,  4, 'Good job on the sprinklers.',             'Arrive a bit earlier next time.',       '2024-01-24'),
(3,  3,  3, 'Hauling was okay, took longer expected.', 'Bring more crew next time.',            '2024-02-08'),
(4,  4,  5, 'Hedges look perfect!',                    'No suggestions.',                       '2024-02-15'),
(5,  5,  5, 'Sprinkler install was flawless.',         'Would love drip irrigation next.',      '2024-02-25'),
(6,  6,  4, 'Grounds look great overall.',             'Communication could be better.',        '2024-03-05'),
(9,  9,  5, 'HOA is very happy with the results.',    'Continue the good work.',               '2024-04-05'),
(1, 11,  5, 'Always reliable, great crew.',            'Maybe offer a loyalty discount.',       '2024-05-05'),
(8, 17,  4, 'Garden looks beautiful.',                 'Plant selection was excellent.',        '2024-07-18'),
(9, 18,  5, 'Best landscaping company we have used.',  'No suggestions, keep it up!',           '2024-08-05');

INSERT INTO Job_Costing (Service_ID, Estimate_ID, Actual_Labor_Hours, Actual_Labor_Cost, Actual_Materials, Total_Actual_Cost, Total_Estimated_Cost) VALUES
(1,  1,  7.5,  225.00,  80.00,  305.00,  450.00),
(2,  2,  4.5,  135.00,  60.00,  195.00,  280.00),
(3,  3, 11.0,  330.00, 150.00,  480.00,  600.00),
(4,  4,  6.0,  180.00,  50.00,  230.00,  320.00),
(5,  5, 13.0,  390.00, 200.00,  590.00,  750.00),
(6,  6, 21.0,  630.00, 310.00,  940.00, 1200.00),
(7,  7,  9.5,  285.00, 120.00,  405.00,  500.00),
(8,  8,  7.0,  210.00,  90.00,  300.00,  380.00),
(9,  9, 26.0,  780.00, 400.00, 1180.00, 1500.00),
(10,10,  8.5,  255.00, 100.00,  355.00,  420.00);


-- ============================================================
-- QUICK REFERENCE: How to Run Each Query/Report
-- ============================================================
-- SELECT * FROM vw_ClientFeedback;
-- SELECT * FROM vw_EstimateEmployees;
-- SELECT * FROM vw_ServiceEmployees;
-- SELECT * FROM vw_PaymentsThisMonth;
-- SELECT * FROM vw_RevenueByServiceType;
-- SELECT * FROM vw_TopClientsByRevenue;
-- SELECT * FROM vw_RevenueByLocation;
-- SELECT * FROM vw_MonthlyRevenueReport;
-- SELECT * FROM vw_OutstandingInvoices;
-- SELECT * FROM vw_ClientServiceHistory;
-- SELECT * FROM vw_JobCostingReport;
-- SELECT * FROM vw_ScheduleWorkload;
