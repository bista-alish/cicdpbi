IF OBJECT_ID('Reference.DateHoliday', 'U') IS NULL
BEGIN
    CREATE TABLE Reference.DateHoliday
    (
        Id                  UNIQUEIDENTIFIER    NOT NULL DEFAULT NEWID(),
        HolidayYear         INT                 NOT NULL,
        HolidayName         NVARCHAR(200)       NOT NULL,
        HolidayDate         DATE                NOT NULL,
        ObservedDate        DATE                NOT NULL,
        IsObservedDifferent BIT                 NOT NULL,
        IsObserved          BIT                 NOT NULL DEFAULT 1,
        CreateDate          DATETIME            NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_Reference_DateHoliday PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_Reference_DateHoliday_Year_Name UNIQUE (HolidayYear, HolidayName)
    );
END
GO

-- Safe to re-run: clear existing rows before re-inserting
TRUNCATE TABLE Reference.DateHoliday;
GO

SET DATEFIRST 7; -- 1=Sunday, 7=Saturday

;WITH Years AS (
    SELECT 2000 AS Y
    UNION ALL
    SELECT Y + 1 FROM Years WHERE Y < 2100
),
Holidays AS (
    -- =============================================
    -- Fixed-date holidays
    -- Observed rule: Sat -> Fri, Sun -> Mon
    -- =============================================

    -- New Year's Day (January 1)
    SELECT
        Y AS HolidayYear,
        N'New Year''s Day' AS HolidayName,
        DATEFROMPARTS(Y, 1, 1) AS HolidayDate,
        CASE DATEPART(dw, DATEFROMPARTS(Y, 1, 1))
            WHEN 7 THEN DATEADD(DAY, -1, DATEFROMPARTS(Y, 1, 1))
            WHEN 1 THEN DATEADD(DAY,  1, DATEFROMPARTS(Y, 1, 1))
            ELSE DATEFROMPARTS(Y, 1, 1)
        END AS ObservedDate
    FROM Years

    UNION ALL

    -- Independence Day (July 4)
    SELECT
        Y,
        N'Independence Day',
        DATEFROMPARTS(Y, 7, 4),
        CASE DATEPART(dw, DATEFROMPARTS(Y, 7, 4))
            WHEN 7 THEN DATEADD(DAY, -1, DATEFROMPARTS(Y, 7, 4))
            WHEN 1 THEN DATEADD(DAY,  1, DATEFROMPARTS(Y, 7, 4))
            ELSE DATEFROMPARTS(Y, 7, 4)
        END
    FROM Years

    UNION ALL

    -- Veterans Day (November 11)
    SELECT
        Y,
        N'Veterans Day',
        DATEFROMPARTS(Y, 11, 11),
        CASE DATEPART(dw, DATEFROMPARTS(Y, 11, 11))
            WHEN 7 THEN DATEADD(DAY, -1, DATEFROMPARTS(Y, 11, 11))
            WHEN 1 THEN DATEADD(DAY,  1, DATEFROMPARTS(Y, 11, 11))
            ELSE DATEFROMPARTS(Y, 11, 11)
        END
    FROM Years

    UNION ALL

    -- Christmas Day (December 25)
    SELECT
        Y,
        N'Christmas Day',
        DATEFROMPARTS(Y, 12, 25),
        CASE DATEPART(dw, DATEFROMPARTS(Y, 12, 25))
            WHEN 7 THEN DATEADD(DAY, -1, DATEFROMPARTS(Y, 12, 25))
            WHEN 1 THEN DATEADD(DAY,  1, DATEFROMPARTS(Y, 12, 25))
            ELSE DATEFROMPARTS(Y, 12, 25)
        END
    FROM Years

    UNION ALL

    -- Juneteenth National Independence Day (June 19, starting 2021)
    SELECT
        Y,
        N'Juneteenth National Independence Day',
        DATEFROMPARTS(Y, 6, 19),
        CASE DATEPART(dw, DATEFROMPARTS(Y, 6, 19))
            WHEN 7 THEN DATEADD(DAY, -1, DATEFROMPARTS(Y, 6, 19))
            WHEN 1 THEN DATEADD(DAY,  1, DATEFROMPARTS(Y, 6, 19))
            ELSE DATEFROMPARTS(Y, 6, 19)
        END
    FROM Years
    WHERE Y >= 2021

    UNION ALL

    -- =============================================
    -- Nth weekday holidays
    -- These land on weekdays, so Observed = Actual
    -- =============================================

    -- Martin Luther King Jr. Day (3rd Monday of January)
    SELECT
        Y,
        N'Martin Luther King Jr. Day',
        DATEADD(DAY, ((2 - DATEPART(dw, DATEFROMPARTS(Y, 1, 1)) + 7) % 7) + 14, DATEFROMPARTS(Y, 1, 1)),
        DATEADD(DAY, ((2 - DATEPART(dw, DATEFROMPARTS(Y, 1, 1)) + 7) % 7) + 14, DATEFROMPARTS(Y, 1, 1))
    FROM Years

    UNION ALL

    -- Washington's Birthday (3rd Monday of February)
    SELECT
        Y,
        N'Washington''s Birthday',
        DATEADD(DAY, ((2 - DATEPART(dw, DATEFROMPARTS(Y, 2, 1)) + 7) % 7) + 14, DATEFROMPARTS(Y, 2, 1)),
        DATEADD(DAY, ((2 - DATEPART(dw, DATEFROMPARTS(Y, 2, 1)) + 7) % 7) + 14, DATEFROMPARTS(Y, 2, 1))
    FROM Years

    UNION ALL

    -- Memorial Day (Last Monday of May)
    SELECT
        Y,
        N'Memorial Day',
        DATEADD(DAY, -((DATEPART(dw, DATEFROMPARTS(Y, 5, 31)) + 5) % 7), DATEFROMPARTS(Y, 5, 31)),
        DATEADD(DAY, -((DATEPART(dw, DATEFROMPARTS(Y, 5, 31)) + 5) % 7), DATEFROMPARTS(Y, 5, 31))
    FROM Years

    UNION ALL

    -- Labor Day (1st Monday of September)
    SELECT
        Y,
        N'Labor Day',
        DATEADD(DAY, (2 - DATEPART(dw, DATEFROMPARTS(Y, 9, 1)) + 7) % 7, DATEFROMPARTS(Y, 9, 1)),
        DATEADD(DAY, (2 - DATEPART(dw, DATEFROMPARTS(Y, 9, 1)) + 7) % 7, DATEFROMPARTS(Y, 9, 1))
    FROM Years

    UNION ALL

    -- Columbus Day (2nd Monday of October)
    SELECT
        Y,
        N'Columbus Day',
        DATEADD(DAY, ((2 - DATEPART(dw, DATEFROMPARTS(Y, 10, 1)) + 7) % 7) + 7, DATEFROMPARTS(Y, 10, 1)),
        DATEADD(DAY, ((2 - DATEPART(dw, DATEFROMPARTS(Y, 10, 1)) + 7) % 7) + 7, DATEFROMPARTS(Y, 10, 1))
    FROM Years

    UNION ALL

    -- Thanksgiving Day (4th Thursday of November)
    SELECT
        Y,
        N'Thanksgiving Day',
        DATEADD(DAY, ((5 - DATEPART(dw, DATEFROMPARTS(Y, 11, 1)) + 7) % 7) + 21, DATEFROMPARTS(Y, 11, 1)),
        DATEADD(DAY, ((5 - DATEPART(dw, DATEFROMPARTS(Y, 11, 1)) + 7) % 7) + 21, DATEFROMPARTS(Y, 11, 1))
    FROM Years

    UNION ALL

    -- Day After Thanksgiving (4th Thursday of November + 1)
    SELECT
        Y,
        N'Day After Thanksgiving',
        DATEADD(DAY, ((5 - DATEPART(dw, DATEFROMPARTS(Y, 11, 1)) + 7) % 7) + 22, DATEFROMPARTS(Y, 11, 1)),
        DATEADD(DAY, ((5 - DATEPART(dw, DATEFROMPARTS(Y, 11, 1)) + 7) % 7) + 22, DATEFROMPARTS(Y, 11, 1))
    FROM Years
)
INSERT INTO Reference.DateHoliday
(
    HolidayYear,
    HolidayName,
    HolidayDate,
    ObservedDate,
    IsObservedDifferent
)
SELECT
    HolidayYear,
    HolidayName,
    HolidayDate,
    ObservedDate,
    CASE WHEN HolidayDate <> ObservedDate THEN 1 ELSE 0 END
FROM Holidays
ORDER BY HolidayYear, HolidayDate
OPTION (MAXRECURSION 200);

-- ============================================================
-- Stamp holiday flags back onto Reference.[Date]
-- Same logic lives in Update_Date_Dimension_Holiday_Flags.sql —
-- run that script any time IsObserved or ObservedDate is changed
-- on individual rows without a full reload.
-- ============================================================
IF OBJECT_ID('Reference.[Date]', 'U') IS NOT NULL
BEGIN
    -- Reset all holiday flags first (supports re-runs)
    UPDATE Reference.[Date]
    SET    IsHoliday    = 0,
           HolidayName  = NULL,
           IsBusinessDay = CASE WHEN DayOfWeek IN (1, 7) THEN 0 ELSE 1 END;

    -- Apply observed holidays: mark as holiday and clear IsBusinessDay
    UPDATE d
    SET    d.IsHoliday    = 1,
           d.HolidayName  = h.HolidayName,
           d.IsBusinessDay = 0
    FROM   Reference.[Date]        d
    JOIN   Reference.DateHoliday   h ON d.[Date] = h.ObservedDate
    WHERE  h.IsObserved = 1;
END
