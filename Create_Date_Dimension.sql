-- ============================================================
-- Reference.Date Dimension 

-- Configuration:
--   @StartDate            — first date in the dimension
--   @EndDate              — last date in the dimension
--   @FiscalYearStartMonth — 1 = calendar year
--
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Reference')
    EXEC('CREATE SCHEMA Reference');
GO

-- ============================================================
-- All DDL + DML in one batch so variables are in scope
-- ============================================================
SET DATEFIRST 7;        -- 7 sets Sunday as first day of week i.e. 1=Sunday, 2=Monday, ..., 7=Saturday
SET NOCOUNT ON;

DECLARE @StartDate            DATE    = '2000-01-01';
DECLARE @EndDate              DATE    = '2099-12-31';
DECLARE @FiscalYearStartMonth TINYINT = 1;      -- 1 = calendar year 

-- ============================================================
-- 1.  Table definition
-- ============================================================
DROP TABLE IF EXISTS Reference.[Date];

CREATE TABLE Reference.[Date] (
    [Id]                         UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    [Date]                       DATE             NOT NULL,
    [DateKey]                    INT              NOT NULL,   -- YYYYMMDD integer; use as FK in fact tables

    -- ---- Year -----------------------------------------------
    [Year]                       SMALLINT         NOT NULL,
    [StartOfYear]                DATE             NOT NULL,
    [EndOfYear]                  DATE             NOT NULL,

    -- ---- Month ----------------------------------------------
    [Month]                      TINYINT          NOT NULL,
    [MonthName]                  VARCHAR(10)      NOT NULL,
    [MonthNameShort]             CHAR(3)          NOT NULL,
    [StartOfMonth]               DATE             NOT NULL,
    [EndOfMonth]                 DATE             NOT NULL,
    [DaysInMonth]                TINYINT          NOT NULL,
    [YearMonthNumber]            INT              NOT NULL,   -- YYYYMM
    [YearMonthName]              VARCHAR(10)      NOT NULL,   -- 'YYYY-MMM'

    -- ---- Day ------------------------------------------------
    [Day]                        TINYINT          NOT NULL,
    [DayName]                    VARCHAR(10)      NOT NULL,
    [DayNameShort]               CHAR(3)          NOT NULL,
    [DayOfWeek]                  TINYINT          NOT NULL,   -- 1=Sunday (DAX WEEKDAY default)
    [DayOfYear]                  SMALLINT         NOT NULL,

    -- ---- Week -----------------------------------------------
    [WeekOfYear]                 TINYINT          NOT NULL,
    [WeekOfQuarter]              TINYINT          NOT NULL,
    [StartOfWeek]                DATE             NOT NULL,   -- Sunday
    [EndOfWeek]                  DATE             NOT NULL,   -- Saturday

    -- ---- Quarter --------------------------------------------
    [Quarter]                    TINYINT          NOT NULL,
    [QuarterName]                CHAR(2)          NOT NULL,   -- 'Q1' .. 'Q4'
    [YearQuarterNumber]          INT              NOT NULL,   -- YYYYQ
    [YearQuarterName]            VARCHAR(8)       NOT NULL,   -- 'YYYY Q1'
    [StartOfQuarter]             DATE             NOT NULL,
    [EndOfQuarter]               DATE             NOT NULL,

    -- ---- Fiscal (start month = @FiscalYearStartMonth) -------
    [FiscalYear]                 SMALLINT         NOT NULL,   -- year in which the fiscal year ends
    [FiscalQuarter]              TINYINT          NOT NULL,
    [FiscalMonth]                TINYINT          NOT NULL,   -- 1 = first month of fiscal year

    -- ---- Holiday / Business Day -----------------------------
    -- Populated by Create_Date_Dimension_Holidays.sql after holiday data is loaded.
    -- IsBusinessDay is initialised here (weekday = 1) and flipped to 0 for observed holidays by that script.
    [IsHoliday]                  BIT              NOT NULL DEFAULT 0,
    [HolidayName]                NVARCHAR(200)    NULL,
    [IsBusinessDay]              BIT              NOT NULL DEFAULT 0,   -- 1 = weekday and not an observed holiday

    CONSTRAINT PK_Reference_Date PRIMARY KEY CLUSTERED ([Date])
);

-- ============================================================
-- 2.  Generate date spine via cross-joined numbers CTE
--     L4 yields 65,536 rows — covers ~179 years
-- ============================================================
WITH
    L0   AS (SELECT 1 AS c UNION ALL SELECT 1),
    L1   AS (SELECT 1 AS c FROM L0 a CROSS JOIN L0 b),
    L2   AS (SELECT 1 AS c FROM L1 a CROSS JOIN L1 b),
    L3   AS (SELECT 1 AS c FROM L2 a CROSS JOIN L2 b),
    L4   AS (SELECT 1 AS c FROM L3 a CROSS JOIN L3 b),
    Nums AS (
        SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
        FROM L4
    ),
    Cal  AS (
        SELECT CAST(DATEADD(DAY, n, @StartDate) AS DATE) AS d
        FROM Nums
        WHERE n <= DATEDIFF(DAY, @StartDate, @EndDate)
    )
INSERT INTO Reference.[Date] (
    [Date],
    [DateKey],
    [Year],
    [StartOfYear],
    [EndOfYear],
    [Month],
    [MonthName],
    [MonthNameShort],
    [StartOfMonth],
    [EndOfMonth],
    [DaysInMonth],
    [YearMonthNumber],
    [YearMonthName],
    [Day],
    [DayName],
    [DayNameShort],
    [DayOfWeek],
    [DayOfYear],
    [WeekOfYear],
    [WeekOfQuarter],
    [StartOfWeek],
    [EndOfWeek],
    [Quarter],
    [QuarterName],
    [YearQuarterNumber],
    [YearQuarterName],
    [StartOfQuarter],
    [EndOfQuarter],
    [FiscalYear],
    [FiscalQuarter],
    [FiscalMonth],
    [IsHoliday],
    [HolidayName],
    [IsBusinessDay]
)
SELECT
    -- Date & surrogate key
    d,
    x.Yr * 10000 + x.Mn * 100 + DAY(d),                               -- DateKey YYYYMMDD

    -- Year
    CAST(x.Yr AS SMALLINT),                                            -- Year
    CAST(DATEFROMPARTS(x.Yr,  1,  1) AS DATE),                         -- StartOfYear
    CAST(DATEFROMPARTS(x.Yr, 12, 31) AS DATE),                         -- EndOfYear

    -- Month
    CAST(x.Mn AS TINYINT),                                             -- Month
    FORMAT(d, 'MMMM'),                                                 -- MonthName
    FORMAT(d, 'MMM'),                                                  -- MonthNameShort
    CAST(DATEFROMPARTS(x.Yr, x.Mn, 1) AS DATE),                        -- StartOfMonth
    CAST(EOMONTH(d) AS DATE),                                          -- EndOfMonth
    CAST(
        DATEDIFF(DAY, DATEFROMPARTS(x.Yr, x.Mn, 1), EOMONTH(d)) + 1
    AS TINYINT),                                                       -- DaysInMonth
    x.Yr * 100 + x.Mn,                                                -- YearMonthNumber  (YYYYMM)
    FORMAT(d, 'yyyy-MMM'),                                             -- YearMonthName

    -- Day
    CAST(DAY(d) AS TINYINT),                                           -- Day
    FORMAT(d, 'dddd'),                                                 -- DayName
    FORMAT(d, 'ddd'),                                                  -- DayNameShort
    CAST(x.WkDay AS TINYINT),                                          -- DayOfWeek  (1=Sun, SET DATEFIRST 7)
    CAST(DATEPART(DAYOFYEAR, d) AS SMALLINT),                          -- DayOfYear

    -- Week  (DATEPART(WEEK,...) respects SET DATEFIRST 7, so week starts Sunday)
    CAST(DATEPART(WEEK, d) AS TINYINT),                                -- WeekOfYear
    CAST(
        DATEPART(WEEK, d)
        - DATEPART(WEEK, DATEFROMPARTS(x.Yr, (x.Qtr * 3) - 2, 1))
        + 1
    AS TINYINT),                                                       -- WeekOfQuarter
    CAST(DATEADD(DAY, 1 - x.WkDay, d) AS DATE),                       -- StartOfWeek  (Sunday)
    CAST(DATEADD(DAY, 7 - x.WkDay, d) AS DATE),                       -- EndOfWeek    (Saturday)

    -- Quarter
    CAST(x.Qtr AS TINYINT),                                            -- Quarter
    'Q' + CAST(x.Qtr AS CHAR(1)),                                      -- QuarterName
    x.Yr * 10 + x.Qtr,                                                -- YearQuarterNumber  (YYYYQ)
    CAST(x.Yr AS VARCHAR(4)) + ' Q' + CAST(x.Qtr AS VARCHAR(1)),       -- YearQuarterName
    CAST(DATEFROMPARTS(x.Yr, (x.Qtr * 3) - 2, 1) AS DATE),            -- StartOfQuarter
    CAST(EOMONTH(DATEFROMPARTS(x.Yr, x.Qtr * 3, 1)) AS DATE),         -- EndOfQuarter

    -- Fiscal
    -- FiscalYear: the calendar year in which the fiscal year ends.
    --   When @FiscalYearStartMonth > 1, integer division flips to +1 once the month
    --   crosses the fiscal year boundary (e.g. Jul 2024 → FY 2025 when startMonth = 7).
    CAST(
        CASE
            WHEN @FiscalYearStartMonth = 1 THEN x.Yr
            ELSE x.Yr + (x.Mn + (13 - @FiscalYearStartMonth)) / 13
        END
    AS SMALLINT),                                                      -- FiscalYear

    -- FiscalQuarter: 1 = first quarter of fiscal year
    -- FiscalMonth:   1 = first month of fiscal year (e.g. July when startMonth = 7)
    CAST(((x.Mn - @FiscalYearStartMonth + 12) % 12) / 3 + 1 AS TINYINT),  -- FiscalQuarter
    CAST(((x.Mn - @FiscalYearStartMonth + 12) % 12)     + 1 AS TINYINT),  -- FiscalMonth

    -- Holiday columns — seeded here, updated by Create_Date_Dimension_Holidays.sql
    CAST(0 AS BIT),                                                        -- IsHoliday   (default: not a holiday)
    CAST(NULL AS NVARCHAR(200)),                                           -- HolidayName (null until holiday script runs)
    CAST(CASE WHEN x.WkDay IN (1, 7) THEN 0 ELSE 1 END AS BIT)            -- IsBusinessDay (0 on Sat/Sun; holidays flipped later)

FROM Cal
CROSS APPLY (
    SELECT
        YEAR(d)              AS Yr,
        MONTH(d)             AS Mn,
        DATEPART(QUARTER, d) AS Qtr,
        DATEPART(WEEKDAY, d) AS WkDay
) x;

-- ============================================================
-- 3.  Supporting indexes
-- ============================================================
CREATE NONCLUSTERED INDEX IX_Reference_Date_Year_Month
    ON Reference.[Date] ([Year], [Month])
    INCLUDE ([MonthName], [YearMonthName]);

CREATE NONCLUSTERED INDEX IX_Reference_Date_FiscalYear_Month
    ON Reference.[Date] ([FiscalYear], [FiscalMonth])
    INCLUDE ([FiscalQuarter]);

CREATE NONCLUSTERED INDEX IX_Reference_Date_DateKey
    ON Reference.[Date] ([DateKey]);

CREATE NONCLUSTERED INDEX IX_Reference_Date_IsBusinessDay
    ON Reference.[Date] ([IsBusinessDay])
    INCLUDE ([Date], [Year], [Month], [FiscalYear], [FiscalMonth]);
GO


