
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

--------------------------------------------------------

USE OnboardingDB;
GO


-- 1. Country
-- Referenztabelle aller Länder.
-- Wird von LegalForm, CompanyAddress und RequiredDocuments
-- verwendet. Hat keine FK-Abhängigkeiten.

IF OBJECT_ID('dbo.Country', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Country (
        CountryID   INT            NOT NULL IDENTITY(1,1),
        CountryCode CHAR(2)        NOT NULL,
        CountryName NVARCHAR(100)  NOT NULL,
        RegionName  NVARCHAR(100)  NULL,

        CONSTRAINT PK_Country      PRIMARY KEY CLUSTERED (CountryID),
        CONSTRAINT UQ_Country_Code UNIQUE (CountryCode)
    );
    PRINT 'Tabelle Country erstellt.';
END
GO


-- 2. LegalForm
-- Rechtsformen pro Land (GmbH, AG, BV, SA usw.)
-- Wird von Company und RequiredDocuments referenziert.

IF OBJECT_ID('dbo.LegalForm', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.LegalForm (
        LegalFormID   INT           NOT NULL IDENTITY(1,1),
        CountryID     INT           NOT NULL,
        LegalFormCode NVARCHAR(20)  NOT NULL,
        LegalFormName NVARCHAR(100) NOT NULL,

        CONSTRAINT PK_LegalForm PRIMARY KEY CLUSTERED (LegalFormID)
    );
    PRINT 'Tabelle LegalForm erstellt.';
END
GO


-- 3. Company
-- Zentrale Entität. Speichert Stammdaten des Unternehmens.
-- Referenziert LegalForm.

IF OBJECT_ID('dbo.Company', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Company (
        CompanyID          INT            NOT NULL IDENTITY(1,1),
        LegalFormID        INT            NOT NULL,
        CompanyName        NVARCHAR(200)  NOT NULL,
        RegistrationNumber NVARCHAR(50)   NULL,
        FoundationDate     DATE           NULL,
        IndustryCode       NVARCHAR(20)   NULL,
        EmployeeCount      INT            NULL     DEFAULT 0,
        AnnualRevenue      DECIMAL(18,2)  NULL     DEFAULT 0.00,
        RegistrationDate   DATE           NOT NULL  DEFAULT GETDATE(),

        CONSTRAINT PK_Company PRIMARY KEY CLUSTERED (CompanyID)
    );
    PRINT 'Tabelle Company erstellt.';
END
GO


-- 4. CompanyAddress
-- Adressen eines Unternehmens.
-- AddressType: 'Registered' = juristische Adresse,
--              'Physical'   = tatsächlicher Standort

IF OBJECT_ID('dbo.CompanyAddress', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CompanyAddress (
        CompanyAddressID INT            NOT NULL IDENTITY(1,1),
        CompanyID        INT            NOT NULL,
        CountryID        INT            NOT NULL,
        AddressType      NVARCHAR(20)   NOT NULL DEFAULT 'Registered',
        StreetAddress    NVARCHAR(255)  NULL,
        PostalCode       NVARCHAR(20)   NULL,
        City             NVARCHAR(100)  NULL,
        IsPrimary        BIT            NOT NULL DEFAULT 0,

        CONSTRAINT PK_CompanyAddress PRIMARY KEY CLUSTERED (CompanyAddressID)
    );
    PRINT 'Tabelle CompanyAddress erstellt.';
END
GO


-- 5. UBO (Ultimate Beneficial Owner)
-- Natürliche Personen als wirtschaftlich Berechtigte.
-- PassportNo: eindeutige Reisepassnummer (UNIQUE Constraint).
-- Keine FK-Abhängigkeiten – unabhängige Entität.

IF OBJECT_ID('dbo.UBO', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.UBO (
        UBOID       INT            NOT NULL IDENTITY(1,1),
        FirstName   NVARCHAR(100)  NOT NULL,
        LastName    NVARCHAR(100)  NOT NULL,
        DateOfBirth DATE           NULL,
        Nationality CHAR(2)        NULL,
        PassportNo  NVARCHAR(50)   NULL,

        CONSTRAINT PK_UBO             PRIMARY KEY CLUSTERED (UBOID),
        CONSTRAINT UQ_UBO_PassportNo  UNIQUE (PassportNo)
    );
    PRINT 'Tabelle UBO erstellt.';
END
GO


-- 6. Ownership  ← m:n Beziehung Company <-> UBO
-- Beteiligungsanteile und Art der Beteiligung.
-- IsOwnershipDirect: 1 = direkte, 0 = indirekte Beteiligung.
-- Ab 25% Anteil gilt ein UBO als meldepflichtig.

IF OBJECT_ID('dbo.Ownership', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Ownership (
        OwnershipID         INT           NOT NULL IDENTITY(1,1),
        CompanyID           INT           NOT NULL,
        UBOID               INT           NOT NULL,
        OwnershipPercentage DECIMAL(5,2)  NOT NULL DEFAULT 0,
        IsOwnershipDirect   BIT           NOT NULL DEFAULT 1,
        ValidFrom           DATE          NULL,
        ValidTo             DATE          NULL,

        CONSTRAINT PK_Ownership PRIMARY KEY CLUSTERED (OwnershipID)
    );
    PRINT 'Tabelle Ownership erstellt.';
END
GO


-- 7. DocumentType
-- Katalog aller Dokumentarten.
-- DocumentScope: 'Company' = Firmendokument,
--                'UBO'     = Personendokument

IF OBJECT_ID('dbo.DocumentType', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DocumentType (
        DocumentTypeID   INT           NOT NULL IDENTITY(1,1),
        DocumentTypeName NVARCHAR(100) NOT NULL,
        DocumentScope    NVARCHAR(20)  NOT NULL DEFAULT 'Company',

        CONSTRAINT PK_DocumentType PRIMARY KEY CLUSTERED (DocumentTypeID)
    );
    PRINT 'Tabelle DocumentType erstellt.';
END
GO


-- 8. RequiredDocuments
-- Pflichtdokumente pro Rechtsform und Dokumenttyp.
-- Definiert welche Dokumente für welche Rechtsform
-- eingereicht werden müssen.

IF OBJECT_ID('dbo.RequiredDocuments', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.RequiredDocuments (
        RequiredDocumentID INT          NOT NULL IDENTITY(1,1),
        LegalFormID        INT          NOT NULL,
        DocumentTypeID     INT          NOT NULL,
        RequirementLevel   NVARCHAR(50) NULL     DEFAULT 'Standard',
        AppliesToUBO       BIT          NOT NULL DEFAULT 0,
        IsMandatory        BIT          NOT NULL DEFAULT 1,

        CONSTRAINT PK_RequiredDocuments PRIMARY KEY CLUSTERED (RequiredDocumentID)
    );
    PRINT 'Tabelle RequiredDocuments erstellt.';
END
GO


-- 9. OnboardingCase
-- Operativer Onboarding-Prozess eines Unternehmens.
-- CaseStatus: Open → InReview → Approved/Rejected → Closed

IF OBJECT_ID('dbo.OnboardingCase', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.OnboardingCase (
        CaseID       INT          NOT NULL IDENTITY(1,1),
        CompanyID    INT          NOT NULL,
        CaseOpenDate DATE         NOT NULL DEFAULT GETDATE(),
        CaseStatus   NVARCHAR(50) NOT NULL DEFAULT 'Open',

        CONSTRAINT PK_OnboardingCase PRIMARY KEY CLUSTERED (CaseID)
    );
    PRINT 'Tabelle OnboardingCase erstellt.';
END
GO


-- 10. SubmittedDocuments
-- Tatsächlich eingereichte Dokumente pro Case.
-- UBOID ist NULL bei Firmendokumenten.
-- DocumentStatus: Pending → Verified / Rejected

IF OBJECT_ID('dbo.SubmittedDocuments', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SubmittedDocuments (
        SubmittedDocumentID INT          NOT NULL IDENTITY(1,1),
        CaseID              INT          NOT NULL,
        UBOID               INT          NULL,
        DocumentTypeID      INT          NOT NULL,
        SubmissionDate      DATE         NOT NULL DEFAULT GETDATE(),
        DocumentStatus      NVARCHAR(50) NOT NULL DEFAULT 'Pending',
        VerificationDate    DATE         NULL,

        CONSTRAINT PK_SubmittedDocuments PRIMARY KEY CLUSTERED (SubmittedDocumentID)
    );
    PRINT 'Tabelle SubmittedDocuments erstellt.';
END
GO


-- 11. ExternalSource
-- Katalog externer Prüfquellen.
-- Beispiele: Creditreform, Handelsregister, KvK, Firmenbuch

IF OBJECT_ID('dbo.ExternalSource', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ExternalSource (
        ExternalSourceID INT           NOT NULL IDENTITY(1,1),
        SourceName       NVARCHAR(100) NOT NULL,
        SourceCountry    CHAR(2)       NULL,
        SourceType       NVARCHAR(50)  NULL,

        CONSTRAINT PK_ExternalSource PRIMARY KEY CLUSTERED (ExternalSourceID)
    );
    PRINT 'Tabelle ExternalSource erstellt.';
END
GO


-- 12. ExternalVerificationCheck
-- Externe Prüfungen pro Case.
-- CheckStatus: Pending → Passed / Failed / Manual

IF OBJECT_ID('dbo.ExternalVerificationCheck', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ExternalVerificationCheck (
        ExternalCheckID  INT            NOT NULL IDENTITY(1,1),
        CaseID           INT            NOT NULL,
        ExternalSourceID INT            NOT NULL,
        CheckDate        DATE           NOT NULL DEFAULT GETDATE(),
        CheckStatus      NVARCHAR(50)   NOT NULL DEFAULT 'Pending',
        ResultSummary    NVARCHAR(MAX)  NULL,

        CONSTRAINT PK_ExternalVerificationCheck
            PRIMARY KEY CLUSTERED (ExternalCheckID)
    );
    PRINT 'Tabelle ExternalVerificationCheck erstellt.';
END
GO

PRINT 'Alle 12 Tabellen erfolgreich erstellt.';
GO

----------------------------------------------------------------

USE OnboardingDB;
GO


--  NONCLUSTERED INDEXES 


-- Company: Index auf CompanyName (häufige Suchspalte)
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_Company_CompanyName'
      AND object_id = OBJECT_ID('dbo.Company')
)
    CREATE NONCLUSTERED INDEX IX_Company_CompanyName
        ON dbo.Company (CompanyName);
GO

-- Company: Index auf RegistrationNumber
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_Company_RegistrationNumber'
      AND object_id = OBJECT_ID('dbo.Company')
)
    CREATE NONCLUSTERED INDEX IX_Company_RegistrationNumber
        ON dbo.Company (RegistrationNumber);
GO

-- UBO: Index auf LastName für schnelle Personensuche
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_UBO_LastName'
      AND object_id = OBJECT_ID('dbo.UBO')
)
    CREATE NONCLUSTERED INDEX IX_UBO_LastName
        ON dbo.UBO (LastName);
GO

-- OnboardingCase: Index auf CaseStatus (häufig gefiltert)
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_OnboardingCase_Status'
      AND object_id = OBJECT_ID('dbo.OnboardingCase')
)
    CREATE NONCLUSTERED INDEX IX_OnboardingCase_Status
        ON dbo.OnboardingCase (CaseStatus);
GO

-- SubmittedDocuments: Index auf CaseID + DocumentStatus
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_SubmittedDocuments_CaseStatus'
      AND object_id = OBJECT_ID('dbo.SubmittedDocuments')
)
    CREATE NONCLUSTERED INDEX IX_SubmittedDocuments_CaseStatus
        ON dbo.SubmittedDocuments (CaseID, DocumentStatus);
GO

-- Ownership: Index auf CompanyID für UBO-Abfragen
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_Ownership_CompanyID'
      AND object_id = OBJECT_ID('dbo.Ownership')
)
    CREATE NONCLUSTERED INDEX IX_Ownership_CompanyID
        ON dbo.Ownership (CompanyID);
GO


--  CHECK-CONSTRAINTS 


-- Company: EmployeeCount darf nicht negativ sein
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = 'CHK_Company_EmployeeCount'
)
    ALTER TABLE dbo.Company
        ADD CONSTRAINT CHK_Company_EmployeeCount
        CHECK (EmployeeCount >= 0);
GO

-- Company: AnnualRevenue darf nicht negativ sein
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = 'CHK_Company_AnnualRevenue'
)
    ALTER TABLE dbo.Company
        ADD CONSTRAINT CHK_Company_AnnualRevenue
        CHECK (AnnualRevenue >= 0);
GO

-- CompanyAddress: nur erlaubte Adresstypen
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = 'CHK_CompanyAddress_Type'
)
    ALTER TABLE dbo.CompanyAddress
        ADD CONSTRAINT CHK_CompanyAddress_Type
        CHECK (AddressType IN ('Registered', 'Physical'));
GO

-- Ownership: Beteiligungsanteil zwischen 0 und 100%
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = 'CHK_Ownership_Percentage'
)
    ALTER TABLE dbo.Ownership
        ADD CONSTRAINT CHK_Ownership_Percentage
        CHECK (OwnershipPercentage BETWEEN 0 AND 100);
GO

-- DocumentType: nur erlaubte Scope-Werte
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = 'CHK_DocumentType_Scope'
)
    ALTER TABLE dbo.DocumentType
        ADD CONSTRAINT CHK_DocumentType_Scope
        CHECK (DocumentScope IN ('Company', 'UBO'));
GO

-- OnboardingCase: nur erlaubte Status-Werte
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = 'CHK_OnboardingCase_Status'
)
    ALTER TABLE dbo.OnboardingCase
        ADD CONSTRAINT CHK_OnboardingCase_Status
        CHECK (CaseStatus IN ('Open', 'InReview', 'Approved', 'Rejected', 'Closed'));
GO

-- SubmittedDocuments: nur erlaubte Dokumentstatus-Werte
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = 'CHK_SubmittedDocs_Status'
)
    ALTER TABLE dbo.SubmittedDocuments
        ADD CONSTRAINT CHK_SubmittedDocs_Status
        CHECK (DocumentStatus IN ('Pending', 'Verified', 'Rejected'));
GO

-- ExternalVerificationCheck: nur erlaubte Status-Werte
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = 'CHK_ExternalCheck_Status'
)
    ALTER TABLE dbo.ExternalVerificationCheck
        ADD CONSTRAINT CHK_ExternalCheck_Status
        CHECK (CheckStatus IN ('Pending', 'Passed', 'Failed', 'Manual'));
GO

PRINT 'Alle Indexes und CHECK-Constraints erfolgreich erstellt.';
GO

------------------------------------------------------------------

USE OnboardingDB;
GO


-- LegalForm → Country

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_LegalForm_Country'
)
    ALTER TABLE dbo.LegalForm
        ADD CONSTRAINT FK_LegalForm_Country
        FOREIGN KEY (CountryID) REFERENCES dbo.Country(CountryID);
GO


-- Company → LegalForm

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Company_LegalForm'
)
    ALTER TABLE dbo.Company
        ADD CONSTRAINT FK_Company_LegalForm
        FOREIGN KEY (LegalFormID) REFERENCES dbo.LegalForm(LegalFormID);
GO


-- CompanyAddress → Company

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CompanyAddress_Company'
)
    ALTER TABLE dbo.CompanyAddress
        ADD CONSTRAINT FK_CompanyAddress_Company
        FOREIGN KEY (CompanyID) REFERENCES dbo.Company(CompanyID);
GO

-- CompanyAddress → Country
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CompanyAddress_Country'
)
    ALTER TABLE dbo.CompanyAddress
        ADD CONSTRAINT FK_CompanyAddress_Country
        FOREIGN KEY (CountryID) REFERENCES dbo.Country(CountryID);
GO


-- Ownership → Company  (m:n Beziehung – linke Seite)
-- Ownership → UBO      (m:n Beziehung – rechte Seite)

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Ownership_Company'
)
    ALTER TABLE dbo.Ownership
        ADD CONSTRAINT FK_Ownership_Company
        FOREIGN KEY (CompanyID) REFERENCES dbo.Company(CompanyID);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Ownership_UBO'
)
    ALTER TABLE dbo.Ownership
        ADD CONSTRAINT FK_Ownership_UBO
        FOREIGN KEY (UBOID) REFERENCES dbo.UBO(UBOID);
GO


-- RequiredDocuments → LegalForm
-- RequiredDocuments → DocumentType

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ReqDocs_LegalForm'
)
    ALTER TABLE dbo.RequiredDocuments
        ADD CONSTRAINT FK_ReqDocs_LegalForm
        FOREIGN KEY (LegalFormID) REFERENCES dbo.LegalForm(LegalFormID);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ReqDocs_DocType'
)
    ALTER TABLE dbo.RequiredDocuments
        ADD CONSTRAINT FK_ReqDocs_DocType
        FOREIGN KEY (DocumentTypeID) REFERENCES dbo.DocumentType(DocumentTypeID);
GO


-- OnboardingCase → Company

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_OnboardingCase_Company'
)
    ALTER TABLE dbo.OnboardingCase
        ADD CONSTRAINT FK_OnboardingCase_Company
        FOREIGN KEY (CompanyID) REFERENCES dbo.Company(CompanyID);
GO


-- SubmittedDocuments → OnboardingCase
-- SubmittedDocuments → UBO (optional, nullable)
-- SubmittedDocuments → DocumentType

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_SubmittedDocs_Case'
)
    ALTER TABLE dbo.SubmittedDocuments
        ADD CONSTRAINT FK_SubmittedDocs_Case
        FOREIGN KEY (CaseID) REFERENCES dbo.OnboardingCase(CaseID);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_SubmittedDocs_UBO'
)
    ALTER TABLE dbo.SubmittedDocuments
        ADD CONSTRAINT FK_SubmittedDocs_UBO
        FOREIGN KEY (UBOID) REFERENCES dbo.UBO(UBOID);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_SubmittedDocs_DocType'
)
    ALTER TABLE dbo.SubmittedDocuments
        ADD CONSTRAINT FK_SubmittedDocs_DocType
        FOREIGN KEY (DocumentTypeID) REFERENCES dbo.DocumentType(DocumentTypeID);
GO


-- ExternalVerificationCheck → OnboardingCase
-- ExternalVerificationCheck → ExternalSource

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ExtCheck_Case'
)
    ALTER TABLE dbo.ExternalVerificationCheck
        ADD CONSTRAINT FK_ExtCheck_Case
        FOREIGN KEY (CaseID) REFERENCES dbo.OnboardingCase(CaseID);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ExtCheck_Source'
)
    ALTER TABLE dbo.ExternalVerificationCheck
        ADD CONSTRAINT FK_ExtCheck_Source
        FOREIGN KEY (ExternalSourceID)
        REFERENCES dbo.ExternalSource(ExternalSourceID);
GO

PRINT 'Alle Foreign Key Constraints erfolgreich erstellt.';
GO

-------------------------------------------------------------------

USE OnboardingDB;
GO


-- VIEW 1: vw_OnboardingOverview
-- Typ:    INNER JOIN über 4 Tabellen

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

-- DATEI:   06_Functions.sql
-- PROJEKT: Onboarding Database
-- ZWECK:   Gespeicherte Funktionen erstellen
--          - 3 Skalarwertfunktionen
--          - 1 Tabellenwertfunktion


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

--------------------------------------------------------------------


USE OnboardingDB;
GO


-- PROZEDUR: usp_SubmitDocument
-- Zweck:    Dokument für einen Onboarding-Case einreichen.
--
-- Business-Logik (Reihenfolge der Prüfungen):
--   1. CaseID existiert und hat erlaubten Status
--   2. DocumentTypeID existiert
--   3. Dokument wurde noch nicht aktiv eingereicht (kein Duplikat)
--   4. Bei UBO-Dokument: UBO muss meldepflichtig sein (>= 25%)
--   5. Dokument einfügen
--   6. Alle Pflichtdokumente vorhanden? → Status → 'InReview'
--
-- Eingangsparameter:
--   @caseID         INT           – Case-ID des Onboarding-Falls
--   @documentTypeID INT           – Art des einzureichenden Dokuments
--   @uboID          INT (optional)– NULL für Company-Dokumente
--
-- Ausgabeparameter:
--   @errorMessage   NVARCHAR(500) – 'OK' oder Fehlerbeschreibung
--   @newDocumentID  INT           – ID des neuen Eintrags (0 bei Fehler)

IF OBJECT_ID('dbo.usp_SubmitDocument', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_SubmitDocument;
GO

CREATE PROCEDURE dbo.usp_SubmitDocument
    @caseID         INT,
    @documentTypeID INT,
    @uboID          INT           = NULL,
    @errorMessage   NVARCHAR(500) = N'' OUTPUT,
    @newDocumentID  INT           = 0   OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Ausgabeparameter initialisieren
    SET @errorMessage  = N'OK';
    SET @newDocumentID = 0;

 
    -- 1. CaseID prüfen – existiert und hat erlaubten Status?

    DECLARE @caseStatus NVARCHAR(50);

    SELECT @caseStatus = CaseStatus
    FROM dbo.OnboardingCase
    WHERE CaseID = @caseID;

    IF @caseStatus IS NULL
    BEGIN
        SET @errorMessage = N'Fehler: CaseID '
            + CAST(@caseID AS NVARCHAR)
            + N' existiert nicht.';
        RETURN;
    END;

    -- Dokumente nur bei offenem oder laufendem Case erlaubt
    IF @caseStatus NOT IN ('Open', 'InReview')
    BEGIN
        -- Lesbare Bezeichnung über eigene Funktion
        SET @errorMessage = N'Fehler: Case hat Status "'
            + dbo.fn_GetCaseStatusLabel(@caseStatus)
            + N'" – Dokumente können nicht mehr eingereicht werden.';
        RETURN;
    END;

  
    -- 2. DocumentTypeID prüfen
 
    IF NOT EXISTS (
        SELECT 1 FROM dbo.DocumentType
        WHERE DocumentTypeID = @documentTypeID
    )
    BEGIN
        SET @errorMessage = N'Fehler: DocumentTypeID '
            + CAST(@documentTypeID AS NVARCHAR)
            + N' existiert nicht.';
        RETURN;
    END;


    -- 3. Duplikat prüfen – gleiches Dokument für selben Case
    --    (abgelehnte Dokumente dürfen erneut eingereicht werden)

    IF EXISTS (
        SELECT 1
        FROM dbo.SubmittedDocuments
        WHERE CaseID          = @caseID
          AND DocumentTypeID  = @documentTypeID
          AND DocumentStatus <> 'Rejected'
          AND (
                (@uboID IS NULL AND UBOID IS NULL)
                OR UBOID = @uboID
              )
    )
    BEGIN
        SET @errorMessage = N'Hinweis: Dieses Dokument wurde bereits '
            + N'eingereicht und ist noch aktiv (Status nicht "Abgelehnt").';
        RETURN;
    END;

 
    -- 4. UBO-Zugehörigkeit prüfen (nur bei UBO-Dokumenten)
 
    IF @uboID IS NOT NULL
    BEGIN
        DECLARE @companyID INT;

        SELECT @companyID = CompanyID
        FROM dbo.OnboardingCase
        WHERE CaseID = @caseID;

        -- UBO muss meldepflichtig sein (Anteil >= 25%)
        -- Prüfung über eigene Skalarfunktion fn_IsUBOReportable
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Ownership
            WHERE CompanyID = @companyID
              AND UBOID      = @uboID
              AND dbo.fn_IsUBOReportable(OwnershipPercentage) = 1
        )
        BEGIN
            SET @errorMessage = N'Fehler: UBO '
                + CAST(@uboID AS NVARCHAR)
                + N' ist für dieses Unternehmen nicht meldepflichtig '
                + N'(Beteiligungsanteil unter 25%).';
            RETURN;
        END;
    END;

  
    -- 5. Dokument einfügen
  
    INSERT INTO dbo.SubmittedDocuments
        (CaseID, UBOID, DocumentTypeID, SubmissionDate, DocumentStatus)
    VALUES
        (@caseID, @uboID, @documentTypeID, GETDATE(), 'Pending');

    SET @newDocumentID = SCOPE_IDENTITY();

  
    -- 6. Alle Pflichtdokumente vorhanden?
    --    → Case automatisch auf 'InReview' setzen
    --    Prüfung über eigene Funktion fn_CountMissingMandatoryDocs
  
    IF dbo.fn_CountMissingMandatoryDocs(@caseID) = 0
    BEGIN
        UPDATE dbo.OnboardingCase
        SET    CaseStatus = 'InReview'
        WHERE  CaseID     = @caseID
          AND  CaseStatus = 'Open';  -- nur wenn noch 'Open'

        SET @errorMessage = N'OK – Dokument eingereicht. '
            + N'Alle Pflichtdokumente vollständig – '
            + N'Case wurde auf "In Prüfung" gesetzt.';
    END;
    ELSE
    BEGIN
        SET @errorMessage = N'OK – Dokument erfolgreich eingereicht. '
            + N'Es fehlen noch '
            + CAST(dbo.fn_CountMissingMandatoryDocs(@caseID) AS NVARCHAR)
            + N' Pflichtdokument(e).';
    END;
END;
GO

PRINT 'Prozedur usp_SubmitDocument erstellt.';
GO


-- PROZEDUR 2: usp_UpdateCaseStatus
-- Zweck:    Case-Status manuell aktualisieren (z.B. durch Prüfer)
--           Prüft gültige Statusübergänge.

IF OBJECT_ID('dbo.usp_UpdateCaseStatus', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_UpdateCaseStatus;
GO

CREATE PROCEDURE dbo.usp_UpdateCaseStatus
    @caseID       INT,
    @newStatus    NVARCHAR(50),
    @errorMessage NVARCHAR(500) = N'' OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @errorMessage = N'OK';

    -- Case prüfen
    DECLARE @currentStatus NVARCHAR(50);
    SELECT @currentStatus = CaseStatus
    FROM dbo.OnboardingCase
    WHERE CaseID = @caseID;

    IF @currentStatus IS NULL
    BEGIN
        SET @errorMessage = N'Fehler: CaseID nicht gefunden.';
        RETURN;
    END;

    -- Erlaubte Statusübergänge prüfen
    -- Open → InReview → Approved/Rejected → Closed
    DECLARE @allowed BIT = 0;

    IF @currentStatus = 'Open'     AND @newStatus IN ('InReview', 'Rejected') SET @allowed = 1;
    IF @currentStatus = 'InReview' AND @newStatus IN ('Approved', 'Rejected') SET @allowed = 1;
    IF @currentStatus IN ('Approved','Rejected') AND @newStatus = 'Closed'    SET @allowed = 1;

    IF @allowed = 0
    BEGIN
        SET @errorMessage = N'Fehler: Ungültiger Statusübergang von "'
            + dbo.fn_GetCaseStatusLabel(@currentStatus)
            + N'" nach "'
            + dbo.fn_GetCaseStatusLabel(@newStatus) + N'".';
        RETURN;
    END;

    -- Status aktualisieren
    UPDATE dbo.OnboardingCase
    SET CaseStatus = @newStatus
    WHERE CaseID = @caseID;

    SET @errorMessage = N'OK – Status von Case '
        + CAST(@caseID AS NVARCHAR)
        + N' auf "'
        + dbo.fn_GetCaseStatusLabel(@newStatus)
        + N'" gesetzt.';
END;
GO

PRINT 'Prozedur usp_UpdateCaseStatus erstellt.';
GO

------------------------------------------------------------------

USE OnboardingDB;
GO


-- TRIGGER: trg_OnboardingCase_StatusChange
-- Typ:     AFTER UPDATE auf Tabelle OnboardingCase
--
-- Business-Prozess:
--   Wenn ein Case auf 'Approved' gesetzt wird:
--     → alle 'Pending' Dokumente werden automatisch 'Verified'
--     → VerificationDate wird auf heute gesetzt
--
--   Wenn ein Case auf 'Rejected' gesetzt wird:
--     → alle 'Pending' Dokumente werden automatisch 'Rejected'
--     → VerificationDate wird auf heute gesetzt
--
--   In beiden Fällen:
--     → Falls noch kein externer Check vorhanden ist,
--       wird automatisch ein Eintrag mit SourceID=1
--       ('Internal Review') erstellt


IF OBJECT_ID('dbo.trg_OnboardingCase_StatusChange', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_OnboardingCase_StatusChange;
GO

CREATE TRIGGER dbo.trg_OnboardingCase_StatusChange
ON dbo.OnboardingCase
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Nur reagieren wenn CaseStatus tatsächlich geändert wurde
    IF NOT UPDATE(CaseStatus) RETURN;

 
    -- Fall 1: Case wurde auf APPROVED gesetzt
    --         → offene Dokumente verifizieren

    UPDATE sd
    SET    sd.DocumentStatus   = 'Verified',
           sd.VerificationDate = GETDATE()
    FROM   dbo.SubmittedDocuments sd
    INNER JOIN inserted i ON sd.CaseID = i.CaseID
    INNER JOIN deleted  d ON d.CaseID  = i.CaseID
    WHERE  i.CaseStatus     = 'Approved'
      AND  d.CaseStatus    <> 'Approved'    -- nur bei tatsächlicher Änderung
      AND  sd.DocumentStatus = 'Pending';


    -- Fall 2: Case wurde auf REJECTED gesetzt
    --         → offene Dokumente ablehnen
 
    UPDATE sd
    SET    sd.DocumentStatus   = 'Rejected',
           sd.VerificationDate = GETDATE()
    FROM   dbo.SubmittedDocuments sd
    INNER JOIN inserted i ON sd.CaseID = i.CaseID
    INNER JOIN deleted  d ON d.CaseID  = i.CaseID
    WHERE  i.CaseStatus     = 'Rejected'
      AND  d.CaseStatus    <> 'Rejected'    -- nur bei tatsächlicher Änderung
      AND  sd.DocumentStatus = 'Pending';

 
    -- Automatisch externen Check-Eintrag erstellen
    -- wenn noch keiner für diesen Case vorhanden ist
    -- ExternalSourceID = 1 → 'Internal Review'
 
    INSERT INTO dbo.ExternalVerificationCheck
        (CaseID, ExternalSourceID, CheckDate, CheckStatus, ResultSummary)
    SELECT
        i.CaseID,
        1,
        GETDATE(),
        CASE i.CaseStatus
            WHEN 'Approved' THEN 'Passed'
            WHEN 'Rejected' THEN 'Failed'
            ELSE 'Manual'
        END,
        N'Automatisch erstellt durch Trigger – Statusänderung auf: '
            + i.CaseStatus
            + N' (vorher: ' + d.CaseStatus + N')'
    FROM inserted i
    INNER JOIN deleted d ON d.CaseID = i.CaseID
    WHERE i.CaseStatus IN ('Approved', 'Rejected')
      AND d.CaseStatus <> i.CaseStatus
      AND NOT EXISTS (
            SELECT 1
            FROM dbo.ExternalVerificationCheck evc
            WHERE evc.CaseID = i.CaseID
          );

END;
GO

PRINT 'Trigger trg_OnboardingCase_StatusChange erstellt.';
GO

--------------------------------------------------------------------

USE OnboardingDB;
GO

-- SCHRITT 1: Alle Tabellen leeren
DELETE FROM dbo.ExternalVerificationCheck;
DELETE FROM dbo.SubmittedDocuments;
DELETE FROM dbo.ExternalSource;
DELETE FROM dbo.OnboardingCase;
DELETE FROM dbo.RequiredDocuments;
DELETE FROM dbo.Ownership;
DELETE FROM dbo.CompanyAddress;
DELETE FROM dbo.Company;
DELETE FROM dbo.UBO;
DELETE FROM dbo.DocumentType;
DELETE FROM dbo.LegalForm;
DELETE FROM dbo.Country;

DBCC CHECKIDENT ('Country',                   RESEED, 0);
DBCC CHECKIDENT ('LegalForm',                 RESEED, 0);
DBCC CHECKIDENT ('Company',                   RESEED, 0);
DBCC CHECKIDENT ('CompanyAddress',            RESEED, 0);
DBCC CHECKIDENT ('UBO',                       RESEED, 0);
DBCC CHECKIDENT ('Ownership',                 RESEED, 0);
DBCC CHECKIDENT ('DocumentType',              RESEED, 0);
DBCC CHECKIDENT ('RequiredDocuments',         RESEED, 0);
DBCC CHECKIDENT ('OnboardingCase',            RESEED, 0);
DBCC CHECKIDENT ('SubmittedDocuments',        RESEED, 0);
DBCC CHECKIDENT ('ExternalSource',            RESEED, 0);
DBCC CHECKIDENT ('ExternalVerificationCheck', RESEED, 0);
GO

-- SCHRITT 2: Country
INSERT INTO dbo.Country (CountryCode, CountryName, RegionName) VALUES
('DE', 'Germany',     'DACH'),
('AT', 'Austria',     'DACH'),
('CH', 'Switzerland', 'DACH'),
('NL', 'Netherlands', 'BENELUX'),
('BE', 'Belgium',     'BENELUX'),
('LU', 'Luxembourg',  'BENELUX');
GO

-- SCHRITT 3: LegalForm
INSERT INTO dbo.LegalForm (CountryID, LegalFormCode, LegalFormName) VALUES
(1, 'GmbH', 'Gesellschaft mit beschränkter Haftung'),
(1, 'UG',   'Unternehmergesellschaft'),
(1, 'AG',   'Aktiengesellschaft'),
(2, 'GmbH', 'Gesellschaft mit beschränkter Haftung'),
(2, 'AG',   'Aktiengesellschaft'),
(3, 'GmbH', 'Gesellschaft mit beschränkter Haftung'),
(3, 'AG',   'Aktiengesellschaft'),
(4, 'BV',   'Besloten Vennootschap'),
(4, 'NV',   'Naamloze Vennootschap'),
(5, 'SRL',  'Société à responsabilité limitée'),
(5, 'SA',   'Société Anonyme'),
(6, 'SARL', 'Société à responsabilité limitée'),
(6, 'SA',   'Société Anonyme');
GO

-- SCHRITT 4: Company
INSERT INTO dbo.Company
    (CompanyName, RegistrationNumber, LegalFormID, FoundationDate,
     IndustryCode, EmployeeCount, AnnualRevenue, RegistrationDate)
VALUES
('SolarTech GmbH',    'DE-HRB-100001',  1, '2015-03-15', '3511',  45,  2500000,  '2025-01-10'),
('GreenEnergy UG',    'DE-HRB-100002',  2, '2020-07-10', '3511',  12,  450000,   '2025-03-15'),
('AlpenVolt GmbH',    'AT-FN-200001',   4, '2014-06-20', '3511',  30,  1800000,  '2025-02-05'),
('ViennaSolar AG',    'AT-FN-200002',   5, '2010-01-01', '3511',  120, 8500000,  '2025-06-20'),
('SwissVolt GmbH',    'CH-CHE-300001',  6, '2016-05-05', '3511',  25,  1400000,  '2025-04-12'),
('ZurichEnergy AG',   'CH-CHE-300002',  7, '2008-09-09', '3511',  200, 12000000, '2025-09-05'),
('GreenBuild BV',     'NL-KVK-400001',  8, '2018-02-14', '4120',  40,  2200000,  '2025-05-18'),
('DutchSolar NV',     'NL-KVK-400002',  9, '2012-11-11', '3511',  90,  6700000,  '2025-11-30'),
('BelEco SRL',        'BE-0456-500001', 10, '2017-08-01', '3511',  35,  1900000,  '2025-07-22'),
('BrusselsEnergy SA', 'BE-0456-500002', 11, '2009-04-04', '3511',  150, 9800000,  '2025-10-14'),
('LuxPower SARL',     'LU-B-600001',   12, '2019-03-03', '3511',  20,  1100000,  '2026-01-08'),
('LuxEnergy SA',      'LU-B-600002',   13, '2011-12-12', '3511',  80,  7200000,  '2026-02-18');
GO

-- SCHRITT 5: CompanyAddress
INSERT INTO dbo.CompanyAddress
    (CompanyID, CountryID, AddressType, StreetAddress, PostalCode, City, IsPrimary)
VALUES
(1,  1, 'Registered', 'Alexanderplatz 1',       '10178', 'Berlin',     1),
(1,  1, 'Physical',   'Industriestrasse 22',    '12435', 'Berlin',     0),
(2,  1, 'Registered', 'Friedrichstrasse 10',    '10117', 'Berlin',     1),
(2,  1, 'Physical',   'Solarpark 5',            '12099', 'Berlin',     0),
(3,  2, 'Registered', 'Mariahilfer Strasse 50', '1060',  'Vienna',     1),
(3,  2, 'Physical',   'Energiepark 3',          '1100',  'Vienna',     0),
(4,  2, 'Registered', 'Ringstrasse 1',          '1010',  'Vienna',     1),
(4,  2, 'Physical',   'Industriezone 8',        '1230',  'Vienna',     0),
(5,  3, 'Registered', 'Bahnhofstrasse 10',      '8001',  'Zurich',     1),
(5,  3, 'Physical',   'Werkhof 7',              '8050',  'Zurich',     0),
(6,  3, 'Registered', 'Seestrasse 20',          '8700',  'Zurich',     1),
(6,  3, 'Physical',   'Solarpark 2',            '8600',  'Zurich',     0),
(7,  4, 'Registered', 'Damrak 5',               '1012LG','Amsterdam',  1),
(7,  4, 'Physical',   'Constructieweg 12',      '1043AN','Amsterdam',  0),
(8,  4, 'Registered', 'Keizersgracht 30',       '1015',  'Amsterdam',  1),
(8,  4, 'Physical',   'Energy Hub 9',           '1020',  'Amsterdam',  0),
(9,  5, 'Registered', 'Rue de la Loi 12',       '1000',  'Brussels',   1),
(9,  5, 'Physical',   'Green Park 4',           '1070',  'Brussels',   0),
(10, 5, 'Registered', 'Avenue Louise 25',       '1050',  'Brussels',   1),
(10, 5, 'Physical',   'Industrial Zone 6',      '1080',  'Brussels',   0),
(11, 6, 'Registered', 'Rue de la Gare 3',       '1611',  'Luxembourg', 1),
(11, 6, 'Physical',   'Technoport 5',           '3372',  'Leudelange', 0),
(12, 6, 'Registered', 'Boulevard Royal 15',     '2449',  'Luxembourg', 1),
(12, 6, 'Physical',   'Energy Park 2',          '3364',  'Leudelange', 0);
GO

-- SCHRITT 6: UBO
INSERT INTO dbo.UBO (FirstName, LastName, DateOfBirth, Nationality, PassportNo) VALUES
('Max',    'Mueller',   '1985-03-12', 'DE', 'DE-P-100001'),
('Laura',  'Schneider', '1990-07-21', 'DE', 'DE-P-100002'),
('Anna',   'Gruber',    '1987-06-08', 'AT', 'AT-P-200001'),
('Simon',  'Meier',     '1989-09-21', 'CH', 'CH-P-300001'),
('Anna',   'Jansen',    '1990-07-20', 'NL', 'NL-P-400001'),
('Mark',   'De Vries',  '1982-11-02', 'NL', 'NL-P-400002'),
('Luc',    'Dubois',    '1981-01-24', 'BE', 'BE-P-500001'),
('Claire', 'Hoffmann',  '1986-02-02', 'LU', 'LU-P-600001'),
('Ivan',   'Petrov',    '1978-05-17', 'DE', 'BG-P-700001'),
('Elena',  'Rossi',     '1992-08-30', 'DE', 'IT-P-800001');
GO

-- SCHRITT 7: Ownership
INSERT INTO dbo.Ownership
    (CompanyID, UBOID, OwnershipPercentage, IsOwnershipDirect, ValidFrom, ValidTo)
VALUES
(1,  1, 30.00, 1, '2025-01-10', NULL),
(2,  2, 20.00, 1, '2025-03-15', NULL),
(3,  3, 35.00, 1, '2025-02-05', NULL),
(3,  2, 65.00, 1, '2025-02-05', NULL),
(4,  3, 15.00, 0, '2025-06-20', NULL),
(5,  4, 23.00, 1, '2025-04-12', NULL),
(6,  4, 40.00, 0, '2025-09-05', NULL),
(7,  5, 20.00, 1, '2025-05-18', NULL),
(8,  6, 28.00, 1, '2025-11-30', NULL),
(8,  5, 72.00, 1, '2025-11-30', NULL),
(9,  7, 24.00, 1, '2025-07-22', NULL),
(10, 7, 52.00, 0, '2025-10-14', NULL),
(11, 8, 30.00, 1, '2026-01-08', NULL),
(12, 8, 49.00, 0, '2026-02-18', NULL),
(12, 9, 60.00, 1, '2026-02-18', NULL);
GO

-- SCHRITT 8: DocumentType
INSERT INTO dbo.DocumentType (DocumentTypeName, DocumentScope) VALUES
('Handelsregisterauszug',       'Company'),
('Gesellschaftsvertrag',        'Company'),
('Transparenzregisterauszug',   'Company'),
('Jahresabschluss',             'Company'),
('Personalausweis',             'UBO'),
('Wohnsitznachweis',            'UBO'),
('Steuernummer-Nachweis',       'UBO');
GO

-- SCHRITT 9: RequiredDocuments
INSERT INTO dbo.RequiredDocuments
    (LegalFormID, DocumentTypeID, RequirementLevel, AppliesToUBO, IsMandatory)
VALUES
(1, 1, 'Standard', 0, 1),
(1, 2, 'Standard', 0, 1),
(1, 5, 'Standard', 1, 1),
(2, 1, 'Standard', 0, 1),
(2, 5, 'Standard', 1, 1),
(3, 1, 'Standard', 0, 1),
(3, 3, 'Enhanced', 0, 1),
(3, 5, 'Standard', 1, 1),
(4, 1, 'Standard', 0, 1),
(4, 2, 'Standard', 0, 1),
(4, 5, 'Standard', 1, 1);
GO

-- SCHRITT 10: ExternalSource
INSERT INTO dbo.ExternalSource (SourceName, SourceCountry, SourceType) VALUES
('Internal Review',     NULL, 'Internal'),
('Creditreform',        'DE', 'Commercial'),
('Handelsregister DE',  'DE', 'Registry'),
('Firmenbuch AT',       'AT', 'Registry'),
('KvK Netherlands',     'NL', 'Registry'),
('Banque Nationale BE', 'BE', 'Registry');
GO

-- SCHRITT 11: OnboardingCase
INSERT INTO dbo.OnboardingCase (CompanyID, CaseStatus, CaseOpenDate) VALUES
(1,  'Approved',  '2025-01-10'),
(2,  'Open',      '2025-03-15'),
(3,  'InReview',  '2025-02-05'),
(4,  'Approved',  '2025-06-20'),
(5,  'Open',      '2025-04-12'),
(6,  'Rejected',  '2025-09-05'),
(7,  'InReview',  '2025-05-18'),
(8,  'Open',      '2025-11-30'),
(9,  'Approved',  '2025-07-22'),
(10, 'Open',      '2025-10-14'),
(11, 'InReview',  '2026-01-08'),
(12, 'Open',      '2026-02-18');
GO

-- SCHRITT 12: SubmittedDocuments
INSERT INTO dbo.SubmittedDocuments
    (CaseID, UBOID, DocumentTypeID, SubmissionDate, DocumentStatus, VerificationDate)
VALUES
(1,  NULL, 1, '2025-01-12', 'Verified', '2025-01-20'),
(1,  NULL, 2, '2025-01-12', 'Verified', '2025-01-20'),
(1,  1,    5, '2025-01-13', 'Verified', '2025-01-20'),
(3,  NULL, 1, '2025-02-08', 'Pending',  NULL),
(3,  NULL, 2, '2025-02-08', 'Pending',  NULL),
(4,  NULL, 1, '2025-06-22', 'Verified', '2025-06-30'),
(4,  3,    5, '2025-06-22', 'Verified', '2025-06-30'),
(7,  NULL, 1, '2025-05-20', 'Pending',  NULL),
(9,  NULL, 1, '2025-07-25', 'Verified', '2025-08-01'),
(9,  7,    5, '2025-07-25', 'Verified', '2025-08-01');
GO

-- SCHRITT 13: ExternalVerificationCheck
INSERT INTO dbo.ExternalVerificationCheck
    (CaseID, ExternalSourceID, CheckDate, CheckStatus, ResultSummary)
VALUES
(1,  2, '2025-01-15', 'Passed', 'Creditreform – keine negativen Eintraege'),
(1,  3, '2025-01-16', 'Passed', 'Handelsregister – Eintrag bestaetigt'),
(4,  4, '2025-06-25', 'Passed', 'Firmenbuch AT – Eintrag bestaetigt'),
(6,  2, '2025-09-10', 'Failed', 'Creditreform – negative Bonitaet'),
(9,  6, '2025-07-28', 'Passed', 'Banque Nationale – Eintrag bestaetigt');
GO

-- Kontrolle
SELECT 'Country'                    AS Tabelle, COUNT(*) AS Anzahl FROM dbo.Country
UNION ALL SELECT 'LegalForm',                   COUNT(*) FROM dbo.LegalForm
UNION ALL SELECT 'Company',                     COUNT(*) FROM dbo.Company
UNION ALL SELECT 'CompanyAddress',              COUNT(*) FROM dbo.CompanyAddress
UNION ALL SELECT 'UBO',                         COUNT(*) FROM dbo.UBO
UNION ALL SELECT 'Ownership',                   COUNT(*) FROM dbo.Ownership
UNION ALL SELECT 'DocumentType',                COUNT(*) FROM dbo.DocumentType
UNION ALL SELECT 'RequiredDocuments',           COUNT(*) FROM dbo.RequiredDocuments
UNION ALL SELECT 'OnboardingCase',              COUNT(*) FROM dbo.OnboardingCase
UNION ALL SELECT 'SubmittedDocuments',          COUNT(*) FROM dbo.SubmittedDocuments
UNION ALL SELECT 'ExternalSource',              COUNT(*) FROM dbo.ExternalSource
UNION ALL SELECT 'ExternalVerificationCheck',   COUNT(*) FROM dbo.ExternalVerificationCheck;
GO


------------------------------------------------------------------
-- Backup

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


-- Wiederherstellung (nur zur Dokumentation )

/*
USE master;

-- Bestehende Verbindungen trennen
ALTER DATABASE OnboardingDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE OnboardingDB
FROM DISK = 'C:\Backups\OnboardingDB.bak'
WITH REPLACE, STATS = 10;

ALTER DATABASE OnboardingDB SET MULTI_USER;
*/

-- DATEI:   11_Users_Permissions.sql
-- PROJEKT: Onboarding Database
-- ZWECK:   Logins, Benutzer, Rollen und Rechte erstellen
--
-- Struktur:
--   Login  -> Zugang zum SQL Server
--   User   -> Zugang zur Datenbank
--   Role   -> Berechtigungsgruppe (Best Practice)
--   GRANT  -> Rechte werden der Rolle zugewiesen
--   ALTER ROLE ADD MEMBER -> Benutzer wird der Rolle zugewiesen



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

--------------------------------------------------------------------
--Cursor
--
-- Business-Logik:
--   1. Geht durch alle Cases mit Status 'Open' oder 'InReview'
--   2. Prüft für jeden Case wie viele Pflichtdokumente fehlen
--   3. Gibt einen Bericht aus:
--      - Firmenname
--      - Case-Status
--      - Anzahl fehlender Pflichtdokumente
--      - Empfehlung


USE OnboardingDB;
GO

DECLARE @caseID       INT;
DECLARE @companyName  NVARCHAR(200);
DECLARE @caseStatus   NVARCHAR(50);
DECLARE @missingDocs  INT;
DECLARE @empfehlung   NVARCHAR(200);

-- Ergebnistabelle für den Bericht
DECLARE @report TABLE (
    CaseID          INT,
    CompanyName     NVARCHAR(200),
    CaseStatus      NVARCHAR(50),
    FehlendeDocs    INT,
    Empfehlung      NVARCHAR(200)
);


-- CURSOR definieren
-- Alle offenen und laufenden Cases durchgehen

DECLARE cursor_cases CURSOR FOR
    SELECT
        oc.CaseID,
        c.CompanyName,
        oc.CaseStatus
    FROM dbo.OnboardingCase oc
    INNER JOIN dbo.Company  c ON oc.CompanyID = c.CompanyID
    WHERE oc.CaseStatus IN ('Open', 'InReview')
    ORDER BY oc.CaseID;

-- CURSOR öffnen
OPEN cursor_cases;

-- Ersten Datensatz lesen
FETCH NEXT FROM cursor_cases
INTO @caseID, @companyName, @caseStatus;


-- Schleife: solange es Datensätze gibt

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Fehlende Pflichtdokumente zählen (eigene Funktion verwenden)
    SET @missingDocs = dbo.fn_CountMissingMandatoryDocs(@caseID);

    -- Empfehlung basierend auf fehlenden Dokumenten
    IF @missingDocs = 0
        SET @empfehlung = N'Alle Pflichtdokumente vorhanden – bereit für Genehmigung';
    ELSE IF @missingDocs = 1
        SET @empfehlung = N'Noch 1 Pflichtdokument ausstehend';
    ELSE
        SET @empfehlung = N'Noch ' + CAST(@missingDocs AS NVARCHAR)
                        + N' Pflichtdokumente ausstehend';

    -- Status automatisch aktualisieren wenn alle Dokumente vorhanden
    IF @missingDocs = 0 AND @caseStatus = 'Open'
    BEGIN
        UPDATE dbo.OnboardingCase
        SET CaseStatus = 'InReview'
        WHERE CaseID = @caseID;

        SET @caseStatus   = 'InReview';
        SET @empfehlung   = N'Status automatisch auf InReview gesetzt';
    END;

    -- Ergebnis in Berichtstabelle einfügen
    INSERT INTO @report (CaseID, CompanyName, CaseStatus, FehlendeDocs, Empfehlung)
    VALUES (@caseID, @companyName, @caseStatus, @missingDocs, @empfehlung);

    -- Nächsten Datensatz lesen
    FETCH NEXT FROM cursor_cases
    INTO @caseID, @companyName, @caseStatus;
END;


-- CURSOR schließen und freigeben

CLOSE cursor_cases;
DEALLOCATE cursor_cases;


-- Bericht ausgeben

SELECT
    CaseID,
    CompanyName,
    CaseStatus,
    FehlendeDocs    AS FehlendePflichtdokumente,
    Empfehlung
FROM @report
ORDER BY FehlendeDocs DESC;
GO
