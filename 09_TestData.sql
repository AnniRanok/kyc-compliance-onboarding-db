
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
