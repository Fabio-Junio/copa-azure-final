-- ============================================================
-- APPLY (auto-commit) -- corrige FASE DE GRUPOS para horario de BRASILIA (BRT)
-- Seguro para sqlcmd nao-interativo: valida e SO comita se tudo passar.
-- SET XACT_ABORT ON garante rollback automatico em erro de runtime.
-- Pos-checks: 72 jogos, 6 por grupo, e NENHUM confronto cross-grupo
--   (o ultimo tambem valida o mapeamento team_id->grupo).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRAN;

IF (SELECT COUNT(*) FROM dbo.matches WHERE stage='Fase de Grupos') <> 72
BEGIN RAISERROR('Pre-check: nao ha 72 jogos de fase de grupos.',16,1); ROLLBACK TRAN; RETURN; END;

DECLARE @canon TABLE (rn INT, home_team_id INT, away_team_id INT, stadium_id INT, [date] DATE, [time] NVARCHAR(5), group_name NVARCHAR(1));
INSERT INTO @canon (rn,home_team_id,away_team_id,stadium_id,[date],[time],group_name) VALUES
(1, 2, 17, 6, '2026-06-11', '16:00', 'A'),
(2, 18, 19, 17, '2026-06-11', '23:00', 'A'),
(3, 19, 17, 10, '2026-06-18', '13:00', 'A'),
(4, 2, 18, 17, '2026-06-18', '22:00', 'A'),
(5, 19, 2, 6, '2026-06-24', '22:00', 'A'),
(6, 17, 18, 7, '2026-06-24', '22:00', 'A'),
(7, 3, 20, 9, '2026-06-12', '16:00', 'B'),
(8, 21, 22, 16, '2026-06-13', '16:00', 'B'),
(9, 22, 20, 3, '2026-06-18', '16:00', 'B'),
(10, 3, 21, 8, '2026-06-18', '19:00', 'B'),
(11, 22, 3, 8, '2026-06-24', '16:00', 'B'),
(12, 20, 21, 5, '2026-06-24', '16:00', 'B'),
(13, 5, 12, 1, '2026-06-13', '19:00', 'C'),
(14, 23, 24, 11, '2026-06-13', '22:00', 'C'),
(15, 24, 12, 11, '2026-06-19', '19:00', 'C'),
(16, 5, 23, 13, '2026-06-19', '21:30', 'C'),
(17, 24, 5, 12, '2026-06-24', '19:00', 'C'),
(18, 12, 23, 10, '2026-06-24', '19:00', 'C'),
(19, 1, 25, 3, '2026-06-12', '22:00', 'D'),
(20, 26, 27, 8, '2026-06-14', '01:00', 'D'),
(21, 1, 26, 5, '2026-06-19', '16:00', 'D'),
(22, 27, 25, 16, '2026-06-20', '00:00', 'D'),
(23, 27, 1, 3, '2026-06-25', '23:00', 'D'),
(24, 25, 26, 16, '2026-06-25', '23:00', 'D'),
(25, 29, 30, 13, '2026-06-14', '20:00', 'E'),
(26, 7, 28, 14, '2026-06-14', '14:00', 'E'),
(27, 7, 29, 9, '2026-06-20', '17:00', 'E'),
(28, 30, 28, 15, '2026-06-20', '21:00', 'E'),
(29, 28, 29, 13, '2026-06-25', '17:00', 'E'),
(30, 30, 7, 1, '2026-06-25', '17:00', 'E'),
(31, 14, 8, 2, '2026-06-14', '17:00', 'F'),
(32, 31, 32, 7, '2026-06-14', '23:00', 'F'),
(33, 14, 31, 14, '2026-06-20', '14:00', 'F'),
(34, 32, 8, 7, '2026-06-21', '01:00', 'F'),
(35, 8, 31, 2, '2026-06-25', '20:00', 'F'),
(36, 32, 14, 15, '2026-06-25', '20:00', 'F'),
(37, 35, 36, 3, '2026-06-15', '22:00', 'G'),
(38, 33, 34, 5, '2026-06-15', '16:00', 'G'),
(39, 33, 35, 3, '2026-06-21', '16:00', 'G'),
(40, 36, 34, 8, '2026-06-21', '22:00', 'G'),
(41, 34, 35, 5, '2026-06-27', '00:00', 'G'),
(42, 36, 33, 8, '2026-06-27', '00:00', 'G'),
(43, 38, 16, 12, '2026-06-15', '19:00', 'H'),
(44, 10, 37, 10, '2026-06-15', '13:00', 'H'),
(45, 16, 37, 12, '2026-06-21', '19:00', 'H'),
(46, 10, 38, 10, '2026-06-21', '13:00', 'H'),
(47, 37, 38, 14, '2026-06-26', '21:00', 'H'),
(48, 16, 10, 17, '2026-06-26', '21:00', 'H'),
(49, 9, 39, 1, '2026-06-16', '16:00', 'I'),
(50, 40, 41, 11, '2026-06-16', '19:00', 'I'),
(51, 9, 40, 13, '2026-06-22', '18:00', 'I'),
(52, 41, 39, 1, '2026-06-22', '21:00', 'I'),
(53, 41, 9, 11, '2026-06-26', '16:00', 'I'),
(54, 39, 40, 9, '2026-06-26', '16:00', 'I'),
(55, 6, 44, 15, '2026-06-16', '22:00', 'J'),
(56, 42, 43, 16, '2026-06-17', '01:00', 'J'),
(57, 6, 42, 2, '2026-06-22', '14:00', 'J'),
(58, 43, 44, 16, '2026-06-23', '00:00', 'J'),
(59, 44, 42, 15, '2026-06-27', '23:00', 'J'),
(60, 43, 6, 2, '2026-06-27', '23:00', 'J'),
(61, 11, 46, 14, '2026-06-17', '14:00', 'K'),
(62, 45, 4, 6, '2026-06-17', '23:00', 'K'),
(63, 11, 45, 14, '2026-06-23', '14:00', 'K'),
(64, 4, 46, 17, '2026-06-23', '23:00', 'K'),
(65, 4, 11, 12, '2026-06-27', '20:30', 'K'),
(66, 46, 45, 10, '2026-06-27', '20:30', 'K'),
(67, 13, 47, 2, '2026-06-17', '17:00', 'L'),
(68, 48, 49, 9, '2026-06-17', '20:00', 'L'),
(69, 13, 48, 11, '2026-06-23', '17:00', 'L'),
(70, 49, 47, 9, '2026-06-23', '20:00', 'L'),
(71, 49, 13, 1, '2026-06-27', '18:00', 'L'),
(72, 47, 48, 13, '2026-06-27', '18:00', 'L');

;WITH cur AS (
  SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn
  FROM dbo.matches WHERE stage='Fase de Grupos'
)
UPDATE m SET
  m.home_team_id=c.home_team_id, m.away_team_id=c.away_team_id, m.stadium_id=c.stadium_id,
  m.[date]=c.[date], m.[time]=c.[time], m.group_name=c.group_name,
  m.status='scheduled', m.home_score=NULL, m.away_score=NULL
FROM dbo.matches m JOIN cur ON cur.id=m.id JOIN @canon c ON c.rn=cur.rn;

-- POS-CHECK 1: 6 jogos por grupo
IF EXISTS (SELECT 1 FROM (SELECT group_name, COUNT(*) c FROM dbo.matches WHERE stage='Fase de Grupos' GROUP BY group_name) x WHERE x.c<>6)
BEGIN RAISERROR('Pos-check: algum grupo nao tem 6 jogos.',16,1); ROLLBACK TRAN; RETURN; END;

-- POS-CHECK 2: nenhum confronto cross-grupo
IF EXISTS (
  SELECT 1 FROM dbo.matches m
  JOIN dbo.teams th ON th.id=m.home_team_id
  JOIN dbo.teams ta ON ta.id=m.away_team_id
  WHERE m.stage='Fase de Grupos' AND (th.group_name<>m.group_name OR ta.group_name<>m.group_name))
BEGIN RAISERROR('Pos-check: existe confronto cross-grupo (mapa de IDs suspeito).',16,1); ROLLBACK TRAN; RETURN; END;

COMMIT TRAN;
PRINT 'OK: 72 jogos da fase de grupos corrigidos para BRT e commitados.';

SELECT m.[date], m.[time], th.code AS home, ta.code AS away, s.name AS sede, m.group_name AS grp
FROM dbo.matches m
JOIN dbo.teams th ON th.id=m.home_team_id
JOIN dbo.teams ta ON ta.id=m.away_team_id
JOIN dbo.stadiums s ON s.id=m.stadium_id
WHERE m.stage='Fase de Grupos' ORDER BY m.[date], m.[time];
