export type LeaderboardRow = {
    userId: number,
    rank: number,
    value: number,
}

export type PlayerLeaderboardRow = {
    userId: number,
    rank: number?,
    value: number,
}

export type LeaderboardBoard = {
    top: { LeaderboardRow },
    you: PlayerLeaderboardRow?,
}

export type LeaderboardTopRows = { LeaderboardRow }

export type LeaderboardPayload = {
    Level: LeaderboardTopRows,
    RobuxSpent: LeaderboardTopRows,
    TimeSpent: LeaderboardTopRows,
    Wins: LeaderboardTopRows,
}

export type State = {
    [string]: LeaderboardTopRows,
}

export type PlayerStats = {
    Level: number,
    RobuxSpent: number,
    TimeSpent: number,
    Wins: number,
}

return {}