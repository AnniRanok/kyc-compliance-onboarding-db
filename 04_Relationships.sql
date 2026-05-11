
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
