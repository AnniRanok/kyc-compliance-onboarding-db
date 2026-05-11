


USE OnboardingDB;
GO


--  NONCLUSTERED INDEXES 


-- Company: Index auf CompanyName 
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

-- OnboardingCase: Index auf CaseStatus 
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
