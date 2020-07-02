----------
-- EASY --
----------
-- (Q1)
SELECT	FirstName, 
		Lastname, 
        ClubName
FROM	player LEFT OUTER JOIN 
		(
			SELECT	ClubID, 
					PlayerID, 
                    ClubName 
			FROM	clubplayer NATURAL JOIN club
            WHERE	ToDate IS NULL
		) AS currentclubs ON player.PlayerID = currentclubs.PlayerID
        -- could also use a natural join with playerteam + select distinct to achieve thhe same thing as this where clause
        WHERE player.playerID in (Select PlayerID from playerteam)
ORDER BY
		LastName, 
        FirstName;

-- (Q2)
SELECT	CONCAT(FirstName, ' ', LastName) AS PlayerName 
FROM	player NATURAL JOIN playerteam
WHERE	Sex = 'F' 
GROUP BY 
		PlayerName 
HAVING	COUNT(DISTINCT TeamID) > 1;
        
-- (Q3)
SELECT	CONCAT(FirstName, ' ', LastName) AS PlayerName
FROM	player
WHERE	PlayerID NOT IN 
		(
			SELECT	PlayerID
			FROM	playerteam NATURAL JOIN game NATURAL JOIN season NATURAL JOIN competition
            -- also give marks if used competitionName = 'Bingham Trophy'
			WHERE	CompetitionType = 'Mixed'
		);
        
------------
-- MEDIUM --
------------

-- (Q4)
SELECT	SeasonYear,
		COUNT(*) 
FROM	game NATURAL JOIN season
WHERE	T1Score IS NULL
AND		T2Score IS NULL 
GROUP BY
		SeasonYear
HAVING	COUNT(*) = 
		(
			SELECT	MAX(CancelledGames)
			FROM	(
						SELECT	SeasonYear,
								COUNT(*) as CancelledGames 
						FROM	game NATURAL JOIN season
						WHERE	T1Score IS NULL
						AND		T2Score IS NULL 
						GROUP BY
								SeasonYear			
					) cancelledgames
        );
        
-- (Q5)
SELECT	ClubName, 
		MaleCount, 
        FemaleCount,
        ABS(MaleCount - FemaleCount) as diff
FROM	(
			SELECT	ClubID, 
					COUNT(PlayerID) AS MaleCount
			FROM	clubplayer NATURAL JOIN player
			WHERE	Sex = 'M'
            AND		ToDate IS NULL
			GROUP BY
					ClubID
		) AS MaleList INNER JOIN 
		(
			SELECT	ClubID,
					COUNT(PlayerID) AS FemaleCount
			FROM	clubplayer NATURAL JOIN player
			WHERE	Sex = 'F'
            AND		ToDate IS NULL
			GROUP BY
					ClubID
		) AS FemaleList ON MaleList.ClubID = FemaleList.ClubID INNER JOIN club ON club.ClubID = MaleList.ClubID
WHERE	MaleCount != FemaleCount
ORDER BY
		diff DESC;

-- (Q6)
SELECT	Games2017.PlayerID,
		FirstName,
		Sex,
        IFNULL(GamesIn2018, 0),
        GamesIn2017 
FROM	player NATURAL JOIN		 
        ( 
			SELECT	PlayerID, 
					COUNT(GameID) AS GamesIn2017 
			FROM	playerteam NATURAL JOIN game NATURAL JOIN season 
            -- could also just use the year from the game, the don't need to join season
			WHERE	SeasonYear = 2017 
			GROUP BY
					PlayerID 
		) AS Games2017 LEFT OUTER JOIN
        ( 
			SELECT	PlayerID, 
					COUNT(GameID) AS GamesIn2018 
			FROM	playerteam NATURAL JOIN game NATURAL JOIN season 
            -- could also just use the year from the game, the don't need to join season
			WHERE	SeasonYear = 2018 
			GROUP BY
					PlayerID 
		) AS Games2018 ON Games2018.PlayerID = Games2017.PlayerID
WHERE	IFNULL(GamesIn2018, 0) < GamesIn2017;

-- (Q7)
SELECT	TeamName,
		SUM(Score) AS Score
FROM	(
			SELECT	TeamName,
					T1Score AS Score, 
                    SeasonID, 
                    MatchDate
			FROM	game INNER JOIN team on game.Team1 = team.TeamID
			UNION ALL 
			SELECT	TeamName, 
					T2Score AS Score, 
                    SeasonID, 
                    MatchDate
			FROM game INNER JOIN team on game.Team2 = team.TeamID
		) AS Scorecard NATURAL JOIN season 
		NATURAL JOIN competition
WHERE	CompetitionName = 'Bingham Trophy' 
AND		YEAR(MatchDate) = 2017
-- note can also use 'seasonyear = 2017'
GROUP BY
		TeamName
HAVING	Score > 100
ORDER BY
		Score DESC;

----------
-- HARD --
----------
-- (Q8)
SELECT	CONCAT(FirstName, ' ', LastName) AS PlayerName,
		NumberOfDays
FROM	player INNER JOIN 
		(	
			SELECT	PlayerID, 
					ClubName,
					SUM(CASE 
							WHEN ISNULL(ToDate) THEN DATEDIFF('2020-4-30', FromDate)
							ELSE DATEDIFF(ToDate, FromDate)
						END) AS NumberOfDays
			FROM	clubplayer INNER JOIN club ON clubplayer.ClubID = club.ClubID
			WHERE	ClubName = 'Melbourne City'
			GROUP BY 
					PlayerID
		) as playerdays ON player.PlayerID = playerdays.PlayerID
ORDER BY
		NumberOfDays ASC
LIMIT 1;

-- (Q9)
SELECT 
    playergames.FirstName,
    playergames.lastname,
    clubplayer.PlayerID,
    COUNT(*) AS otherteamgames
FROM
    (
		SELECT	PlayerID,
				FirstName,
                LastName,
                playerteam.GameID,
                MatchDate,
                ClubID
		FROM	playerteam NATURAL JOIN game 
				NATURAL JOIN team 
				NATURAL JOIN player
	) AS playergames
	INNER JOIN clubplayer ON clubplayer.PlayerID = playergames.PlayerID AND playergames.ClubID != clubplayer.ClubID
WHERE	FromDate < MatchDate
AND		(ToDate IS NULL OR ToDate > MatchDate)
GROUP BY
		PlayerID, 
        playergames.FirstName,
        playergames.LastName,
        clubplayer.PlayerID
ORDER BY
		otherteamgames DESC
LIMIT 20;

-- (Q10)
-- NOTE: for this question, since a team can only participate in ONE season per year currently (eg if its a mixed team, can only participate in the Bingham trophy) it is
-- sufficient to be only using SeasonYear rather than SeasonID when doing a groupby. Solutions for both methods are below:

-- First version: the 'correct'/ as the spec reads version, grouping by SeasonID
SELECT	TeamName,
		maxNumberOfWalkovers, 
        SeasonYear
FROM	Team NATURAL JOIN 
		(
			SELECT	maxseasonteamwalkovers.teamID,
					maxseasonteamwalkovers.maxNumberOfWalkovers,
                    teamwalkoversperseason.SeasonID 
			FROM	(
						SELECT	TeamID, 
								COUNT(*) AS numberOfWalkovers,
                                SeasonID
						FROM	(
									SELECT	TeamID AS teamID,
											T1Score AS teamscore,
											T2Score AS opponentscore,
                                            SeasonID
									FROM	game NATURAL JOIN season
											INNER JOIN team ON game.Team1 = team.TeamID
									UNION ALL -- or UNION
									SELECT	TeamID AS teamID, 
											T2Score AS teamscore,
											T1Score AS opponentscore,
                                            SeasonID
									FROM	game NATURAL JOIN season
											INNER JOIN team ON game.Team2 = team.TeamID
								) AS teamgamescores
						WHERE	teamscore = 0
                        AND		opponentscore = 28
						GROUP BY
								teamID, 
                                SeasonID
						HAVING	COUNT(*) > 1 
				) AS teamwalkoversperseason INNER JOIN 
                (
					SELECT	teamID,
							MAX(numberOfWalkovers) AS maxNumberOfWalkovers
					FROM	(
							SELECT	TeamID, 
									COUNT(*) AS numberOfWalkovers,
									SeasonID
							FROM	(
										SELECT	TeamID AS teamID,
												T1Score AS teamscore,
												T2Score AS opponentscore,
												SeasonID
										FROM	game NATURAL JOIN season
												INNER JOIN team ON game.Team1 = team.TeamID
										UNION ALL -- or UNION
										SELECT	TeamID AS teamID, 
												T2Score AS teamscore,
												T1Score AS opponentscore,
												SeasonID
										FROM	game NATURAL JOIN season
												INNER JOIN team ON game.Team2 = team.TeamID
									) AS teamgamescores
							WHERE	teamscore = 0
							AND		opponentscore = 28
							GROUP BY
									teamID, 
									SeasonID
							HAVING	COUNT(*) > 1 
					) AS teamwalkoversperseason
					GROUP BY teamID
				) AS maxseasonteamwalkovers ON maxseasonteamwalkovers.teamID = teamwalkoversperseason.teamID AND teamwalkoversperseason.numberOfWalkovers = maxseasonteamwalkovers.maxNumberOfWalkovers
		) AS maxteamwalkoversperyear Natural Join season;

-- The second version of Q10 solution, Grouping by SeasonYear instead (this still works, read above note)
SELECT	TeamName,
		maxNumberOfWalkovers, 
        SeasonYear 
FROM	Team NATURAL JOIN 
		(
			SELECT	maxyearlyteamwalkovers.teamID,
					maxyearlyteamwalkovers.maxNumberOfWalkovers,
                    teamwalkoversperyear.SeasonYear 
			FROM	(
						SELECT	TeamID, 
								COUNT(*) AS numberOfWalkovers,
                                SeasonYear
						FROM	(
									SELECT	TeamID AS teamID,
											T1Score AS teamscore,
											T2Score AS opponentscore, 
                                            SeasonYear
									FROM	game NATURAL JOIN season
											INNER JOIN team ON game.Team1 = team.TeamID
									UNION ALL -- or UNION
									SELECT	TeamID AS teamID, 
											T2Score AS teamscore,
											T1Score AS opponentscore, 
                                            SeasonYear
									FROM	game NATURAL JOIN season
											INNER JOIN team ON game.Team2 = team.TeamID
								) AS teamgamescores
						WHERE	teamscore = 0
                        AND		opponentscore = 28
						GROUP BY
								teamID, 
                                SeasonYear
						HAVING	COUNT(*) > 1 
				) AS teamwalkoversperyear INNER JOIN 
                (
					SELECT	teamID,
							MAX(numberOfWalkovers) AS maxNumberOfWalkovers
					FROM	(
								SELECT	teamID, 
										COUNT(*) as numberOfWalkovers,
                                        SeasonYear
								FROM	(
											SELECT 	TeamID as teamID, 
													T1Score AS teamscore,
													T2Score AS opponentscore, 
                                                    SeasonYear
											FROM	game NATURAL JOIN season
													INNER JOIN team ON game.Team1 = team.TeamID
											UNION ALL -- or UNION
											SELECT	TeamID as teamID,
													T2Score AS teamscore,
													T1Score AS opponentscore, 
                                                    SeasonYear
											FROM	game NATURAL JOIN season
													INNER JOIN team ON game.Team2 = team.TeamID
										) AS teamgamescores
								WHERE	teamscore = 0
                                AND		opponentscore = 28
								GROUP BY
										teamID, 
                                        SeasonYear
								HAVING	COUNT(*) > 1 
							) AS teamwalkoversperyear
					GROUP BY teamID
				) AS maxyearlyteamwalkovers ON maxyearlyteamwalkovers.teamID = teamwalkoversperyear.teamID AND teamwalkoversperyear.numberOfWalkovers = maxyearlyteamwalkovers.maxNumberOfWalkovers
		) AS maxteamwalkoversperyear;