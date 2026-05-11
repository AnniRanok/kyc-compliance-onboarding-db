
USE OnboardingDB;
GO


-- SKALARFUNKTION 1: fn_IsUBOReportable
-- Gibt 1 (true) zurück wenn OwnershipPercentage >= 25%
-- Wird in der Prozedur usp_SubmitDocument verwendet.

IF OBJECT_ID('dbo.fn_IsUBOReportable', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_IsUBOReportable;
GO

CREATE FUNCTION dbo.fn_IsUBOReportable
(
    @ownershipPct DECIMAL(5,2)
)
RETURNS BIT
AS
BEGIN
    DECLARE @result BIT = 0;

    -- Meldepflicht ab 25% Beteiligungsanteil
    IF @ownershipPct >= 25.00
        SET @result = 1;

    RETURN @result;
END;
GO

PRINT 'Funktion fn_IsUBOReportable erstellt.';
GO


-- SKALARFUNKTION 2: fn_GetCaseStatusLabel
-- Gibt eine lesbare deutsche Bezeichnung für den Status zurück.
-- Wird in der Prozedur für Fehlermeldungen verwendet.

IF OBJECT_ID('dbo.fn_GetCaseStatusLabel', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_GetCaseStatusLabel;
GO

CREATE FUNCTION dbo.fn_GetCaseStatusLabel
(
    @status NVARCHAR(50)
)
RETURNS NVARCHAR(100)
AS
BEGIN
    DECLARE @label NVARCHAR(100);

    SET @label = CASE @status
        WHEN 'Open'     THEN N'Offen – wartet auf Dokumente'
        WHEN 'InReview' THEN N'In Prüfung'
        WHEN 'Approved' THEN N'Genehmigt'
        WHEN 'Rejected' THEN N'Abgelehnt'
        WHEN 'Closed'   THEN N'Geschlossen'
        ELSE N'Unbekannter Status'
    END;

    RETURN @label;
END;
GO

PRINT 'Funktion fn_GetCaseStatusLabel erstellt.';
GO


-- SKALARFUNKTION 3: fn_CountMissingMandatoryDocs
-- Zählt Pflichtdokumente, die für einen Case noch fehlen
-- (nicht eingereicht oder abgelehnt).
-- Wird in der Prozedur für den Status-Wechsel verwendet.

IF OBJECT_ID('dbo.fn_CountMissingMandatoryDocs', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_CountMissingMandatoryDocs;
GO

CREATE FUNCTION dbo.fn_CountMissingMandatoryDocs
(
    @caseID INT
)
RETURNS INT
AS
BEGIN
    DECLARE @missing INT;

    -- Pflichtdokumente auf Company-Ebene die noch nicht verifiziert sind
    SELECT @missing = COUNT(*)
    FROM dbo.RequiredDocuments rd
    INNER JOIN dbo.Company        c   ON c.LegalFormID = rd.LegalFormID
    INNER JOIN dbo.OnboardingCase oc  ON oc.CompanyID  = c.CompanyID
    WHERE oc.CaseID      = @caseID
      AND rd.IsMandatory  = 1
      AND rd.AppliesToUBO = 0
      AND NOT EXISTS (
            SELECT 1
            FROM dbo.SubmittedDocuments sd
            WHERE sd.CaseID         = @caseID
              AND sd.DocumentTypeID  = rd.DocumentTypeID
              AND sd.DocumentStatus <> 'Rejected'
          );

    RETURN ISNULL(@missing, 0);
END;
GO

PRINT 'Funktion fn_CountMissingMandatoryDocs erstellt.';
GO


-- TABELLENWERTFUNKTION: fn_GetUBOsByCompany
-- Gibt alle aktiven UBOs einer Company zurück,
-- inkl. Beteiligungsdetails und Meldepflicht-Flag.

IF OBJECT_ID('dbo.fn_GetUBOsByCompany', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_GetUBOsByCompany;
GO

CREATE FUNCTION dbo.fn_GetUBOsByCompany
(
    @companyID INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        u.UBOID,
        u.FirstName,
        u.LastName,
        u.FirstName + ' ' + u.LastName       AS FullName,
        u.DateOfBirth,
        u.Nationality,
        o.OwnershipPercentage,
        o.OwnershipType,
        o.ValidFrom,
        o.ValidTo,
        -- Wiederverwendung der Skalarfunktion
        dbo.fn_IsUBOReportable(o.OwnershipPercentage) AS IsReportable
    FROM dbo.UBO       u
    INNER JOIN dbo.Ownership o ON u.UBOID = o.UBOID
    WHERE o.CompanyID = @companyID
      AND (o.ValidTo IS NULL OR o.ValidTo >= GETDATE())
);
GO

PRINT 'Tabellenwertfunktion fn_GetUBOsByCompany erstellt.';
GO
