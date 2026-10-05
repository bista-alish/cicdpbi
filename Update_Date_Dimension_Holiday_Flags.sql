-- ============================================================
-- Update_Date_Dimension_Holiday_Flags.sql
--
-- Re-syncs IsHoliday, HolidayName, and IsBusinessDay on
-- Reference.[Date] from the current state of Reference.DateHoliday.
--
-- Run this whenever IsObserved or ObservedDate is changed on
-- individual rows in Reference.DateHoliday so that Reference.[Date]
-- stays consistent without needing a full reload.
--
-- Prerequisites:
--   Reference.[Date]       populated by Create_Date_Dimension.sql
--   Reference.DateHoliday  populated by Create_Date_Dimension_Holidays.sql
-- ============================================================

SET DATEFIRST 7;    -- 1=Sunday, 7=Saturday  (must match Create_Date_Dimension.sql)
SET NOCOUNT ON;

-- Step 1: Reset all holiday flags to their weekend-only baseline
UPDATE Reference.[Date]
SET    IsHoliday     = 0,
       HolidayName   = NULL,
       IsBusinessDay = CASE WHEN DayOfWeek IN (1, 7) THEN 0 ELSE 1 END;

-- Step 2: Apply observed holidays (IsObserved = 1 only)
UPDATE d
SET    d.IsHoliday    = 1,
       d.HolidayName  = h.HolidayName,
       d.IsBusinessDay = 0
FROM   Reference.[Date]       d
JOIN   Reference.DateHoliday  h ON d.[Date] = h.ObservedDate
WHERE  h.IsObserved = 1;
