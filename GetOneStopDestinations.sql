USE OpenFlights;
GO

/* =====================================================================
   STORED PROCEDURE: GetOneStopDestinations

   A stored procedure is a SQL query we save in the database and run by
   name. We can reuse it with different inputs, so we write this logic
   once and just call it for any airport instead of rewriting the query.

   WHAT IT DOES:
     You give it an airport code (e.g. 'LHR' = London Heathrow).
     It returns the places you CANNOT fly to directly from there,
     but CAN reach by taking ONE connecting flight.

     Example: Heathrow flies direct to 170 airports. Take one stop and
     roughly 1,758 more open up - this SP lists those extra places,
     and how many different connecting airports get you to each one.
   ===================================================================== */

CREATE OR ALTER PROCEDURE dbo.GetOneStopDestinations
    @StartIata CHAR(3)        -- INPUT: the airport we start from, e.g. 'LHR'
AS
BEGIN
    SET NOCOUNT ON;           -- hides the "(x rows affected)" messages so the output stays clean

    /* -----------------------------------------------------------------
       STEP 1 - Turn the airport CODE into its ID number.
       The route table stores airports as ID numbers, not 3-letter codes,
       so first we look up the ID for the code the user typed in.
       ----------------------------------------------------------------- */
    DECLARE @StartAirportId INT;

    SELECT @StartAirportId = airport_id
    FROM dbo.airport
    WHERE iata_code = @StartIata;

    /* -----------------------------------------------------------------
       STEP 2 - Find the one-stop destinations.
       A one-stop trip is two flights:  START -> STOPOVER -> DESTINATION.
       To build that we use the route table TWICE (a "self-join"):
         leg1 = the first flight  (leaves our start airport)
         leg2 = the second flight (leaves wherever leg1 landed)
       We connect them by matching leg1's landing airport to leg2's
       take-off airport.
       ----------------------------------------------------------------- */
    SELECT TOP (50)
        dest.iata_code    AS reachable_airport,
        dest.airport_name,
        dest.city,
        c.country_name,
        -- how many different stopover airports can get us to this destination:
        COUNT(DISTINCT leg1.destination_airport_id) AS possible_stopovers
    FROM dbo.route AS leg1                 -- first flight:  start -> stopover
    JOIN dbo.route AS leg2                 -- second flight: stopover -> destination
        ON leg1.destination_airport_id = leg2.source_airport_id
    JOIN dbo.airport AS dest              -- look up the destination's name and city
        ON leg2.destination_airport_id = dest.airport_id
    LEFT JOIN dbo.country AS c            -- add its country (LEFT JOIN keeps the row even if no country matched)
        ON dest.iso_code = c.iso_code
    WHERE
        -- the first flight must start at our chosen airport
        leg1.source_airport_id = @StartAirportId

        -- ignore trips that just fly us back to where we started
        AND leg2.destination_airport_id <> @StartAirportId

        -- skip anywhere we can ALREADY reach on a direct flight
        AND leg2.destination_airport_id NOT IN (
            SELECT destination_airport_id
            FROM dbo.route
            WHERE source_airport_id = @StartAirportId
        )
    -- one row per destination, so COUNT can tally each one's stopovers
    GROUP BY dest.iata_code, dest.airport_name, dest.city, c.country_name
    -- show the best-connected destinations first
    ORDER BY possible_stopovers DESC;
END;
GO

/* Run the procedure - each call reuses the same saved logic: */
EXEC dbo.GetOneStopDestinations @StartIata = 'LHR';   -- London Heathrow
EXEC dbo.GetOneStopDestinations @StartIata = 'JFK';   -- New York JFK
-- EXEC dbo.GetOneStopDestinations @StartIata = 'CDG'; -- Paris CDG
-- EXEC dbo.GetOneStopDestinations @StartIata = 'DXB'; -- Dubai
