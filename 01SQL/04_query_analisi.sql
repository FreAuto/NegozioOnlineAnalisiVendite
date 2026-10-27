-- =====================================================================
--  03_query_analisi.sql – Online Retail II 🛒
--  20 query che rispondono alle 6 domande del progetto.
--  Testate su SQLite; scritte per funzionare anche su MySQL 8
--  (CTE e funzioni finestra; niente funzioni sulle date: uso la colonna "mese").
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0️⃣  CONTROLLO DEI DATI
-- ---------------------------------------------------------------------

-- Q0.1 Quante righe, scontrini, clienti, prodotti e paesi?
SELECT COUNT(*)                         AS righe,
       COUNT(DISTINCT scontrino)        AS scontrini,
       COUNT(DISTINCT cliente_id)       AS clienti,
       COUNT(DISTINCT codice_prodotto)  AS prodotti,
       COUNT(DISTINCT paese)            AS paesi,
       ROUND(SUM(ricavo), 0)            AS ricavi_totali
FROM vendite;

-- Q0.2 Che percentuale di vendite non ha il codice cliente?
SELECT ROUND(100.0 * SUM(CASE WHEN cliente_id IS NULL THEN ricavo ELSE 0 END) / SUM(ricavo), 1) AS pct_ricavi_senza_cliente
FROM vendite;


-- ---------------------------------------------------------------------
-- 1️⃣  COME VANNO LE VENDITE NEL TEMPO?
-- ---------------------------------------------------------------------

-- Q1.1 Ricavi, scontrini e clienti per mese
SELECT mese,
       ROUND(SUM(ricavo), 0)       AS ricavi,
       COUNT(DISTINCT scontrino)   AS scontrini,
       COUNT(DISTINCT cliente_id)  AS clienti
FROM vendite
GROUP BY mese
ORDER BY mese;

-- Q1.2 Crescita rispetto allo stesso mese dell'anno prima (funzione finestra LAG)
WITH m AS (
    SELECT mese, SUM(ricavo) AS ricavi FROM vendite GROUP BY mese
)
SELECT mese,
       ROUND(ricavi, 0) AS ricavi,
       ROUND(LAG(ricavi, 12) OVER (ORDER BY mese), 0) AS ricavi_anno_prima,
       ROUND(100.0 * (ricavi - LAG(ricavi, 12) OVER (ORDER BY mese)) / LAG(ricavi, 12) OVER (ORDER BY mese), 1) AS crescita_pct
FROM m
ORDER BY mese;

-- Q1.3 Quanto pesa il periodo settembre-novembre (stagione di Natale) sull'anno 2010?
SELECT ROUND(100.0 * SUM(CASE WHEN mese IN ('2010-09','2010-10','2010-11') THEN ricavo ELSE 0 END)
             / SUM(ricavo), 1) AS pct_ricavi_set_nov_2010
FROM vendite
WHERE mese LIKE '2010-%';

-- Q1.4 Scontrino medio per anno
SELECT SUBSTR(mese, 1, 4) AS anno,
       ROUND(SUM(ricavo) / COUNT(DISTINCT scontrino), 2) AS scontrino_medio
FROM vendite
GROUP BY SUBSTR(mese, 1, 4)
ORDER BY anno;


-- ---------------------------------------------------------------------
-- 2️⃣  QUALI PRODOTTI E QUALI PAESI PORTANO PIÙ SOLDI?
-- ---------------------------------------------------------------------

-- Q2.1 I 10 prodotti con più ricavi
SELECT codice_prodotto, descrizione,
       ROUND(SUM(ricavo), 0) AS ricavi,
       SUM(quantita)         AS pezzi
FROM vendite
GROUP BY codice_prodotto, descrizione
ORDER BY ricavi DESC
LIMIT 10;

-- Q2.2 Regola 80/20: quanti prodotti fanno l'80% dei ricavi? (somma cumulata)
WITH p AS (
    SELECT codice_prodotto, SUM(ricavo) AS ricavi FROM vendite GROUP BY codice_prodotto
), c AS (
    SELECT codice_prodotto,
           SUM(ricavi) OVER (ORDER BY ricavi DESC) / SUM(ricavi) OVER () AS quota_cumulata,
           ROW_NUMBER() OVER (ORDER BY ricavi DESC) AS posizione,
           COUNT(*) OVER () AS tot_prodotti
    FROM p
)
SELECT MIN(posizione) AS prodotti_per_80pct,
       MAX(tot_prodotti) AS prodotti_totali,
       ROUND(100.0 * MIN(posizione) / MAX(tot_prodotti), 1) AS pct_prodotti
FROM c
WHERE quota_cumulata >= 0.8;

-- Q2.3 I 10 paesi esteri con più ricavi e il loro scontrino medio
SELECT paese,
       ROUND(SUM(ricavo), 0) AS ricavi,
       COUNT(DISTINCT cliente_id) AS clienti,
       ROUND(SUM(ricavo) / COUNT(DISTINCT scontrino), 0) AS scontrino_medio
FROM vendite
WHERE paese <> 'United Kingdom'
GROUP BY paese
ORDER BY ricavi DESC
LIMIT 10;

-- Q2.4 Il prodotto più venduto in ogni paese (funzione finestra RANK)
WITH pp AS (
    SELECT paese, descrizione, SUM(ricavo) AS ricavi,
           RANK() OVER (PARTITION BY paese ORDER BY SUM(ricavo) DESC) AS posto
    FROM vendite
    GROUP BY paese, descrizione
)
SELECT paese, descrizione, ROUND(ricavi, 0) AS ricavi
FROM pp
WHERE posto = 1
ORDER BY ricavi DESC
LIMIT 15;


-- ---------------------------------------------------------------------
-- 3️⃣  CHI SONO I CLIENTI MIGLIORI? (RFM)
-- ---------------------------------------------------------------------

-- Q3.1 Quanti clienti e quanta spesa per ogni segmento
SELECT segmento,
       COUNT(*) AS clienti,
       ROUND(SUM(spesa), 0) AS spesa,
       ROUND(100.0 * SUM(spesa) / (SELECT SUM(spesa) FROM clienti_rfm), 1) AS pct_spesa,
       ROUND(AVG(recency_giorni), 0) AS giorni_da_ultimo_acquisto
FROM clienti_rfm
GROUP BY segmento
ORDER BY spesa DESC;

-- Q3.2 Il 10% dei clienti che spende di più: quanta spesa fa? (NTILE)
WITH d AS (
    SELECT spesa, NTILE(10) OVER (ORDER BY spesa DESC) AS decile FROM clienti_rfm
)
SELECT ROUND(100.0 * SUM(CASE WHEN decile = 1 THEN spesa ELSE 0 END) / SUM(spesa), 1) AS pct_spesa_top10_clienti
FROM d;

-- Q3.3 I 10 clienti migliori
SELECT cliente_id, paese, frequenza AS scontrini, spesa, recency_giorni, segmento
FROM clienti_rfm
ORDER BY spesa DESC
LIMIT 10;

-- Q3.4 Clienti "Da non perdere": spendevano tanto ma non comprano da molto
SELECT cliente_id, paese, spesa, recency_giorni, ultimo_acquisto
FROM clienti_rfm
WHERE segmento = 'Da non perdere'
ORDER BY spesa DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- 4️⃣  QUANTI CLIENTI TORNANO A COMPRARE?
-- ---------------------------------------------------------------------

-- Q4.1 Clienti che hanno comprato una volta sola vs più volte
SELECT CASE WHEN frequenza = 1 THEN '1 solo acquisto' ELSE 'più acquisti' END AS tipo,
       COUNT(*) AS clienti,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM clienti_rfm), 1) AS pct_clienti,
       ROUND(100.0 * SUM(spesa) / (SELECT SUM(spesa) FROM clienti_rfm), 1) AS pct_spesa
FROM clienti_rfm
GROUP BY CASE WHEN frequenza = 1 THEN '1 solo acquisto' ELSE 'più acquisti' END;

-- Q4.2 Coorti: clienti nuovi per mese e quanti tornano 1, 3 e 6 mesi dopo
WITH primo AS (
    SELECT cliente_id, MIN(mese) AS coorte FROM vendite WHERE cliente_id IS NOT NULL GROUP BY cliente_id
), attivita AS (
    SELECT DISTINCT v.cliente_id, p.coorte,
           (CAST(SUBSTR(v.mese, 1, 4) AS INT) - CAST(SUBSTR(p.coorte, 1, 4) AS INT)) * 12
         + (CAST(SUBSTR(v.mese, 6, 2) AS INT) - CAST(SUBSTR(p.coorte, 6, 2) AS INT)) AS mesi_dopo
    FROM vendite v JOIN primo p ON v.cliente_id = p.cliente_id
)
SELECT coorte,
       SUM(CASE WHEN mesi_dopo = 0 THEN 1 ELSE 0 END) AS nuovi_clienti,
       ROUND(100.0 * SUM(CASE WHEN mesi_dopo = 1 THEN 1 ELSE 0 END) / SUM(CASE WHEN mesi_dopo = 0 THEN 1 ELSE 0 END), 1) AS ritorno_1_mese_pct,
       ROUND(100.0 * SUM(CASE WHEN mesi_dopo = 3 THEN 1 ELSE 0 END) / SUM(CASE WHEN mesi_dopo = 0 THEN 1 ELSE 0 END), 1) AS ritorno_3_mesi_pct,
       ROUND(100.0 * SUM(CASE WHEN mesi_dopo = 6 THEN 1 ELSE 0 END) / SUM(CASE WHEN mesi_dopo = 0 THEN 1 ELSE 0 END), 1) AS ritorno_6_mesi_pct
FROM attivita
GROUP BY coorte
ORDER BY coorte;


-- ---------------------------------------------------------------------
-- 5️⃣  QUALI PRODOTTI VENGONO COMPRATI INSIEME?
-- ---------------------------------------------------------------------

-- Q5.1 Le coppie di prodotti più frequenti nello stesso scontrino
--      (limitato ai 100 prodotti più venduti, per velocità: self-join)
WITH top AS (
    SELECT codice_prodotto FROM vendite GROUP BY codice_prodotto
    ORDER BY COUNT(DISTINCT scontrino) DESC LIMIT 100
), righe AS (
    SELECT DISTINCT scontrino, codice_prodotto, descrizione
    FROM vendite WHERE codice_prodotto IN (SELECT codice_prodotto FROM top)
)
SELECT a.descrizione AS prodotto_a, b.descrizione AS prodotto_b, COUNT(*) AS scontrini_insieme
FROM righe a
JOIN righe b ON a.scontrino = b.scontrino AND a.codice_prodotto < b.codice_prodotto
GROUP BY a.descrizione, b.descrizione
ORDER BY scontrini_insieme DESC
LIMIT 10;

-- Q5.2 Quanti prodotti diversi ci sono in media in uno scontrino?
SELECT ROUND(AVG(n), 1) AS prodotti_medi_per_scontrino
FROM (SELECT scontrino, COUNT(DISTINCT codice_prodotto) AS n FROM vendite GROUP BY scontrino) s;


-- ---------------------------------------------------------------------
-- 6️⃣  QUANTO PESANO I RESI?
-- ---------------------------------------------------------------------

-- Q6.1 Valore dei resi rispetto alle vendite, per anno
SELECT r.anno, ROUND(r.resi, 0) AS valore_resi, ROUND(v.vendite, 0) AS vendite,
       ROUND(100.0 * r.resi / v.vendite, 2) AS resi_su_vendite_pct
FROM (SELECT SUBSTR(mese, 1, 4) AS anno, SUM(valore_reso) AS resi FROM resi GROUP BY SUBSTR(mese, 1, 4)) r
JOIN (SELECT SUBSTR(mese, 1, 4) AS anno, SUM(ricavo) AS vendite FROM vendite GROUP BY SUBSTR(mese, 1, 4)) v
  ON r.anno = v.anno
ORDER BY r.anno;

-- Q6.2 I prodotti con il tasso di reso più alto (solo prodotti con almeno 10.000 £ di vendite)
WITH v AS (
    SELECT codice_prodotto, MAX(descrizione) AS descrizione, SUM(ricavo) AS vendite, SUM(quantita) AS pezzi
    FROM vendite GROUP BY codice_prodotto
), r AS (
    SELECT codice_prodotto, SUM(quantita) AS pezzi_resi FROM resi GROUP BY codice_prodotto
)
SELECT v.descrizione, ROUND(v.vendite, 0) AS vendite, v.pezzi, r.pezzi_resi,
       ROUND(100.0 * r.pezzi_resi / v.pezzi, 1) AS tasso_reso_pct
FROM v JOIN r ON v.codice_prodotto = r.codice_prodotto
WHERE v.vendite >= 10000
ORDER BY tasso_reso_pct DESC
LIMIT 10;

-- Q6.3 I paesi con più resi in proporzione (almeno 50.000 £ di vendite)
SELECT v.paese, ROUND(v.vendite, 0) AS vendite, ROUND(COALESCE(r.resi, 0), 0) AS resi,
       ROUND(100.0 * COALESCE(r.resi, 0) / v.vendite, 2) AS resi_pct
FROM (SELECT paese, SUM(ricavo) AS vendite FROM vendite GROUP BY paese) v
LEFT JOIN (SELECT paese, SUM(valore_reso) AS resi FROM resi GROUP BY paese) r ON v.paese = r.paese
WHERE v.vendite >= 50000
ORDER BY resi_pct DESC
LIMIT 10;
