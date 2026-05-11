
USE master;
GO

-- Datenbank nur erstellen wenn sie noch nicht existiert
IF NOT EXISTS (
    SELECT name FROM sys.databases WHERE name = N'OnboardingDB'
)
BEGIN
    CREATE DATABASE OnboardingDB
    COLLATE Latin1_General_CI_AS;

    PRINT 'Datenbank OnboardingDB wurde erfolgreich erstellt.';
END
ELSE
BEGIN
    PRINT 'Datenbank OnboardingDB existiert bereits.';
END
GO

USE OnboardingDB;
GO
