
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
