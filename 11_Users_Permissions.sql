
-- SCHRITT 1: Logins auf Server-Ebene erstellen

USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'OnboardingReader')
    CREATE LOGIN OnboardingReader WITH PASSWORD = 'Read@1234!';
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'OnboardingWriter')
    CREATE LOGIN OnboardingWriter WITH PASSWORD = 'Write@1234!';
GO


-- SCHRITT 2: Benutzer auf Datenbankebene erstellen

USE OnboardingDB;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'OnboardingReader')
    CREATE USER OnboardingReader FOR LOGIN OnboardingReader;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'OnboardingWriter')
    CREATE USER OnboardingWriter FOR LOGIN OnboardingWriter;
GO


-- SCHRITT 3: Rollen erstellen
-- Best Practice: Rechte werden Rollen zugewiesen,
-- nicht direkt den Benutzern.

IF NOT EXISTS (SELECT 1 FROM sys.database_principals
               WHERE name = 'OnboardingReaderRole' AND type = 'R')
    CREATE ROLE OnboardingReaderRole;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals
               WHERE name = 'OnboardingWriterRole' AND type = 'R')
    CREATE ROLE OnboardingWriterRole;
GO


-- SCHRITT 4: Rechte den Rollen zuweisen

GRANT SELECT ON SCHEMA::dbo TO OnboardingReaderRole;
GO

GRANT SELECT ON SCHEMA::dbo TO OnboardingWriterRole;
GRANT INSERT ON SCHEMA::dbo TO OnboardingWriterRole;
GRANT UPDATE ON SCHEMA::dbo TO OnboardingWriterRole;
GRANT EXECUTE ON dbo.usp_SubmitDocument   TO OnboardingWriterRole;
GRANT EXECUTE ON dbo.usp_UpdateCaseStatus TO OnboardingWriterRole;
GO


-- SCHRITT 5: Benutzer den Rollen zuweisen

ALTER ROLE OnboardingReaderRole ADD MEMBER OnboardingReader;
GO

ALTER ROLE OnboardingWriterRole ADD MEMBER OnboardingWriter;
GO

-- Kontrolle: Benutzer und Rollen anzeigen

SELECT
    dp.name                 AS Benutzer_oder_Rolle,
    dp.type_desc            AS Typ,
    ISNULL(sl.name, '-')    AS Login,
    ISNULL(rm.role_name,'-') AS Mitglied_von_Rolle
FROM sys.database_principals dp
LEFT JOIN sys.server_principals sl ON dp.sid = sl.sid
LEFT JOIN (
    SELECT m.name AS member_name, r.name AS role_name
    FROM sys.database_role_members drm
    INNER JOIN sys.database_principals m ON drm.member_principal_id = m.principal_id
    INNER JOIN sys.database_principals r ON drm.role_principal_id   = r.principal_id
) rm ON dp.name = rm.member_name
WHERE dp.type IN ('S','U','R')
  AND dp.name NOT IN ('dbo','guest','INFORMATION_SCHEMA','sys',
                      'db_owner','db_accessadmin','db_securityadmin',
                      'db_ddladmin','db_backupoperator','db_datareader',
                      'db_datawriter','db_denydatareader','db_denydatawriter','public')
ORDER BY dp.type_desc, dp.name;
GO
