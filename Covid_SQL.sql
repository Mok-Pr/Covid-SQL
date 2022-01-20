-- Check columns
exec sp_columns CovidInfectsAndDeaths
exec sp_columns CovidVaccinations

-- Death Percentage (total deaths vs total cases) in Thailand
SELECT location, CONVERT(date, date) AS date, total_cases, total_deaths, (total_deaths/total_cases)*100 AS death_percentage
FROM MokProject..CovidInfectsAndDeaths
WHERE location LIKE 'thai%'
ORDER BY date

-- Infection rate per population in each countries using CTE
WITH InfectRate (location, date, total_cases, population) AS
(
SELECT inf.location, inf.date, inf.total_cases, vac.population
FROM MokProject..CovidInfectsAndDeaths inf
JOIN MokProject..CovidVaccinations vac
	ON inf.location = vac.location
	AND inf.date = vac.date
WHERE inf.continent IS NOT NULL
) 
SELECT location, population, MAX(total_cases) AS total_infection_count, MAX((total_cases/population))*100 AS population_infected_percentage
FROM InfectRate
GROUP BY location, population
ORDER BY population_infected_percentage DESC

-- Create temp table for storing specific columns
DROP TABLE IF EXISTS #InfectAndVac
CREATE TABLE #InfectAndVac
(
continent nvarchar(60),
location nvarchar(60),
date datetime,
total_deaths int,
population int,
new_vaccinations int
)
INSERT INTO #InfectAndVac
SELECT inf.continent, inf.location, inf.date, inf.total_deaths, vac.population, CONVERT(int, vac.new_vaccinations)
FROM MokProject..CovidInfectsAndDeaths inf
JOIN MokProject..CovidVaccinations vac
	ON inf.location = vac.location
	AND inf.date = vac.date
WHERE inf.continent IS NOT NULL

-- 20 countries with highest death count per population
SELECT TOP(20) location, MAX(CAST(total_deaths AS int)) AS total_death_count
FROM #InfectAndVac
GROUP BY location
ORDER BY total_death_count DESC

-- Drop total_deaths column
ALTER TABLE #InfectAndVac
DROP COLUMN total_deaths

-- New vaccinated people added in each day
SELECT *, SUM(new_vaccinations) OVER (PARTITION BY location ORDER BY location, date) AS increment_vaccination_count
FROM #InfectAndVac

DROP TABLE #InfectAndVac


-- Graphs --
-- Graph 1: stringency index vs new cases
SELECT inf.location, CONVERT(date, inf.date) AS date, vac.stringency_index, inf.new_cases
FROM MokProject..CovidInfectsAndDeaths inf
JOIN MokProject..CovidVaccinations vac
	ON inf.location = vac.location 
	AND inf.date = vac.date
WHERE inf.continent IS NOT NULL AND vac.stringency_index IS NOT NULL AND inf.new_cases IS NOT NULL
ORDER BY 1, 2

-- Graph 2: Thailand, Asia and world table
SELECT location, MAX(total_cases) AS total_cases, MAX(CAST(total_deaths AS int)) AS total_deaths, MAX(CAST(total_deaths AS int))/MAX(total_cases)*100 AS death_percentage
FROM MokProject..CovidInfectsAndDeaths
WHERE location IN ('world', 'asia', 'thailand')
GROUP BY location
ORDER BY 2

-- Graph 3: People vaccinated bar 
SELECT location, ISNULL(MAX(CAST(people_vaccinated AS float)), 0) AS people_vaccinated
FROM MokProject..CovidVaccinations
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY people_vaccinated DESC

-- Graph 4: Deaths percentage world map
SELECT inf.location, vac.population, ISNULL(MAX(inf.total_cases), 0) AS highest_infection_count, ISNULL(MAX(inf.total_cases/vac.population), 0)*100 AS population_infected_percentage
FROM MokProject..CovidInfectsAndDeaths inf
JOIN MokProject..CovidVaccinations vac
	ON inf.location = vac.location 
	AND inf.date = vac.date
WHERE inf.continent IS NOT NULL
GROUP BY inf.location, vac.population
ORDER BY population_infected_percentage DESC
