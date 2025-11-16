#include "raylib.h"
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <math.h>

#define BOARD_WIDTH 15
#define BOARD_HEIGHT 12
#define CELL_SIZE 40
#define MARGIN_X 50
#define MARGIN_Y 80

// Cell states: empty or colored
typedef enum {
    csEmpty,
    csRed,
    csGreen,
    csBlue,
    csYellow,
    csPurple
} TCellState;

// Game states
typedef enum {
    gsPlaying,
    gsGameOver,
    gsVictory
} TGameState;

// Global game variables
TCellState Board[BOARD_WIDTH][BOARD_HEIGHT];
int Score;
TGameState GameState;

// Function declarations
void InitializeGame(void);
Color GetCellColor(TCellState state);
bool HasValidMoves(void);
void FindConnected(int x, int y, TCellState color, bool* visited, bool* connected);
int GetConnectedCount(int x, int y, TCellState color);
void RemoveConnectedGroup(int x, int y, TCellState color);
void ApplyGravity(void);
void RemoveEmptyColumns(void);
bool IsBoardEmpty(void);
void HandleMouseClick(void);

int main(void)
{
    // Initialize game and create window
    InitializeGame();
    
    InitWindow((BOARD_WIDTH * CELL_SIZE) + (MARGIN_X * 2), 
               (BOARD_HEIGHT * CELL_SIZE) + (MARGIN_Y * 2), 
               "SameGame");
    SetTargetFPS(60);

    // Main game loop
    while (!WindowShouldClose())
    {
        // Handle input
        if (IsMouseButtonPressed(MOUSE_BUTTON_LEFT))
            HandleMouseClick();

        // Reset game with R key
        if (IsKeyPressed(KEY_R))
            InitializeGame();

        // Begin drawing
        BeginDrawing();
            ClearBackground(RAYWHITE);

            // Draw centered title
            const char* gameTitle = "SameGame";
            int textWidth = MeasureText(gameTitle, 30);
            DrawText(gameTitle, (GetScreenWidth() - textWidth) / 2, 20, 30, GRAY);

            // Draw score and reset button
            char scoreText[50];
            snprintf(scoreText, sizeof(scoreText), "Score: %d", Score);
            DrawText(scoreText, MARGIN_X, 20, 20, GRAY);

            const char* gameReset = "R - GameReset";
            textWidth = MeasureText(gameReset, 20);
            DrawText(gameReset, GetScreenWidth() - textWidth - MARGIN_X, 20, 20, GRAY);

            // Draw game board
            for (int x = 0; x < BOARD_WIDTH; x++)
            {
                for (int y = 0; y < BOARD_HEIGHT; y++)
                {
                    Color cellColor = GetCellColor(Board[x][y]);

                    Rectangle rect = {
                        MARGIN_X + x * CELL_SIZE,
                        MARGIN_Y + y * CELL_SIZE,
                        CELL_SIZE - 2,
                        CELL_SIZE - 2
                    };

                    DrawRectangleRec(rect, cellColor);
                    DrawRectangleLinesEx(rect, 1, LIGHTGRAY);

                    // Show group size on hover for non-empty cells
                    if (Board[x][y] != csEmpty)
                    {
                        Vector2 mousePos = GetMousePosition();
                        if (mousePos.x >= rect.x && mousePos.x <= rect.x + rect.width &&
                            mousePos.y >= rect.y && mousePos.y <= rect.y + rect.height)
                        {
                            int groupSize = GetConnectedCount(x, y, Board[x][y]);
                            if (groupSize >= 2)
                            {
                                // Highlight and show group size
                                DrawRectangleLinesEx(rect, 2, BLACK);
                                
                                char groupSizeText[10];
                                snprintf(groupSizeText, sizeof(groupSizeText), "%d", groupSize);
                                DrawText(groupSizeText,
                                    (int)(rect.x + rect.width / 2 - 4),
                                    (int)(rect.y + rect.height / 2 - 5),
                                    10, BLACK);
                            }
                        }
                    }
                }
            }

            // Draw game state popups
            switch (GameState)
            {
                case gsGameOver:
                {
                    // Game over popup
                    Rectangle popupRect = {
                        (GetScreenWidth() - 400) / 2.0f,
                        250,
                        400,
                        150
                    };

                    DrawRectangleRec(popupRect, Fade(DARKGRAY, 0.8f));

                    textWidth = MeasureText("GAME OVER!", 30);
                    DrawText("GAME OVER!", (GetScreenWidth() - textWidth) / 2, 270, 30, MAROON);

                    textWidth = MeasureText("No valid moves available", 20);
                    DrawText("No valid moves available", (GetScreenWidth() - textWidth) / 2, 310, 20, RAYWHITE);

                    textWidth = MeasureText("Press R - for new game", 20);
                    DrawText("Press R - for new game", (GetScreenWidth() - textWidth) / 2, 340, 20, RAYWHITE);
                    break;
                }

                case gsVictory:
                {
                    // Victory popup
                    Rectangle popupRect = {
                        (GetScreenWidth() - 400) / 2.0f,
                        250,
                        400,
                        150
                    };

                    DrawRectangleRec(popupRect, Fade(DARKGRAY, 0.8f));

                    textWidth = MeasureText("Victory!", 30);
                    DrawText("Victory!", (GetScreenWidth() - textWidth) / 2, 270, 30, DARKGREEN);

                    char victoryScoreText[50];
                    snprintf(victoryScoreText, sizeof(victoryScoreText), "Score: %d", Score);
                    textWidth = MeasureText(victoryScoreText, 20);
                    DrawText(victoryScoreText, (GetScreenWidth() - textWidth) / 2, 310, 20, RAYWHITE);

                    textWidth = MeasureText("Press R - for new game", 20);
                    DrawText("Press R - for new game", (GetScreenWidth() - textWidth) / 2, 340, 20, RAYWHITE);
                    break;
                }
                
                default:
                    break;
            }

            // Draw instructions
            const char* instructionText = "Click groups of 2 or more same-colored blocks";
            textWidth = MeasureText(instructionText, 20);
            DrawText(instructionText,
                (GetScreenWidth() - textWidth) / 2,
                MARGIN_Y + BOARD_HEIGHT * CELL_SIZE + 20,
                20, GRAY);

        EndDrawing();
    }

    CloseWindow();
    return 0;
}

// Initialize game with random board
void InitializeGame(void)
{
    Score = 0;
    GameState = gsPlaying;

    // Fill board with random colors
    for (int x = 0; x < BOARD_WIDTH; x++)
        for (int y = 0; y < BOARD_HEIGHT; y++)
            Board[x][y] = (TCellState)(rand() % 5 + 1); // 1-5 colors, 0 - empty
}

// Get color for cell state
Color GetCellColor(TCellState state)
{
    switch (state)
    {
        case csEmpty: return RAYWHITE;
        case csRed: return MAROON;
        case csGreen: return DARKGREEN;
        case csBlue: return DARKBLUE;
        case csYellow: return GOLD;
        case csPurple: return PURPLE;
        default: return LIGHTGRAY;
    }
}

// Check if there are any valid moves left
bool HasValidMoves(void)
{
    for (int x = 0; x < BOARD_WIDTH; x++)
    {
        for (int y = 0; y < BOARD_HEIGHT; y++)
        {
            TCellState currentColor = Board[x][y];
            if (currentColor == csEmpty)
                continue;

            // Check right and bottom neighbors for same color
            if ((x < BOARD_WIDTH - 1) && (Board[x + 1][y] == currentColor))
                return true;

            if ((y < BOARD_HEIGHT - 1) && (Board[x][y + 1] == currentColor))
                return true;
        }
    }
    
    return false;
}

// Recursive function to find connected cells using flood fill algorithm
void FindConnected(int x, int y, TCellState color, bool* visited, bool* connected)
{
    // Check bounds
    if (x < 0 || x >= BOARD_WIDTH || y < 0 || y >= BOARD_HEIGHT)
        return;

    // Check if already visited or different color
    if (visited[y * BOARD_WIDTH + x] || Board[x][y] != color)
        return;

    // Mark as visited and connected
    visited[y * BOARD_WIDTH + x] = true;
    connected[y * BOARD_WIDTH + x] = true;

    // Directions: right, left, down, up
    int directions[4][2] = {
        {1, 0},
        {-1, 0},
        {0, 1},
        {0, -1}
    };

    // Recursively check all directions
    for (int i = 0; i < 4; i++)
    {
        int nx = x + directions[i][0];
        int ny = y + directions[i][1];
        FindConnected(nx, ny, color, visited, connected);
    }
}

// Get number of connected cells in group
int GetConnectedCount(int x, int y, TCellState color)
{
    if (color == csEmpty) return 0;

    // Allocate memory for visited and connected arrays
    bool* visited = (bool*)calloc(BOARD_WIDTH * BOARD_HEIGHT, sizeof(bool));
    bool* connected = (bool*)calloc(BOARD_WIDTH * BOARD_HEIGHT, sizeof(bool));

    if (!visited || !connected)
    {
        if (visited) free(visited);
        if (connected) free(connected);
        return 0;
    }

    // Find all connected cells
    FindConnected(x, y, color, visited, connected);

    // Count connected cells
    int count = 0;
    for (int i = 0; i < BOARD_WIDTH * BOARD_HEIGHT; i++)
        if (connected[i]) count++;

    // Free memory
    free(visited);
    free(connected);
    
    return count;
}

// Remove connected group from board
void RemoveConnectedGroup(int x, int y, TCellState color)
{
    if (color == csEmpty) return;

    // Allocate memory for visited and connected arrays
    bool* visited = (bool*)calloc(BOARD_WIDTH * BOARD_HEIGHT, sizeof(bool));
    bool* connected = (bool*)calloc(BOARD_WIDTH * BOARD_HEIGHT, sizeof(bool));

    if (!visited || !connected)
    {
        if (visited) free(visited);
        if (connected) free(connected);
        return;
    }

    // Find all connected cells
    FindConnected(x, y, color, visited, connected);

    // Remove all connected blocks
    for (int i = 0; i < BOARD_WIDTH * BOARD_HEIGHT; i++)
    {
        if (connected[i])
        {
            int cx = i % BOARD_WIDTH;
            int cy = i / BOARD_WIDTH;
            Board[cx][cy] = csEmpty;
        }
    }

    // Free memory
    free(visited);
    free(connected);
}

// Apply gravity - make blocks fall down
void ApplyGravity(void)
{
    // Gravity in columns - blocks fall down
    for (int x = 0; x < BOARD_WIDTH; x++)
    {
        int emptyCount = 0;
        // Process column from bottom to top
        for (int y = BOARD_HEIGHT - 1; y >= 0; y--)
        {
            if (Board[x][y] == csEmpty)
                emptyCount++;
            else if (emptyCount > 0)
            {
                // Move block down
                Board[x][y + emptyCount] = Board[x][y];
                Board[x][y] = csEmpty;
            }
        }
    }
}

// Remove empty columns and shift columns left
void RemoveEmptyColumns(void)
{
    TCellState tempBoard[BOARD_WIDTH][BOARD_HEIGHT];
    
    // Create temporary board copy
    for (int x = 0; x < BOARD_WIDTH; x++)
        for (int y = 0; y < BOARD_HEIGHT; y++)
            tempBoard[x][y] = Board[x][y];

    int shift = 0;

    // Move non-empty columns to the left
    for (int x = 0; x < BOARD_WIDTH; x++)
    {
        bool columnEmpty = true;
        for (int y = 0; y < BOARD_HEIGHT; y++)
        {
            if (tempBoard[x][y] != csEmpty)
            {
                columnEmpty = false;
                break;
            }
        }

        if (!columnEmpty)
        {
            // Copy non-empty column to new position
            for (int y = 0; y < BOARD_HEIGHT; y++)
                Board[shift][y] = tempBoard[x][y];
            shift++;
        }
    }

    // Fill remaining columns with empty cells
    for (int x = shift; x < BOARD_WIDTH; x++)
        for (int y = 0; y < BOARD_HEIGHT; y++)
            Board[x][y] = csEmpty;
}

// Check if board is completely empty
bool IsBoardEmpty(void)
{
    for (int x = 0; x < BOARD_WIDTH; x++)
        for (int y = 0; y < BOARD_HEIGHT; y++)
            if (Board[x][y] != csEmpty)
                return false;
    
    return true;
}

// Handle mouse click on game board
void HandleMouseClick(void)
{
    if (GameState != gsPlaying)
        return;

    Vector2 mousePos = GetMousePosition();

    // Convert mouse coordinates to board coordinates
    int x = (int)((mousePos.x - MARGIN_X) / CELL_SIZE);
    int y = (int)((mousePos.y - MARGIN_Y) / CELL_SIZE);

    // Check bounds
    if (x < 0 || x >= BOARD_WIDTH || y < 0 || y >= BOARD_HEIGHT)
        return;

    // Ignore empty cells
    if (Board[x][y] == csEmpty)
        return;

    // Check group size
    int groupSize = GetConnectedCount(x, y, Board[x][y]);

    // Need at least 2 connected cells
    if (groupSize < 2)
        return;

    // Remove group and add score (n² points for n blocks)
    RemoveConnectedGroup(x, y, Board[x][y]);
    Score += (groupSize - 1) * (groupSize - 1);

    // Apply gravity and remove empty columns
    ApplyGravity();
    RemoveEmptyColumns();

    // Check game end conditions
    if (IsBoardEmpty())
        GameState = gsVictory;
    else if (!HasValidMoves())
        GameState = gsGameOver;
}
