-- =====================================================================
--  01_crea_database.sql – Online Retail II 🛒
--  Crea il database e le tabelle (funziona su MySQL 8 e, quasi uguale, su SQLite)
-- =====================================================================
CREATE DATABASE IF NOT EXISTS negozio_online;   -- (solo MySQL)
USE negozio_online;                             -- (solo MySQL)

DROP TABLE IF EXISTS vendite;
CREATE TABLE vendite (
    scontrino        VARCHAR(10)   NOT NULL,   -- numero dello scontrino
    codice_prodotto  VARCHAR(20)   NOT NULL,
    descrizione      VARCHAR(100),
    quantita         INT           NOT NULL,   -- pezzi venduti (> 0)
    data_ora         DATETIME      NOT NULL,
    prezzo           DECIMAL(10,2) NOT NULL,   -- prezzo unitario in sterline
    ricavo           DECIMAL(12,2) NOT NULL,   -- quantita × prezzo
    cliente_id       INT,                      -- NULL = cliente non registrato
    paese            VARCHAR(40),
    area             VARCHAR(15),              -- 'Regno Unito' o 'Estero'
    mese             CHAR(7)                   -- es. '2011-11'
);

DROP TABLE IF EXISTS resi;
CREATE TABLE resi (
    scontrino        VARCHAR(10)   NOT NULL,   -- inizia con 'C'
    codice_prodotto  VARCHAR(20)   NOT NULL,
    descrizione      VARCHAR(100),
    quantita         INT           NOT NULL,   -- pezzi resi (in positivo)
    data_ora         DATETIME      NOT NULL,
    prezzo           DECIMAL(10,2),
    valore_reso      DECIMAL(12,2),
    cliente_id       INT,
    paese            VARCHAR(40),
    mese             CHAR(7)
);

DROP TABLE IF EXISTS clienti_rfm;
CREATE TABLE clienti_rfm (
    cliente_id       INT PRIMARY KEY,
    ultimo_acquisto  DATE,
    primo_acquisto   DATE,
    frequenza        INT,            -- numero di scontrini
    spesa            DECIMAL(12,2),
    paese            VARCHAR(40),
    recency_giorni   INT,
    R INT, F INT, M INT,             -- punteggi da 1 a 5
    segmento         VARCHAR(20),
    punteggio_RFM    CHAR(3)
);

CREATE INDEX idx_vendite_cliente  ON vendite (cliente_id);
CREATE INDEX idx_vendite_prodotto ON vendite (codice_prodotto);
CREATE INDEX idx_vendite_scontrino ON vendite (scontrino);
CREATE INDEX idx_vendite_mese     ON vendite (mese);
