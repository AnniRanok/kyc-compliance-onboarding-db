
USE OnboardingDB;
GO


-- TRIGGER: trg_OnboardingCase_StatusChange
-- Typ:     AFTER UPDATE auf Tabelle OnboardingCase
--
-- Business-Prozess:
--   Wenn ein Case auf 'Approved' gesetzt wird:
--      alle 'Pending' Dokumente werden automatisch 'Verified'
--      VerificationDate wird auf heute gesetzt
--
--   Wenn ein Case auf 'Rejected' gesetzt wird:
--      alle 'Pending' Dokumente werden automatisch 'Rejected'
--      VerificationDate wird auf heute gesetzt
--
--   In beiden Fällen:
--      Falls noch kein externer Check vorhanden ist,
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
    --          offene Dokumente verifizieren
    
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
    --          offene Dokumente ablehnen
   
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
    -- ExternalSourceID = 1  'Internal Review'
    
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
