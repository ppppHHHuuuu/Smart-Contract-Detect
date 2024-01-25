/// @title This contract manages the meta details of EthernalGo. 
///     Registering to a board, splitting the revenues and other day-to-day actions that are unrelated to the actual game
/// @author https://www.EthernalGo.com
/// @dev See the GoGameLogic to understand the actual game mechanics and rules
contract GoBoardMetaDetails is GoGlobals {
    
    /// @dev The player added to board event can be used to check upon registration success
    event PlayerAddedToBoard(uint boardId, address playerAddress);
    
    /// @dev The board updated status can be used to get the new board status
    event BoardStatusUpdated(uint boardId, BoardStatus newStatus);
    
    /// @dev The player withdrawn his accumulated balance 
    event PlayerWithdrawnBalance(address playerAddress);
    
    /// @dev Simple wrapper to return the number of boards in total
    function getTotalNumberOfBoards() public view returns(uint) {
        return allBoards.length;
    }

    /// @notice We would like to easily and transparantly share the game's statistics with anyone and present on the web-app
    function getCompletedGamesStatistics() public view returns(uint, uint) {
        uint completed = 0;
        uint ethPaid = 0;
        
        // @dev Go through all the boards, we start with 1 as it's an unsigned int
        for (uint i = 1; i <= allBoards.length; i++) {

            // Get the current board
            GoBoard storage board = allBoards[i - 1];
            
            // Check if it was a victory, otherwise it's not interesting as the players just got their deposit back
            if ((board.status == BoardStatus.BlackWin) || (board.status == BoardStatus.WhiteWin)) {
                ++completed;

                // We need to query the table stakes as the board's balance will be zero once a game is finished
                ethPaid += board.tableStakes.mul(2);
            }
        }

        return (completed, ethPaid);
    }

    /// @dev At this point there is no support for returning dynamic arrays (it's supported for web3 calls but not for internal testing) so we will "only" present the recent 50 games per player.
    uint8 constant PAGE_SIZE = 50;

    /// @dev Make sure this board is in waiting for result status
    modifier boardWaitingToResolve(uint boardId){
        require(allBoards[boardId].status == BoardStatus.WaitingToResolve);
        _;
    }

    /// @dev Make sure this board is in one of the end of game states
    modifier boardGameEnded(GoBoard storage board){
        require(isEndGameStatus(board.status));
        _;
    }

    /// @dev Make sure this board still has balance
    modifier boardNotPaid(GoBoard storage board){
        require(board.boardBalance > 0);
        _;
    }

    /// @dev Make sure this board still has a spot for at least one player to join
    modifier boardWaitingForPlayers(uint boardId){
        require(allBoards[boardId].status == BoardStatus.WaitForOpponent &&
                (allBoards[boardId].blackAddress == 0 || 
                 allBoards[boardId].whiteAddress == 0));
        _;
    }

    /// @dev Restricts games for the allowed table stakes
    /// @param value the value we are looking for to register
    modifier allowedValuesOnly(uint value){
        bool didFindValue = false;
        
        // The number of tableStakesOptions can change hence it has to be dynamic
        for (uint8 i = 0; i < tableStakesOptions.length; ++ i) {
           if (value == tableStakesOptions[i])
            didFindValue = true;
        }

        require (didFindValue);
        _;
    }

    /// @dev Checks a status if and returns if it's an end game
    /// @param status the value we are checking
    /// @return true if it's an end-game status
    function isEndGameStatus(BoardStatus status) public pure returns(bool) {
        return (status == BoardStatus.BlackWin) || (status == BoardStatus.WhiteWin) || (status == BoardStatus.Draw) || (status == BoardStatus.Canceled);
    }

    /// @dev Gets the update time for a board
    /// @param boardId The id of the board to check
    /// @return the update timestamp in seconds
    function getBoardUpdateTime(uint boardId) public view returns(uint) {
        GoBoard storage board = allBoards[boardId];
        return (board.lastUpdate);
    }

    /// @dev Gets the current board status
    /// @param boardId The id of the board to check
    /// @return the current board status
    function getBoardStatus(uint boardId) public view returns(BoardStatus) {
        GoBoard storage board = allBoards[boardId];
        return (board.status);
    }

    /// @dev Gets the current balance of the board
    /// @param boardId The id of the board to check
    /// @return the current board balance in WEI
    function getBoardBalance(uint boardId) public view returns(uint) {
        GoBoard storage board = allBoards[boardId];
        return (board.boardBalance);
    }

    /// @dev Sets the current balance of the board, this is internal and is triggerred by functions run by external player actions
    /// @param board The board to update
    /// @param boardId The board's Id
    /// @param newStatus The new status to set
    function updateBoardStatus(GoBoard storage board, uint boardId, BoardStatus newStatus) internal {    
        
        // Save gas if we accidentally are trying to update to an existing update
        if (newStatus != board.status) {
            
            // Set the new board status
            board.status = newStatus;
            
            // Update the time (important for start and finish states)
            board.lastUpdate = now;

            // If this is an end game status
            if (isEndGameStatus(newStatus)) {

                // Credit the players accoriding to the board score
                creditBoardGameRevenues(board);
            }

            // Notify status update
            BoardStatusUpdated(boardId, newStatus);
        }
    }

    /// @dev Overload to set the board status when we only have a boardId
    /// @param boardId The boardId to update
    /// @param newStatus The new status to set
    function updateBoardStatus(uint boardId, BoardStatus newStatus) internal {
        updateBoardStatus(allBoards[boardId], boardId, newStatus);
    }

    /// @dev Gets the player color given an address and board (overload for when we only have boardId)
    /// @param boardId The boardId to check
    /// @param searchAddress The player's address we are searching for
    /// @return the player's color
    function getPlayerColor(uint boardId, address searchAddress) internal view returns (PlayerColor) {
        return (getPlayerColor(allBoards[boardId], searchAddress));
    }
    
    /// @dev Gets the player color given an address and board
    /// @param board The board to check
    /// @param searchAddress The player's address we are searching for
    /// @return the player's color
    function getPlayerColor(GoBoard storage board, address searchAddress) internal view returns (PlayerColor) {

        // Check if this is the black player
        if (board.blackAddress == searchAddress) {
            return (PlayerColor.Black);
        }

        // Check if this is the white player
        if (board.whiteAddress == searchAddress) {
            return (PlayerColor.White);
        }

        // We aren't suppose to try and get the color of a player if they aren't on the board
        revert();
    }

    /// @dev Gets the player address given a color on the board
    /// @param boardId The board to check
    /// @param color The color of the player we want
    /// @return the player's address
    function getPlayerAddress(uint boardId, PlayerColor color) public view returns(address) {

        // If it's the black player
        if (color == PlayerColor.Black) {
            return allBoards[boardId].blackAddress;
        }

        // If it's the white player
        if (color == PlayerColor.White) {
            return allBoards[boardId].whiteAddress;
        }

        // We aren't suppose to try and get the color of a player if they aren't on the board
        revert();
    }

    /// @dev Check if a player is on board (overload for boardId)
    /// @param boardId The board to check
    /// @param searchAddress the player's address we want to check
    /// @return true if the player is playing in the board
    function isPlayerOnBoard(uint boardId, address searchAddress) public view returns(bool) {
        return (isPlayerOnBoard(allBoards[boardId], searchAddress));
    }

    /// @dev Check if a player is on board
    /// @param board The board to check
    /// @param searchAddress the player's address we want to check
    /// @return true if the player is playing in the board
    function isPlayerOnBoard(GoBoard storage board, address searchAddress) private view returns(bool) {
        return (board.blackAddress == searchAddress || board.whiteAddress == searchAddress);
    }

    /// @dev Check which player acts next
    /// @param boardId The board to check
    /// @return The color of the current player to act
    function getNextTurnColor(uint boardId) public view returns(PlayerColor) {
        return allBoards[boardId].nextTurnColor;
    }

    /// @notice This is the first function a player will be using in order to start playing. This function allows 
    ///  to register to an existing or a new board, depending on the current available boards.
    ///  Upon registeration the player will pay the board's stakes and will be the black or white player.
    ///  The black player also creates the board, and is the first player which gives a small advantage in the
    ///  game, therefore we decided that the black player will be the one paying for the additional gas
    ///  that is required to create the board.
    /// @param  tableStakes The tablestakes to use, although this appears in the "value" of the message, we preferred to
    ///  add it as an additional parameter for client use for clients that allow to customize the value parameter.
    /// @return The boardId the player registered to (either a new board or an existing board)
    function registerPlayerToBoard(uint tableStakes) external payable allowedValuesOnly(msg.value) whenNotPaused returns(uint) {
        // Make sure the value and tableStakes are the same
        require (msg.value == tableStakes);
        GoBoard storage boardToJoin;
        uint boardIDToJoin;
        
        // Check which board to connect to
        (boardIDToJoin, boardToJoin) = getOrCreateWaitingBoard(tableStakes);
        
        // Add the player to the board (they already paid)
        bool shouldStartGame = addPlayerToBoard(boardToJoin, tableStakes);

        // Fire the event for anyone listening
        PlayerAddedToBoard(boardIDToJoin, msg.sender);

        // If we have both players, start the game
        if (shouldStartGame) {

            // Start the game
            startBoardGame(boardToJoin, boardIDToJoin);
        }

        return boardIDToJoin;
    }

    /// @notice This function allows a player to cancel a match in the case they were waiting for an opponent for
    ///  a long time but didn't find anyone and would want to get their deposit of table stakes back.
    ///  That player may cancel the game as long as no opponent was found and the deposit will be returned in full (though gas fees still apply). The player will also need to withdraw funds from the contract after this action.
    /// @param boardId The board to cancel
    function cancelMatch(uint boardId) external {
        
        // Get the player
        GoBoard storage board = allBoards[boardId];

        // Make sure this player is on board
        require(isPlayerOnBoard(boardId, msg.sender));

        // Make sure that the game hasn't started
        require(board.status == BoardStatus.WaitForOpponent);

        // Update the board status to cancel (which also triggers the revenue sharing function)
        updateBoardStatus(board, boardId, BoardStatus.Canceled);
    }

    /// @dev Gets the current player boards to present to the player as needed
    /// @param activeTurnsOnly We might want to highlight the boards where the player is expected to act
    /// @return an array of PAGE_SIZE with the number of boards found and the actual IDs
    function getPlayerBoardsIDs(bool activeTurnsOnly) public view returns (uint, uint[PAGE_SIZE]) {
        uint[PAGE_SIZE] memory playerBoardIDsToReturn;
        uint numberOfPlayerBoardsToReturn = 0;
        
        // Look at the recent boards until you find a player board
        for (uint currBoard = allBoards.length; currBoard > 0 && numberOfPlayerBoardsToReturn < PAGE_SIZE; currBoard--) {
            uint boardID = currBoard - 1;            

            // We only care about boards the player is in
            if (isPlayerOnBoard(boardID, msg.sender)) {

                // Check if the player is the next to act, or just include it if it wasn't requested
                if (!activeTurnsOnly || getNextTurnColor(boardID) == getPlayerColor(boardID, msg.sender)) {
                    playerBoardIDsToReturn[numberOfPlayerBoardsToReturn] = boardID;
                    ++numberOfPlayerBoardsToReturn;
                }
            }
        }

        return (numberOfPlayerBoardsToReturn, playerBoardIDsToReturn);
    }

    /// @dev Creates a new board in case no board was found for a player to register
    /// @param tableStakesToUse The value used to set the board
    /// @return the id of new board (which is it's position in the allBoards array)
    function createNewGoBoard(uint tableStakesToUse) private returns(uint, GoBoard storage) {
        GoBoard memory newBoard = GoBoard({lastUpdate: now,
                                           isHonorableLoss: false,
                                           tableStakes: tableStakesToUse,
                                           boardBalance: 0,
                                           blackAddress: 0,
                                           whiteAddress: 0,
                                           blackPeriodsRemaining: PLAYER_START_PERIODS,
                                           whitePeriodsRemaining: PLAYER_START_PERIODS,
                                           nextTurnColor: PlayerColor.None,
                                           status:BoardStatus.WaitForOpponent,
                                           didPassPrevTurn:false});

        uint boardId = allBoards.push(newBoard) - 1;
        return (boardId, allBoards[boardId]);
    }

    /// @dev Creates a new board in case no board was found for a player to register
    /// @param tableStakes The value used to set the board
    /// @return the id of new board (which is it's position in the allBoards array)
    function getOrCreateWaitingBoard(uint tableStakes) private returns(uint, GoBoard storage) {
        bool wasFound = false;
        uint selectedBoardId = 0;
        GoBoard storage board;

        // First, try to find a board that has an empty spot and the right table stakes
        for (uint i = allBoards.length; i > 0 && !wasFound; --i) {
            board = allBoards[i - 1];

            // Make sure this board is already waiting and it's stakes are the same
            if (board.tableStakes == tableStakes) {
                
                // If this board is waiting for an opponent
                if (board.status == BoardStatus.WaitForOpponent) {
                    
                    // Awesome, we have the board and we are done
                    wasFound = true;
                    selectedBoardId = i - 1;
                }

                // If we found the rights stakes board but it isn't waiting for player we won't have another empty board.
                // We need to create a new one
                break;
            }
        }

        // Create a new board if we couldn't find one
        if (!wasFound) {
            (selectedBoardId, board) = createNewGoBoard(tableStakes);
        }

        return (selectedBoardId, board);
    }

    /// @dev Starts the game and sets everything up for the match
    /// @param board The board to update with the starting data
    /// @param boardId The board's Id
    function startBoardGame(GoBoard storage board, uint boardId) private {
        
        // Make sure both players are present
        require(board.blackAddress != 0 && board.whiteAddress != 0);
        
        // The black is always the first player in GO
        board.nextTurnColor = PlayerColor.Black;

        // Save the game start time and set the game status to in progress
        updateBoardStatus(board, boardId, BoardStatus.InProgress);
    }

    /// @dev Handles the registration of a player to a board
    /// @param board The board to update with the starting data
    /// @param paidAmount The amount the player paid to start playing (will be added to the board balance)
    /// @return true if the game should be started
    function addPlayerToBoard(GoBoard storage board, uint paidAmount) private returns(bool) {
        
        // Make suew we are still waitinf for opponent (otherwise we can't add players)
        bool shouldStartTheGame = false;
        require(board.status == BoardStatus.WaitForOpponent);

        // Check that the player isn't already on the board, otherwise they would pay twice for a single board... :( 
        require(!isPlayerOnBoard(board, msg.sender));

        // We always add the black player first as they created the board
        if (board.blackAddress == 0) {
            board.blackAddress = msg.sender;
        
        // If we have a black player, add the white player
        } else if (board.whiteAddress == 0) {
            board.whiteAddress = msg.sender;
        
            // Once the white player has been added, we can start the match
            shouldStartTheGame = true;           

        // If both addresses are occuipied and we got here, it's a problem
        } else {
            revert();
        }

        // Credit the board with what we know 
        board.boardBalance += paidAmount;

        return shouldStartTheGame;
    }

    /// @dev Helper function to caclulate how much time a player used since now
    /// @param lastUpdate the timestamp of last update of the board
    /// @return the number of periods used for this time
    function getTimePeriodsUsed(uint lastUpdate) private view returns(uint8) {
        return uint8(now.sub(lastUpdate).div(PLAYER_TURN_SINGLE_PERIOD));
    }

    /// @notice Convinience function to help present how much time a player has.
    /// @param boardId the board to check.
    /// @param color the color of the player to check.
    /// @return The number of time periods the player has, the number of seconds per each period and the total number of seconds for convinience.
    function getPlayerRemainingTime(uint boardId, PlayerColor color) view external returns (uint, uint, uint) {
        GoBoard storage board = allBoards[boardId];

        // Always verify we can act
        require(board.status == BoardStatus.InProgress);

        // Get the total remaining time:
        uint timePeriods = getPlayerTimePeriods(board, color);
        uint totalTimeRemaining = timePeriods * PLAYER_TURN_SINGLE_PERIOD;

        // If this is the acting player
        if (color == board.nextTurnColor) {

            // Calc time periods for player
            uint timePeriodsUsed = getTimePeriodsUsed(board.lastUpdate);
            if (timePeriods > timePeriodsUsed) {
                timePeriods -= timePeriodsUsed;
            } else {
                timePeriods = 0;
            }

            // Calc total time remaining  for player
            uint timeUsed = (now - board.lastUpdate);
            
            // Safely reduce the time used
            if (totalTimeRemaining > timeUsed) {
                totalTimeRemaining -= timeUsed;
            
            // A player can't have less than zero time to act
            } else {
                totalTimeRemaining = 0;
            }
        }
        
        return (timePeriods, PLAYER_TURN_SINGLE_PERIOD, totalTimeRemaining);
    }

    /// @dev After a player acted we might need to reduce the number of remaining time periods.
    /// @param board The board the player acted upon.
    /// @param color the color of the player that acted.
    /// @param timePeriodsUsed the number of periods the player used.
    function updatePlayerTimePeriods(GoBoard storage board, PlayerColor color, uint8 timePeriodsUsed) internal {

        // Reduce from the black player
        if (color == PlayerColor.Black) {

            // The player can't have less than 0 periods remaining
            board.blackPeriodsRemaining = board.blackPeriodsRemaining > timePeriodsUsed ? board.blackPeriodsRemaining - timePeriodsUsed : 0;
        // Reduce from the white player
        } else if (color == PlayerColor.White) {
            
            // The player can't have less than 0 periods remaining
            board.whitePeriodsRemaining = board.whitePeriodsRemaining > timePeriodsUsed ? board.whitePeriodsRemaining - timePeriodsUsed : 0;

        // We are not supposed to get here
        } else {
            revert();
        }
    }

    /// @dev Helper function to access the time periods of a player in a board.
    /// @param board The board to check.
    /// @param color the color of the player to check.
    /// @return The number of time periods remaining for this player
    function getPlayerTimePeriods(GoBoard storage board, PlayerColor color) internal view returns (uint8) {

        // For the black player
        if (color == PlayerColor.Black) {
            return board.blackPeriodsRemaining;

        // For the white player
        } else if (color == PlayerColor.White) {
            return board.whitePeriodsRemaining;

        // We are not supposed to get here
        } else {

            revert();
        }
    }

    /// @notice The main function to split game revenues, this is triggered only by changing the game's state
    ///  to one of the ending game states.
    ///  We make sure this board has a balance and that it's only running once a board game has ended
    ///  We used numbers for easier read through as this function is critical for the revenue sharing model
    /// @param board The board the credit will come from.
    function creditBoardGameRevenues(GoBoard storage board) private boardGameEnded(board) boardNotPaid(board) {
                
        // Get the shares from the globals
        uint updatedHostShare = HOST_SHARE;
        uint updatedLoserShare = 0;

        // Start accumulating funds for each participant and EthernalGo's CFO
        uint amountBlack = 0;
        uint amountWhite = 0;
        uint amountCFO = 0;
        uint fullAmount = 1000;

        // Incentivize resigns and quick end-games for the loser
        if (board.status == BoardStatus.BlackWin || board.status == BoardStatus.WhiteWin) {
            
            // In case the game ended honorably (not by time out), the loser will get credit (from the CFO's share)
            if (board.isHonorableLoss) {
                
                // Reduce the credit from the CFO
                updatedHostShare = HOST_SHARE - HONORABLE_LOSS_BONUS;
                
                // Add to the loser share
                updatedLoserShare = HONORABLE_LOSS_BONUS;
            }

            // If black won
            if (board.status == BoardStatus.BlackWin) {
                
                // Black should get the winner share
                amountBlack = board.boardBalance.mul(WINNER_SHARE).div(fullAmount);
                
                // White player should get the updated loser share (with or without the bonus)
                amountWhite = board.boardBalance.mul(updatedLoserShare).div(fullAmount);
            }

            // If white won
            if (board.status == BoardStatus.WhiteWin) {

                // White should get the winner share
                amountWhite = board.boardBalance.mul(WINNER_SHARE).div(fullAmount);
                
                // Black should get the updated loser share (with or without the bonus)
                amountBlack = board.boardBalance.mul(updatedLoserShare).div(fullAmount);
            }

            // The CFO should get the updates share if the game ended as expected
            amountCFO = board.boardBalance.mul(updatedHostShare).div(fullAmount);
        }

        // If the match ended in a draw or it was cancelled
        if (board.status == BoardStatus.Draw || board.status == BoardStatus.Canceled) {
            
            // The CFO is not taking a share from draw or a cancelled match
            amountCFO = 0;

            // If the white player was on board, we should split the balance in half
            if (board.whiteAddress != 0) {

                // Each player gets half of the balance
                amountBlack = board.boardBalance.div(2);
                amountWhite = board.boardBalance.div(2);

            // If there was only the black player, they should get the entire balance
            } else {
                amountBlack = board.boardBalance;
            }
        }

        // Make sure we are going to split the entire amount and nothing gets left behind
        assert(amountBlack + amountWhite + amountCFO == board.boardBalance);
        
        // Reset the balance
        board.boardBalance = 0;

        // Async sends to the participants (this means each participant will be required to withdraw funds)
        asyncSend(board.blackAddress, amountBlack);
        asyncSend(board.whiteAddress, amountWhite);
        asyncSend(CFO, amountCFO);
    }

    /// @dev withdraw accumulated balance, called by payee.
    function withdrawPayments() public {

        // Call Zeppelin's withdrawPayments
        super.withdrawPayments();

        // Send an event
        PlayerWithdrawnBalance(msg.sender);
    }
}