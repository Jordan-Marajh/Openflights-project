/* =====================================================================
   OpenFlights  -  COMPLETE BUILD IN ONE SCRIPT (SSMS / T-SQL)
   Creates the database, loads the cleaned CSVs, applies constraints,
   validates. No Python. Just press Execute (F5) with this whole file.

   >>> BEFORE RUNNING: file location matters on SQL Express <<<
   BULK INSERT reads the CSVs as the SQL Server SERVICE account, not as
   you. A user folder like Documents usually FAILS with
     "Operating system error code 5 (Access is denied)".
   Fix: make a plain folder, e.g.  C:\OpenFlightsData\ , copy your six
   cleaned CSVs into it. If that folder also denies, right-click it ->
   Properties -> Security -> give "Everyone" Read (fine on a local box).
   If you use a different folder, Find & Replace  C:\OpenFlightsData
   throughout Section 3.

   Files expected in that folder (exact names from the notebook):
     countries.csv  planes.csv  airports.csv
     airlines.csv   routes.csv  route_equipment.csv

    @authors
    Jordan, Chan, Emily, Michael
   ===================================================================== */


/* ---------- SECTION 1 : DATABASE ---------- */
IF DB_ID('OpenFlights') IS NULL
    CREATE DATABASE OpenFlights;
GO
USE OpenFlights;
GO


/* ---------- SECTION 2 : TABLES (PK + types, no FKs yet) ---------- */
IF OBJECT_ID('dbo.route_equipment','U') IS NOT NULL DROP TABLE dbo.route_equipment;
IF OBJECT_ID('dbo.route','U')           IS NOT NULL DROP TABLE dbo.route;
IF OBJECT_ID('dbo.airport','U')         IS NOT NULL DROP TABLE dbo.airport;
IF OBJECT_ID('dbo.airline','U')         IS NOT NULL DROP TABLE dbo.airline;
IF OBJECT_ID('dbo.plane','U')           IS NOT NULL DROP TABLE dbo.plane;
IF OBJECT_ID('dbo.country','U')         IS NOT NULL DROP TABLE dbo.country;
GO

CREATE TABLE dbo.country (
    iso_code     CHAR(2)       NOT NULL,   -- ISO 3166-1 alpha-2, natural PK
    name         VARCHAR(100)  NOT NULL,
    dafif_code   CHAR(2)       NULL,
    CONSTRAINT PK_country      PRIMARY KEY (iso_code),
    CONSTRAINT UQ_country_name UNIQUE (name)
);

CREATE TABLE dbo.plane (
    iata_code    CHAR(3)       NOT NULL,   -- IATA aircraft type code, natural PK
    icao_code    VARCHAR(4)    NULL,
    name         VARCHAR(100)  NOT NULL,
    CONSTRAINT PK_plane PRIMARY KEY (iata_code)
);

CREATE TABLE dbo.airport (
    airport_id            INT           NOT NULL,
    name                  VARCHAR(150)  NOT NULL,
    city                  VARCHAR(100)  NULL,
    country_iso_code      CHAR(2)       NULL,   -- FK -> country; nullable (168 didn't resolve)
    iata_code             CHAR(3)       NULL,
    icao_code             VARCHAR(4)    NULL,
    latitude              DECIMAL(9,6)  NULL,
    longitude             DECIMAL(9,6)  NULL,
    altitude              INT           NULL,   -- feet
    timezone_offset       DECIMAL(4,2)  NULL,   -- hours from UTC
    dst                   CHAR(1)       NULL,
    tz_database_timezone  VARCHAR(50)   NULL,
    type                  VARCHAR(30)   NULL,
    source                VARCHAR(30)   NULL,
    CONSTRAINT PK_airport PRIMARY KEY (airport_id)
);

CREATE TABLE dbo.airline (
    airline_id        INT           NOT NULL,
    name              VARCHAR(150)  NOT NULL,
    alias             VARCHAR(100)  NULL,
    iata_code         VARCHAR(3)    NULL,   -- 1-3 chars in data, so VARCHAR
    icao_code         VARCHAR(5)    NULL,   -- 2-5 chars in data, so VARCHAR
    callsign          VARCHAR(100)  NULL,
    country_iso_code  CHAR(2)       NULL,   -- FK -> country; nullable (245 didn't resolve)
    active            CHAR(1)       NULL,   -- 'Y' / 'N'
    CONSTRAINT PK_airline PRIMARY KEY (airline_id)
);

CREATE TABLE dbo.route (
    route_id               INT      NOT NULL,
    airline_id             INT      NULL,
    source_airport_id      INT      NULL,
    destination_airport_id INT      NULL,
    codeshare              CHAR(1)  NULL,
    stops                  INT      NULL,
    CONSTRAINT PK_route PRIMARY KEY (route_id)
);

CREATE TABLE dbo.route_equipment (   -- bridge: route <-> plane many-to-many
    route_id         INT      NOT NULL,
    plane_iata_code  CHAR(3)  NOT NULL,
    CONSTRAINT PK_route_equipment PRIMARY KEY (route_id, plane_iata_code)
);
GO


/* ---------- SECTION 3 : LOAD via BULK INSERT  (replaces the Python loader) ----------
   Options tuned to your files:
     FORMAT='CSV'       -> handles commas inside quoted names
     FIRSTROW=2         -> skips the header row
     ROWTERMINATOR      -> 0x0a  (your files are LF, not CRLF)
     CODEPAGE='65001'   -> UTF-8, so accented airport names load correctly
     KEEPNULLS          -> empty fields become NULL, not empty string
   Column order in each CSV already matches the table, so positional
   mapping is fine. */

BULK INSERT dbo.country          FROM 'C:\OpenFlightsData\countries.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', CODEPAGE='65001', KEEPNULLS, TABLOCK);

BULK INSERT dbo.plane            FROM 'C:\OpenFlightsData\planes.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', CODEPAGE='65001', KEEPNULLS, TABLOCK);

BULK INSERT dbo.airport          FROM 'C:\OpenFlightsData\airports.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', CODEPAGE='65001', KEEPNULLS, TABLOCK);

BULK INSERT dbo.airline          FROM 'C:\OpenFlightsData\airlines.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', CODEPAGE='65001', KEEPNULLS, TABLOCK);

BULK INSERT dbo.route            FROM 'C:\OpenFlightsData\routes.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', CODEPAGE='65001', KEEPNULLS, TABLOCK);

BULK INSERT dbo.route_equipment  FROM 'C:\OpenFlightsData\route_equipment.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', CODEPAGE='65001', KEEPNULLS, TABLOCK);
GO

-- Safety net: make sure empty country codes are NULL (not blank) before the FK gate
UPDATE dbo.airport SET country_iso_code = NULL WHERE country_iso_code = '';
UPDATE dbo.airline SET country_iso_code = NULL WHERE country_iso_code = '';
GO


/* ---------- SECTION 4 : FOREIGN KEYS  (integrity gate) ----------
   Each ALTER scans the data: it either succeeds (referential integrity
   proven) or names the table still holding orphans. */

ALTER TABLE dbo.airport
    ADD CONSTRAINT FK_airport_country
    FOREIGN KEY (country_iso_code) REFERENCES dbo.country (iso_code);

ALTER TABLE dbo.airline
    ADD CONSTRAINT FK_airline_country
    FOREIGN KEY (country_iso_code) REFERENCES dbo.country (iso_code);

ALTER TABLE dbo.route
    ADD CONSTRAINT FK_route_airline
    FOREIGN KEY (airline_id) REFERENCES dbo.airline (airline_id);

ALTER TABLE dbo.route
    ADD CONSTRAINT FK_route_source_airport
    FOREIGN KEY (source_airport_id) REFERENCES dbo.airport (airport_id);

ALTER TABLE dbo.route
    ADD CONSTRAINT FK_route_destination_airport
    FOREIGN KEY (destination_airport_id) REFERENCES dbo.airport (airport_id);

ALTER TABLE dbo.route_equipment
    ADD CONSTRAINT FK_route_equipment_route
    FOREIGN KEY (route_id) REFERENCES dbo.route (route_id);

ALTER TABLE dbo.route_equipment
    ADD CONSTRAINT FK_route_equipment_plane
    FOREIGN KEY (plane_iata_code) REFERENCES dbo.plane (iata_code);
GO


/* ---------- SECTION 5 : VALIDATION ---------- */

-- Row counts. Expected:
--   country 239 | plane 220 | airport 7698 | airline 6162 | route 66316 | route_equipment 77669
SELECT 'country'         AS table_name, COUNT(*) AS row_count FROM dbo.country
UNION ALL SELECT 'plane',           COUNT(*) FROM dbo.plane
UNION ALL SELECT 'airport',         COUNT(*) FROM dbo.airport
UNION ALL SELECT 'airline',         COUNT(*) FROM dbo.airline
UNION ALL SELECT 'route',           COUNT(*) FROM dbo.route
UNION ALL SELECT 'route_equipment', COUNT(*) FROM dbo.route_equipment;

-- Sample four-table join
SELECT TOP (10)
       al.name       AS airline,
       src.iata_code AS from_iata,
       dst.iata_code AS to_iata,
       src.city      AS from_city,
       dst.city      AS to_city
FROM dbo.route r
JOIN dbo.airline al  ON r.airline_id             = al.airline_id
JOIN dbo.airport src ON r.source_airport_id      = src.airport_id
JOIN dbo.airport dst ON r.destination_airport_id = dst.airport_id
ORDER BY al.name;
