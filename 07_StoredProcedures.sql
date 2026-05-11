
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
