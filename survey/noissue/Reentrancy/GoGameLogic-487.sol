/// @title The actual game logic for EthernalGo - setting stones, capturing, etc.
/// @author https://www.EthernalGo.com
contract GoGameLogic is GoBoardMetaDetails {

    /// @dev The StoneAddedToBoard event is fired when a new stone is added to the board, 
    ///  and includes the board Id, stone color, row & column. This event will fire even if it was a suicide stone.
    event StoneAddedToBoard(uint boardId, PlayerColor color, uint8 row, uint8 col);

    /// @dev The PlayerPassedTurn event is fired when a player passes turn 
    ///  and includes the board Id, color.
    event PlayerPassedTurn(uint boardId, PlayerColor color);
    
    /// @dev Updating the player's time periods left, according to the current time - board last update time.
    ///  If the player does not have enough time and chose to act, the game will end and the player will lose.
    /// @param board is the relevant board.
    /// @param boardId is the board's Id.
    /// @param color is the color of the player we want to update.
    /// @return true if the player can continue playing, otherwise false.
    function updatePlayerTime(GoBoard storage board, uint boardId, PlayerColor color) private returns(bool) {

        // Verify that the board is in progress and that it's the current player
        require(board.status == BoardStatus.InProgress && board.nextTurnColor == color);

        // Calculate time periods used by the player
        uint timePeriodsUsed = uint(now.sub(board.lastUpdate).div(PLAYER_TURN_SINGLE_PERIOD));

        // Subtract time periods if needed
        if (timePeriodsUsed > 0) {

            // Can't spend more than MAX_UINT8
            updatePlayerTimePeriods(board, color, timePeriodsUsed > MAX_UINT8 ? MAX_UINT8 : uint8(timePeriodsUsed));

            // The player losses when there aren't any time periods left
            if (getPlayerTimePeriods(board, color) == 0) {
                playerLost(board, boardId, color);
                return false;
            }
        }

        return true;
    }

    /// @notice Updates the board status according to the players score.
    ///  Can only be called when the board is in a 'waitingToResolve' status.
    /// @param boardId is the board to check and update
    function checkVictoryByScore(uint boardId) external boardWaitingToResolve(boardId) {
        
        uint8 blackScore;
        uint8 whiteScore;

        // Get the players' score
        (blackScore, whiteScore) = calculateBoardScore(boardId);

        // Default to Draw
        BoardStatus status = BoardStatus.Draw;

        // If black's score is bigger than white's score, black is the winner
        if (blackScore > whiteScore) {

            status = BoardStatus.BlackWin;
        // If white's score is bigger, white is the winner
        } else if (whiteScore > blackScore) {

            status = BoardStatus.WhiteWin;
        }

        // Update the board's status
        updateBoardStatus(boardId, status);
    }

    /// @notice Performs a pass action on a psecific board, only by the current active color player.
    /// @param boardId is the board to perform pass on.
    function passTurn(uint boardId) external {

        // Get the board & player
        GoBoard storage board = allBoards[boardId];
        PlayerColor activeColor = getPlayerColor(board, msg.sender);

        // Verify the player can act
        require(board.status == BoardStatus.InProgress && board.nextTurnColor == activeColor);
        
        // Check if this player can act
        if (updatePlayerTime(board, boardId, activeColor)) {

            // If it's the second straight pass, the game is over
            if (board.didPassPrevTurn) {

                // Finishing the game like this is considered honorable
                board.isHonorableLoss = true;

                // On second pass, the board status changes to 'WaitingToResolve'
                updateBoardStatus(board, boardId, BoardStatus.WaitingToResolve);

            // If it's the first pass, we can simply continue
            } else {

                // Move to the next player, flag that it was a pass action
                nextTurn(board);
                board.didPassPrevTurn = true;

                // Notify the player passed turn
                PlayerPassedTurn(boardId, activeColor);
            }
        }
    }

    /// @notice Resigns a player from a specific board, can get called by either player on the board.
    /// @param boardId is the board to resign from.
    function resignFromMatch(uint boardId) external {

        // Get the board, make sure it's in progress
        GoBoard storage board = allBoards[boardId];
        require(board.status == BoardStatus.InProgress);

        // Get the sender's color
        PlayerColor activeColor = getPlayerColor(board, msg.sender);
                
        // Finishing the game like this is considered honorable
        board.isHonorableLoss = true;

        // Set that color as the losing player
        playerLost(board, boardId, activeColor);
    }

    /// @notice Claiming the current acting player on the board is out of time, thus losses the game.
    /// @param boardId is the board to claim it on.
    function claimActingPlayerOutOfTime(uint boardId) external {

        // Get the board, make sure it's in progress
        GoBoard storage board = allBoards[boardId];
        require(board.status == BoardStatus.InProgress);

        // Get the acting player color
        PlayerColor actingPlayerColor = getNextTurnColor(boardId);

        // Calculate remaining allowed time for the acting player
        uint playerTimeRemaining = PLAYER_TURN_SINGLE_PERIOD * getPlayerTimePeriods(board, actingPlayerColor);

        // If the player doesn't have enough time left, the player losses
        if (playerTimeRemaining < now - board.lastUpdate) {
            playerLost(board, boardId, actingPlayerColor);
        }
    }

    /// @dev Update a board status with a losing color
    /// @param board is the board to update.
    /// @param boardId is the board's Id.
    /// @param color is the losing player's color.
    function playerLost(GoBoard storage board, uint boardId, PlayerColor color) private {

        // If black is the losing color, white wins
        if (color == PlayerColor.Black) {
            updateBoardStatus(board, boardId, BoardStatus.WhiteWin);
        
        // If white is the losing color, black wins
        } else if (color == PlayerColor.White) {
            updateBoardStatus(board, boardId, BoardStatus.BlackWin);

        // There's an error, revert
        } else {
            revert();
        }
    }

    /// @dev Internally used to move to the next turn, by switching sides and updating the board last update time.
    /// @param board is the board to update.
    function nextTurn(GoBoard storage board) private {
        
        // Switch sides
        board.nextTurnColor = board.nextTurnColor == PlayerColor.Black ? PlayerColor.White : PlayerColor.Black;

        // Last update time
        board.lastUpdate = now;
    }
    
    /// @notice Adding a stone to a specific board and position (row & col).
    ///  Requires the board to be in progress, that the caller is the acting player, 
    ///  and that the spot on the board is empty.
    /// @param boardId is the board to add the stone to.
    /// @param row is the row for the new stone.
    /// @param col is the column for the new stone.
    function addStoneToBoard(uint boardId, uint8 row, uint8 col) external {
        
        // Get the board & sender's color
        GoBoard storage board = allBoards[boardId];
        PlayerColor activeColor = getPlayerColor(board, msg.sender);

        // Verify the player can act
        require(board.status == BoardStatus.InProgress && board.nextTurnColor == activeColor);

        // Calculate the position
        uint8 position = row * BOARD_ROW_SIZE + col;
        
        // Check that it's an empty spot
        require(board.positionToColor[position] == 0);

        // Update the player timeout (if the player doesn't have time left, discontinue)
        if (updatePlayerTime(board, boardId, activeColor)) {

            // Set the stone on the board
            board.positionToColor[position] = uint8(activeColor);

            // Run capture / suidice logic
            updateCaptures(board, position, uint8(activeColor));
            
            // Next turn logic
            nextTurn(board);

            // Clear the pass flag
            if (board.didPassPrevTurn) {
                board.didPassPrevTurn = false;
            }

            // Fire the event
            StoneAddedToBoard(boardId, activeColor, row, col);
        }
    }

    /// @notice Returns a board's row details, specifies which color occupies which cell in that row.
    /// @dev It returns a row and not the entire board because some nodes might fail to return arrays larger than ~50.
    /// @param boardId is the board to inquire.
    /// @param row is the row to get details on.
    /// @return an array that contains the colors occupying each cell in that row.
    function getBoardRowDetails(uint boardId, uint8 row) external view returns (uint8[BOARD_ROW_SIZE]) {
        
        // The array to return
        uint8[BOARD_ROW_SIZE] memory rowToReturn;

        // For all columns, calculate the position and get the current status
        for (uint8 col = 0; col < BOARD_ROW_SIZE; col++) {
            
            uint8 position = row * BOARD_ROW_SIZE + col;
            rowToReturn[col] = allBoards[boardId].positionToColor[position];
        }

        // Return the array
        return (rowToReturn);
    }

    /// @notice Returns the current color of a specific position in a board.
    /// @param boardId is the board to inquire.
    /// @param row is part of the position to get details on.
    /// @param col is part of the position to get details on.
    /// @return the color occupying that position.
    function getBoardSingleSpaceDetails(uint boardId, uint8 row, uint8 col) external view returns (uint8) {

        uint8 position = row * BOARD_ROW_SIZE + col;
        return allBoards[boardId].positionToColor[position];
    }

    /// @dev Calcultes whether a position captures an enemy group, or whether it's a suicide. 
    ///  Updates the board accoridngly (clears captured groups, or the suiciding stone).
    /// @param board the board to check and update
    /// @param position the position of the new stone
    /// @param positionColor the color of the new stone (this param is sent to spare another reading op)
    function updateCaptures(GoBoard storage board, uint8 position, uint8 positionColor) private {

        // Group positions, used later
        uint8[BOARD_SIZE] memory group;

        // Is group captured, or free
        bool isGroupCaptured;

        // In order to save gas, we check suicide only if the position is fully surrounded and doesn't capture enemy groups 
        bool shouldCheckSuicide = true;

        // Get the position's adjacent cells
        uint8[MAX_ADJACENT_CELLS] memory adjacentArray = getAdjacentCells(position);

        // Run as long as there an adjacent cell, or until we reach the end of the array
        for (uint8 currAdjacentIndex = 0; currAdjacentIndex < MAX_ADJACENT_CELLS && adjacentArray[currAdjacentIndex] < MAX_UINT8; currAdjacentIndex++) {

            // Get the adjacent cell's color
            uint8 currColor = board.positionToColor[adjacentArray[currAdjacentIndex]];

            // If the enemy's color
            if (currColor != 0 && currColor != positionColor) {

                // Get the group's info
                (group, isGroupCaptured) = getGroup(board, adjacentArray[currAdjacentIndex], currColor);

                // Captured a group
                if (isGroupCaptured) {
                    
                    // Clear the group from the board
                    for (uint8 currGroupIndex = 0; currGroupIndex < BOARD_SIZE && group[currGroupIndex] < MAX_UINT8; currGroupIndex++) {

                        board.positionToColor[group[currGroupIndex]] = 0;
                    }

                    // Shouldn't check suicide
                    shouldCheckSuicide = false;
                }
            // There's an empty adjacent cell
            } else if (currColor == 0) {

                // Shouldn't check suicide
                shouldCheckSuicide = false;
            }
        }

        // Detect suicide if needed
        if (shouldCheckSuicide) {

            // Get the new stone's surrounding group
            (group, isGroupCaptured) = getGroup(board, position, positionColor);

            // If the group is captured, it's a suicide move, remove it
            if (isGroupCaptured) {

                // Clear added stone
                board.positionToColor[position] = 0;
            }
        }
    }

    /// @dev Internally used to set a flag in a shrinked board array (used to save gas costs).
    /// @param visited the array to update.
    /// @param position the position on the board we want to flag.
    /// @param flag the flag we want to set (either 1 or 2).
    function setFlag(uint8[SHRINKED_BOARD_SIZE] visited, uint8 position, uint8 flag) private pure {
        visited[position / 4] |= flag << ((position % 4) * 2);
    }

    /// @dev Internally used to check whether a flag in a shrinked board array is set.
    /// @param visited the array to check.
    /// @param position the position on the board we want to check.
    /// @param flag the flag we want to check (either 1 or 2).
    /// @return true if that flag is set, false otherwise.
    function isFlagSet(uint8[SHRINKED_BOARD_SIZE] visited, uint8 position, uint8 flag) private pure returns (bool) {
        return (visited[position / 4] & (flag << ((position % 4) * 2)) > 0);
    }

    // Get group visited flags
    uint8 constant FLAG_POSITION_WAS_IN_STACK = 1;
    uint8 constant FLAG_DID_VISIT_POSITION = 2;

    /// @dev Gets a group starting from the position & color sent. In order for a stone to be part of the group,
    ///  it must match the original stone's color, and be connected to it - either directly, or through adjacent cells.
    ///  A group is captured if there aren't any empty cells around it.
    ///  The function supports both returning colored groups - white/black, and empty groups (for that case, isGroupCaptured isn't relevant).
    /// @param board the board to check and update
    /// @param position the position of the starting stone
    /// @param positionColor the color of the starting stone (this param is sent to spare another reading op)
    /// @return an array that contains the positions of the group, 
    ///  a boolean that specifies whether the group is captured or not.
    ///  In order to save gas, if a group isn't captured, the array might not contain the enitre group.
    function getGroup(GoBoard storage board, uint8 position, uint8 positionColor) private view returns (uint8[BOARD_SIZE], bool isGroupCaptured) {

        // The return array, and its size
        uint8[BOARD_SIZE] memory groupPositions;
        uint8 groupSize = 0;
        
        // Flagging visited locations
        uint8[SHRINKED_BOARD_SIZE] memory visited;

        // Stack of waiting positions, the first position to check is the sent position
        uint8[BOARD_SIZE] memory stack;
        stack[0] = position;
        uint8 stackSize = 1;

        // That position was added to the stack
        setFlag(visited, position, FLAG_POSITION_WAS_IN_STACK);

        // Run as long as there are positions in the stack
        while (stackSize > 0) {

            // Take the last position and clear it
            position = stack[--stackSize];
            stack[stackSize] = 0;

            // Only if we didn't visit that stone before
            if (!isFlagSet(visited, position, FLAG_DID_VISIT_POSITION)) {
                
                // Set the flag so we won't visit it again
                setFlag(visited, position, FLAG_DID_VISIT_POSITION);

                // Add that position to the return value
                groupPositions[groupSize++] = position;

                // Get that position adjacent cells
                uint8[MAX_ADJACENT_CELLS] memory adjacentArray = getAdjacentCells(position);

                // Run over the adjacent cells
                for (uint8 currAdjacentIndex = 0; currAdjacentIndex < MAX_ADJACENT_CELLS && adjacentArray[currAdjacentIndex] < MAX_UINT8; currAdjacentIndex++) {
                    
                    // Get the current adjacent cell color
                    uint8 currColor = board.positionToColor[adjacentArray[currAdjacentIndex]];
                    
                    // If it's the same color as the original position color
                    if (currColor == positionColor) {

                        // Add that position to the stack
                        if (!isFlagSet(visited, adjacentArray[currAdjacentIndex], FLAG_POSITION_WAS_IN_STACK)) {
                            stack[stackSize++] = adjacentArray[currAdjacentIndex];
                            setFlag(visited, adjacentArray[currAdjacentIndex], FLAG_POSITION_WAS_IN_STACK);
                        }
                    // If that position is empty, the group isn't captured, no need to continue running
                    } else if (currColor == 0) {
                        
                        return (groupPositions, false);
                    }
                }
            }
        }

        // Flag the end of the group array only if needed
        if (groupSize < BOARD_SIZE) {
            groupPositions[groupSize] = MAX_UINT8;
        }
        
        // The group is captured, return it
        return (groupPositions, true);
    }
    
    /// The max number of adjacent cells is 4
    uint8 constant MAX_ADJACENT_CELLS = 4;

    /// @dev returns the adjacent positions for a given position.
    /// @param position to get its adjacents.
    /// @return the adjacent positions array, filled with MAX_INT8 in case there aren't 4 adjacent positions.
    function getAdjacentCells(uint8 position) private pure returns (uint8[MAX_ADJACENT_CELLS]) {

        // Init the return array and current index
        uint8[MAX_ADJACENT_CELLS] memory returnCells = [MAX_UINT8, MAX_UINT8, MAX_UINT8, MAX_UINT8];
        uint8 adjacentCellsIndex = 0;

        // Set the up position, if relevant
        if (position / BOARD_ROW_SIZE > 0) {
            returnCells[adjacentCellsIndex++] = position - BOARD_ROW_SIZE;
        }

        // Set the down position, if relevant
        if (position / BOARD_ROW_SIZE < BOARD_ROW_SIZE - 1) {
            returnCells[adjacentCellsIndex++] = position + BOARD_ROW_SIZE;
        }

        // Set the left position, if relevant
        if (position % BOARD_ROW_SIZE > 0) {
            returnCells[adjacentCellsIndex++] = position - 1;
        }

        // Set the right position, if relevant
        if (position % BOARD_ROW_SIZE < BOARD_ROW_SIZE - 1) {
            returnCells[adjacentCellsIndex++] = position + 1;
        }

        return returnCells;
    }

    /// @notice Calculates the board's score, using area scoring.
    /// @param boardId the board to calculate the score for.
    /// @return blackScore & whiteScore, the players' scores.
    function calculateBoardScore(uint boardId) public view returns (uint8 blackScore, uint8 whiteScore) {

        GoBoard storage board = allBoards[boardId];
        uint8[BOARD_SIZE] memory boardEmptyGroups;
        uint8 maxEmptyGroupId;
        (boardEmptyGroups, maxEmptyGroupId) = getBoardEmptyGroups(board);
        uint8[BOARD_SIZE] memory groupsSize;
        uint8[BOARD_SIZE] memory groupsState;
        
        blackScore = 0;
        whiteScore = 0;

        // Count stones and find empty territories
        for (uint8 position = 0; position < BOARD_SIZE; position++) {

            if (PlayerColor(board.positionToColor[position]) == PlayerColor.Black) {

                blackScore++;
            } else if (PlayerColor(board.positionToColor[position]) == PlayerColor.White) {

                whiteScore++;
            } else {

                uint8 groupId = boardEmptyGroups[position];
                groupsSize[groupId]++;

                // Checking is needed only if we didn't find the group is adjacent to the two colors already
                if ((groupsState[groupId] & uint8(PlayerColor.Black) == 0) || (groupsState[groupId] & uint8(PlayerColor.White) == 0)) {

                    uint8[MAX_ADJACENT_CELLS] memory adjacentArray = getAdjacentCells(position);

                    // Check adjacent cells to mark the group's bounderies
                    for (uint8 currAdjacentIndex = 0; currAdjacentIndex < MAX_ADJACENT_CELLS && adjacentArray[currAdjacentIndex] < MAX_UINT8; currAdjacentIndex++) {

                        // Check if the group has a black boundry
                        if ((PlayerColor(board.positionToColor[adjacentArray[currAdjacentIndex]]) == PlayerColor.Black) && 
                            (groupsState[groupId] & uint8(PlayerColor.Black) == 0)) {

                            groupsState[groupId] |= uint8(PlayerColor.Black);

                        // Check if the group has a white boundry
                        } else if ((PlayerColor(board.positionToColor[adjacentArray[currAdjacentIndex]]) == PlayerColor.White) && 
                                   (groupsState[groupId] & uint8(PlayerColor.White) == 0)) {

                            groupsState[groupId] |= uint8(PlayerColor.White);
                        }
                    }
                }
            }
        }

        // Add territories size to the relevant player
        for (uint8 currGroupId = 1; currGroupId < maxEmptyGroupId; currGroupId++) {
            
            // Check if it's a black territory
            if ((groupsState[currGroupId] & uint8(PlayerColor.Black) > 0) &&
                (groupsState[currGroupId] & uint8(PlayerColor.White) == 0)) {

                blackScore += groupsSize[currGroupId];

            // Check if it's a white territory
            } else if ((groupsState[currGroupId] & uint8(PlayerColor.White) > 0) &&
                       (groupsState[currGroupId] & uint8(PlayerColor.Black) == 0)) {

                whiteScore += groupsSize[currGroupId];
            }
        }

        return (blackScore, whiteScore);
    }

    /// @dev IDs empty groups on the board.
    /// @param board the board to map.
    /// @return an array that contains the mapped empty group ids, and the max empty group id
    function getBoardEmptyGroups(GoBoard storage board) private view returns (uint8[BOARD_SIZE], uint8) {

        uint8[BOARD_SIZE] memory boardEmptyGroups;
        uint8 nextGroupId = 1;

        for (uint8 position = 0; position < BOARD_SIZE; position++) {

            PlayerColor currPositionColor = PlayerColor(board.positionToColor[position]);

            if ((currPositionColor == PlayerColor.None) && (boardEmptyGroups[position] == 0)) {

                uint8[BOARD_SIZE] memory emptyGroup;
                bool isGroupCaptured;
                (emptyGroup, isGroupCaptured) = getGroup(board, position, 0);

                for (uint8 currGroupIndex = 0; currGroupIndex < BOARD_SIZE && emptyGroup[currGroupIndex] < MAX_UINT8; currGroupIndex++) {

                    boardEmptyGroups[emptyGroup[currGroupIndex]] = nextGroupId;
                }

                nextGroupId++;
            }
        }

        return (boardEmptyGroups, nextGroupId);
    }
}