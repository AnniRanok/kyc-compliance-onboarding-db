
USE OnboardingDB;
GO


-- VIEW 1: vw_OnboardingOverview
-- Typ:    INNER JOIN über 4 Tabellen
-- Zweck:  Übersicht aller Cases mit Company- und Länderdaten

IF OBJECT_ID('dbo.vw_OnboardingOverview', 'V') IS NOT NULL
    DROP VIEW dbo.vw_OnboardingOverview;
GO

CREATE VIEW dbo.vw_OnboardingOverview AS
SELECT
    oc.CaseID,
    oc.CaseOpenDate,
    oc.CaseStatus,
    c.CompanyID,
    c.CompanyName,
    c.RegistrationNumber,
    c.EmployeeCount,
    c.AnnualRevenue,
    lf.LegalFormName,
    lf.LegalFormCode,
    co.CountryName,
    co.CountryCode,
    co.RegionName
FROM dbo.OnboardingCase        oc
INNER JOIN dbo.Company         c   ON oc.CompanyID  = c.CompanyID
INNER JOIN dbo.LegalForm       lf  ON c.LegalFormID = lf.LegalFormID
INNER JOIN dbo.Country         co  ON lf.CountryID  = co.CountryID;
GO

PRINT 'View vw_OnboardingOverview erstellt.';
GO


-- VIEW 2: vw_DocumentCompletionStats
-- Typ:    GROUP BY + COUNT + SUM + HAVING
-- Zweck:  Dokumentenstatus pro Case – nur Cases mit mind. 1 Dok.

IF OBJECT_ID('dbo.vw_DocumentCompletionStats', 'V') IS NOT NULL
    DROP VIEW dbo.vw_DocumentCompletionStats;
GO

CREATE VIEW dbo.vw_DocumentCompletionStats AS
SELECT
    oc.CaseID,
    c.CompanyName,
    oc.CaseStatus,
    COUNT(sd.SubmittedDocumentID)                               AS TotalDocuments,
    SUM(CASE WHEN sd.DocumentStatus = 'Verified'  THEN 1 ELSE 0 END) AS VerifiedDocuments,
    SUM(CASE WHEN sd.DocumentStatus = 'Pending'   THEN 1 ELSE 0 END) AS PendingDocuments,
    SUM(CASE WHEN sd.DocumentStatus = 'Rejected'  THEN 1 ELSE 0 END) AS RejectedDocuments
FROM dbo.OnboardingCase           oc
INNER JOIN dbo.Company            c   ON oc.CompanyID = c.CompanyID
INNER JOIN dbo.SubmittedDocuments sd  ON oc.CaseID    = sd.CaseID
GROUP BY
    oc.CaseID,
    c.CompanyName,
    oc.CaseStatus
HAVING
    COUNT(sd.SubmittedDocumentID) >= 1;
GO

PRINT 'View vw_DocumentCompletionStats erstellt.';
GO


-- VIEW 3: vw_CompanyWithUBO
-- Typ:    LEFT OUTER JOIN (für Note "sehr gut")
-- Zweck:  Alle Companies MIT oder OHNE UBOs anzeigen.
--         Companies ohne Ownership erscheinen mit NULL-Werten.
--         Flag IsBeneficialOwner wenn Anteil >= 25%.

IF OBJECT_ID('dbo.vw_CompanyWithUBO', 'V') IS NOT NULL
    DROP VIEW dbo.vw_CompanyWithUBO;
GO

CREATE VIEW dbo.vw_CompanyWithUBO AS
SELECT
    c.CompanyID,
    c.CompanyName,
    lf.LegalFormName,
    co.CountryName,
    u.UBOID,
    u.FirstName + ' ' + u.LastName          AS UBOFullName,
    u.Nationality                            AS UBONationality,
    o.OwnershipPercentage,
    o.OwnershipType,
    o.ValidFrom,
    o.ValidTo,
    -- Meldepflichtig wenn Anteil >= 25%
    CASE
        WHEN o.OwnershipPercentage >= 25 THEN 'Ja'
        WHEN o.OwnershipPercentage IS NULL THEN 'Kein UBO'
        ELSE 'Nein'
    END                                      AS IsBeneficialOwner
FROM dbo.Company               c
INNER JOIN dbo.LegalForm       lf ON c.LegalFormID = lf.LegalFormID
INNER JOIN dbo.Country         co ON lf.CountryID  = co.CountryID
LEFT JOIN  dbo.Ownership       o  ON c.CompanyID   = o.CompanyID
LEFT JOIN  dbo.UBO             u  ON o.UBOID       = u.UBOID;
GO

PRINT 'View vw_CompanyWithUBO (LEFT JOIN) erstellt.';
GO
