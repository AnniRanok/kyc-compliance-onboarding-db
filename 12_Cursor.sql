
-- ZWECK:   CURSOR – Pflichtdokumente aller offenen Cases prüfen
--          und Status automatisch aktualisieren
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
