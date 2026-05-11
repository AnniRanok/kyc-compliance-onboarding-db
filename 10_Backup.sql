
USE master;
GO

-- Vollsicherung der Datenbank als .bak-Datei

BACKUP DATABASE OnboardingDB
TO DISK = 'C:\Backups\OnboardingDB.bak'
WITH
    FORMAT,                              -- überschreibt vorhandene Sicherung
    INIT,                                -- neues Sicherungsset
    NAME    = N'OnboardingDB – Vollsicherung',
    STATS   = 10;                        -- Fortschritt alle 10%
GO

PRINT 'Backup erfolgreich erstellt: C:\Backups\OnboardingDB.bak';
GO


-- Optional: Sicherung mit Datum im Dateinamen
-- (nützlich für automatische tägliche Sicherungen)

/*
DECLARE @backupPath NVARCHAR(500);
SET @backupPath = 'C:\Backups\OnboardingDB_'
    + CONVERT(NVARCHAR(8), GETDATE(), 112)  -- YYYYMMDD
    + '.bak';

BACKUP DATABASE OnboardingDB
TO DISK = @backupPath
WITH FORMAT, INIT, NAME = N'OnboardingDB – Tagessicherung', STATS = 10;
*/


-- Wiederherstellung

/*
USE master;

-- Bestehende Verbindungen trennen
ALTER DATABASE OnboardingDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE OnboardingDB
FROM DISK = 'C:\Backups\OnboardingDB.bak'
WITH REPLACE, STATS = 10;

ALTER DATABASE OnboardingDB SET MULTI_USER;
*/
