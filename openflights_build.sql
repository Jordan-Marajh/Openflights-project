/* =====================================================================
   OpenFlights  -  COMPLETE BUILD IN ONE SCRIPT 
   RETARGETED to Jordan's cleaned CSVs (github.com/Jordan-Marajh).

   Differences from the notebook version this replaces:
     - column names are entity-prefixed (airport_name, plane_name, ...)
     - the country FK column is named  iso_code  (not country_iso_code)
     - timezone column is  tz_database_time_zone
     - plane column order is  iata_code, name, icao_code
     - four columns are NOT present in Jordan's data and so are omitted:
         country.dafif_code,  airport.type,  airport.source,  route.codeshare
  

   Files expected (exact names from his repo):
     countries.csv  planes.csv  airports.csv
     airlines.csv   routes.csv  route_equipment.csv

   @authors
   Chan, Emily, Jordan, Michael
   ===================================================================== */


/* ---------- SECTION 1 : DATABASE ---------- */
IF DB_ID('OpenFlights') IS NULL
    CREATE DATABASE OpenFlights;
GO
USE OpenFlights;
GO


/* ---------- SECTION 2 : TABLES (PK + types, no FKs yet) ----------
   Column ORDER matches Jordan's CSV headers (BULK INSERT is positional). */

IF OBJECT_ID('dbo.route_equipment','U') IS NOT NULL DROP TABLE dbo.route_equipment;
IF OBJECT_ID('dbo.route','U')           IS NOT NULL DROP TABLE dbo.route;
IF OBJECT_ID('dbo.airport','U')         IS NOT NULL DROP TABLE dbo.airport;
IF OBJECT_ID('dbo.airline','U')         IS NOT NULL DROP TABLE dbo.airline;
IF OBJECT_ID('dbo.plane','U')           IS NOT NULL DROP TABLE dbo.plane;
IF OBJECT_ID('dbo.country','U')         IS NOT NULL DROP TABLE dbo.country;
GO

CREATE TABLE dbo.country (
    iso_code      CHAR(2)       NOT NULL,   -- ISO 3166-1 alpha-2, natural PK
    country_name  VARCHAR(100)  NOT NULL,
    CONSTRAINT PK_country      PRIMARY KEY (iso_code),
    CONSTRAINT UQ_country_name UNIQUE (country_name)
);

CREATE TABLE dbo.plane (
    plane_iata_code  CHAR(3)       NOT NULL,   -- IATA aircraft type code, natural PK
    plane_name       VARCHAR(100)  NOT NULL,
    plane_icao_code  VARCHAR(4)    NULL,
    CONSTRAINT PK_plane PRIMARY KEY (plane_iata_code)
);

CREATE TABLE dbo.airport (
    airport_id             INT           NOT NULL,
    airport_name           VARCHAR(150)  NOT NULL,
    city                   VARCHAR(100)  NULL,
    iso_code               CHAR(2)       NULL,   -- FK -> country.iso_code; nullable (168 didn't resolve)
    iata_code              CHAR(3)       NULL,
    icao_code              VARCHAR(4)    NULL,
    latitude               DECIMAL(9,6)  NULL,
    longitude              DECIMAL(9,6)  NULL,
    altitude               INT           NULL,   -- feet
    timezone_offset        DECIMAL(4,2)  NULL,   -- hours from UTC
    dst                    CHAR(1)       NULL,
    tz_database_time_zone  VARCHAR(50)   NULL,   -- Olson tz
    CONSTRAINT PK_airport PRIMARY KEY (airport_id)
);

CREATE TABLE dbo.airline (
    airline_id     INT           NOT NULL,
    airline_name   VARCHAR(150)  NOT NULL,
    alias          VARCHAR(100)  NULL,
    iata_code      VARCHAR(3)    NULL,   -- 1-3 chars in data, so VARCHAR
    icao_code      VARCHAR(5)    NULL,   -- 2-5 chars in data, so VARCHAR
    callsign       VARCHAR(100)  NULL,
    iso_code       CHAR(2)       NULL,   -- FK -> country.iso_code; nullable (245 didn't resolve)
    active         CHAR(1)       NULL,   -- 'Y' / 'N'
    CONSTRAINT PK_airline PRIMARY KEY (airline_id)
);

CREATE TABLE dbo.route (
    route_id               INT  NOT NULL,
    airline_id             INT  NULL,   -- FK -> airline
    source_airport_id      INT  NULL,   -- FK -> airport
    destination_airport_id INT  NULL,   -- FK -> airport (second reference)
    stops                  INT  NULL,   -- 0 = direct
    CONSTRAINT PK_route PRIMARY KEY (route_id)
);

CREATE TABLE dbo.route_equipment (   -- bridge: route <-> plane many-to-many
    route_id         INT      NOT NULL,
    plane_iata_code  CHAR(3)  NOT NULL,
    CONSTRAINT PK_route_equipment PRIMARY KEY (route_id, plane_iata_code)
);
GO


/* ---------- SECTION 3 : LOAD via BULK INSERT ----------
   Options tuned to Jordan's files: FORMAT='CSV' (quoted commas),
   FIRSTROW=2 (skip header), ROWTERMINATOR=0x0a (LF), CODEPAGE='65001'
   (UTF-8 accents), KEEPNULLS (empty -> NULL). */

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

-- Safety net: force empty country codes to NULL before the FK gate
UPDATE dbo.airport SET iso_code = NULL WHERE iso_code = '';
UPDATE dbo.airline SET iso_code = NULL WHERE iso_code = '';
GO


/* ---------- SECTION 4 : FOREIGN KEYS  (integrity gate) ---------- */
ALTER TABLE dbo.airport
    ADD CONSTRAINT FK_airport_country
    FOREIGN KEY (iso_code) REFERENCES dbo.country (iso_code);

ALTER TABLE dbo.airline
    ADD CONSTRAINT FK_airline_country
    FOREIGN KEY (iso_code) REFERENCES dbo.country (iso_code);

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
    FOREIGN KEY (plane_iata_code) REFERENCES dbo.plane (plane_iata_code);
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
       al.airline_name AS airline,
       src.iata_code   AS from_iata,
       dst.iata_code   AS to_iata,
       src.city        AS from_city,
       dst.city        AS to_city
FROM dbo.route r
JOIN dbo.airline al  ON r.airline_id             = al.airline_id
JOIN dbo.airport src ON r.source_airport_id      = src.airport_id
JOIN dbo.airport dst ON r.destination_airport_id = dst.airport_id
ORDER BY al.airline_name;
