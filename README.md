# Openflights Database Project

This project uses the data available at [Openflights](https://openflights.org/data.php) to create an SQL database.

## How to use this project

1. Create a folder called `raw` and download the following files from the Openflights website:
- [airports.dat](https://raw.githubusercontent.com/jpatokal/openflights/master/data/airports.dat)
- [airlines.dat](https://raw.githubusercontent.com/jpatokal/openflights/master/data/airlines.dat)
- [routes.dat](https://raw.githubusercontent.com/jpatokal/openflights/master/data/routes.dat)
- [planes.dat](https://raw.githubusercontent.com/jpatokal/openflights/master/data/planes.dat)
- [countries.dat](https://raw.githubusercontent.com/jpatokal/openflights/master/data/countries.dat)

2. Run the [Openflights Cleaning Notebook](Openflights-project\openflights_cleaning_notebook.ipynb) to clean the data ready for importing into SQL

3. Run the SQL file to create the database and import data