program samegame;

{$mode objfpc}{$H+}

uses
{$IFDEF LINUX}
  cthreads,
{$ENDIF}
  Classes, SysUtils, CustApp, raylib, math;

type
  { TRayApplication }
  TRayApplication = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

const
  AppTitle = 'SameGame';
  BOARD_WIDTH = 15;
  BOARD_HEIGHT = 12;
  CELL_SIZE = 40;
  MARGIN_X = 50;
  MARGIN_Y = 80;

type
  TCellState = (csEmpty, csRed, csGreen, csBlue, csYellow, csPurple);
  TGameState = (gsPlaying, gsGameOver, gsVictory);

var
  Board: array[0..BOARD_WIDTH-1, 0..BOARD_HEIGHT-1] of TCellState;
  Score: Integer;
  GameState: TGameState;

{ TRayApplication }
procedure InitializeGame;
var
  x, y: Integer;
begin
  Randomize;
  Score := 0;
  GameState := gsPlaying;

  // Заполняем поле случайными цветами
  for x := 0 to BOARD_WIDTH - 1 do
    for y := 0 to BOARD_HEIGHT - 1 do
      Board[x, y] := TCellState(Random(5) + 1); // 1-5 цвета, 0 - пусто
end;

constructor TRayApplication.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
    InitWindow( (BOARD_WIDTH * CELL_SIZE) + (MARGIN_X * 2), (BOARD_HEIGHT * CELL_SIZE)+ (MARGIN_Y * 2) , AppTitle);
  SetTargetFPS(60);
  InitializeGame;
end;

function GetCellColor(State: TCellState): TColor;
begin
  case State of
    csEmpty: Result := RAYWHITE;
    csRed: Result := MAROON;
    csGreen: Result := DARKGREEN;
    csBlue: Result := DARKBLUE;
    csYellow: Result := GOLD;
    csPurple: Result := PURPLE;
  else
    Result := LIGHTGRAY;
  end;
end;

function HasValidMoves: Boolean;
var
  x, y: Integer;
  currentColor: TCellState;
begin
  Result := False;

  for x := 0 to BOARD_WIDTH - 1 do
  begin
    for y := 0 to BOARD_HEIGHT - 1 do
    begin
      currentColor := Board[x, y];
      if currentColor = csEmpty then
        Continue;

      // Проверяем соседей справа и снизу
      if (x < BOARD_WIDTH - 1) and (Board[x + 1, y] = currentColor) then
      begin
        Result := True;
        Exit;
      end;

      if (y < BOARD_HEIGHT - 1) and (Board[x, y + 1] = currentColor) then
      begin
        Result := True;
        Exit;
      end;
    end;
  end;
end;

procedure FindConnected(x, y: Integer; Color: TCellState;
  var Visited: array of Boolean; var Connected: array of Boolean);
var
  directions: array[0..3, 0..1] of Integer;
  i, nx, ny: Integer;
begin
  if (x < 0) or (x >= BOARD_WIDTH) or (y < 0) or (y >= BOARD_HEIGHT) then
    Exit;

  if Visited[y * BOARD_WIDTH + x] or (Board[x, y] <> Color) then
    Exit;

  Visited[y * BOARD_WIDTH + x] := True;
  Connected[y * BOARD_WIDTH + x] := True;

  directions[0, 0] := 1;  directions[0, 1] := 0;   // right
  directions[1, 0] := -1; directions[1, 1] := 0;   // left
  directions[2, 0] := 0;  directions[2, 1] := 1;   // down
  directions[3, 0] := 0;  directions[3, 1] := -1;  // up

  for i := 0 to 3 do
  begin
    nx := x + directions[i, 0];
    ny := y + directions[i, 1];
    FindConnected(nx, ny, Color, Visited, Connected);
  end;
end;

function GetConnectedCount(x, y: Integer; Color: TCellState): Integer;
var
  Visited: array of Boolean;
  Connected: array of Boolean;
  i: Integer;
begin
  Result := 0;
  if Color = csEmpty then Exit;

  SetLength(Visited, BOARD_WIDTH * BOARD_HEIGHT);
  SetLength(Connected, BOARD_WIDTH * BOARD_HEIGHT);

  for i := 0 to Length(Visited) - 1 do
  begin
    Visited[i] := False;
    Connected[i] := False;
  end;

  FindConnected(x, y, Color, Visited, Connected);

  for i := 0 to Length(Connected) - 1 do
    if Connected[i] then
      Inc(Result);
end;

procedure RemoveConnectedGroup(x, y: Integer; Color: TCellState);
var
  Visited: array of Boolean;
  Connected: array of Boolean;
  i, cx, cy: Integer;
begin
  if Color = csEmpty then Exit;

  SetLength(Visited, BOARD_WIDTH * BOARD_HEIGHT);
  SetLength(Connected, BOARD_WIDTH * BOARD_HEIGHT);

  for i := 0 to Length(Visited) - 1 do
  begin
    Visited[i] := False;
    Connected[i] := False;
  end;

  FindConnected(x, y, Color, Visited, Connected);

  // Удаляем все подключенные блоки
  for i := 0 to Length(Connected) - 1 do
  begin
    if Connected[i] then
    begin
      cx := i mod BOARD_WIDTH;
      cy := i div BOARD_WIDTH;
      Board[cx, cy] := csEmpty;
    end;
  end;
end;

procedure ApplyGravity;
var
  x, y, emptyCount: Integer;
begin
  // Гравитация в столбцах - блоки падают вниз
  for x := 0 to BOARD_WIDTH - 1 do
  begin
    emptyCount := 0;
    // Проходим столбец снизу вверх
    for y := BOARD_HEIGHT - 1 downto 0 do
    begin
      if Board[x, y] = csEmpty then
        Inc(emptyCount)
      else if emptyCount > 0 then
      begin
        // Перемещаем блок вниз
        Board[x, y + emptyCount] := Board[x, y];
        Board[x, y] := csEmpty;
      end;
    end;
  end;
end;

procedure RemoveEmptyColumns;
var
  x, shift, y: Integer;
  columnEmpty: Boolean;
  tempBoard: array[0..BOARD_WIDTH-1, 0..BOARD_HEIGHT-1] of TCellState;
begin
  // Создаем временную копию доски
  for x := 0 to BOARD_WIDTH - 1 do
    for y := 0 to BOARD_HEIGHT - 1 do
      tempBoard[x, y] := Board[x, y];

  shift := 0;

  // Переносим непустые столбцы влево
  for x := 0 to BOARD_WIDTH - 1 do
  begin
    columnEmpty := True;
    for y := 0 to BOARD_HEIGHT - 1 do
    begin
      if tempBoard[x, y] <> csEmpty then
      begin
        columnEmpty := False;
        Break;
      end;
    end;

    if not columnEmpty then
    begin
      // Копируем непустой столбец на новую позицию
      for y := 0 to BOARD_HEIGHT - 1 do
        Board[shift, y] := tempBoard[x, y];
      Inc(shift);
    end;
  end;

  // Заполняем оставшиеся столбцы пустыми клетками
  for x := shift to BOARD_WIDTH - 1 do
    for y := 0 to BOARD_HEIGHT - 1 do
      Board[x, y] := csEmpty;
end;

function IsBoardEmpty: Boolean;
var
  x, y: Integer;
begin
  Result := True;
  for x := 0 to BOARD_WIDTH - 1 do
    for y := 0 to BOARD_HEIGHT - 1 do
      if Board[x, y] <> csEmpty then
      begin
        Result := False;
        Exit;
      end;
end;

procedure HandleMouseClick;
var
  MousePos: TVector2;
  x, y: Integer;
  groupSize: Integer;
begin
  if GameState <> gsPlaying then
    Exit;

  MousePos := GetMousePosition();

  // Преобразуем координаты мыши в координаты доски
  x := Trunc((MousePos.x - MARGIN_X) / CELL_SIZE);
  y := Trunc((MousePos.y - MARGIN_Y) / CELL_SIZE);

  if (x < 0) or (x >= BOARD_WIDTH) or (y < 0) or (y >= BOARD_HEIGHT) then
    Exit;

  if Board[x, y] = csEmpty then
    Exit;

  // Проверяем размер группы
  groupSize := GetConnectedCount(x, y, Board[x, y]);

  if groupSize < 2 then
    Exit;

  // Удаляем группу и начисляем очки
  RemoveConnectedGroup(x, y, Board[x, y]);
  Score := Score + (groupSize - 1) * (groupSize - 1);

  // Применяем гравитацию и удаляем пустые столбцы
  ApplyGravity;
  RemoveEmptyColumns;

  // Проверяем условия окончания игры
  if IsBoardEmpty then
    GameState := gsVictory
  else if not HasValidMoves then
    GameState := gsGameOver;
end;

procedure TRayApplication.DoRun;
var
  x, y: Integer;
  cellColor: TColor;
  rect: TRectangle;
  groupSize, TextWidth: Integer;
  MousePos: TVector2;
  InstructionText, GameTitle, GameReset: string;
  popupRect: TRectangle;
begin
  while (not WindowShouldClose) do
  begin
    // Обработка ввода
    if IsMouseButtonPressed(MOUSE_BUTTON_LEFT) then
      HandleMouseClick;

    if IsKeyPressed(KEY_R) then
      InitializeGame;

    // Отрисовка
    BeginDrawing();
      ClearBackground(RAYWHITE);

      // Отрисовка заголовка по центру
      GameTitle := 'SameGame';
      TextWidth := MeasureText(PChar(GameTitle), 30);
      DrawText(PChar(GameTitle), (GetScreenWidth() - TextWidth) div 2, 20, 30, GRAY);

      // Отрисовка счета и кнопки новой игры
      DrawText(PChar('Score: ' + IntToStr(Score)), MARGIN_X, 20, 20, GRAY);

      GameReset := 'R - GameReset';
      TextWidth := MeasureText(PChar(GameReset), 20);
      DrawText(PChar(GameReset), GetScreenWidth() - TextWidth - MARGIN_X, 20, 20, GRAY);

      // Отрисовка игрового поля
      for x := 0 to BOARD_WIDTH - 1 do
      begin
        for y := 0 to BOARD_HEIGHT - 1 do
        begin
          cellColor := GetCellColor(Board[x, y]);

          rect.x := MARGIN_X + x * CELL_SIZE;
          rect.y := MARGIN_Y + y * CELL_SIZE;
          rect.width := CELL_SIZE - 2;
          rect.height := CELL_SIZE - 2;

          DrawRectangleRec(rect, cellColor);
          DrawRectangleLinesEx(rect, 1, LIGHTGRAY);

          // Показываем размер группы при наведении
          if Board[x, y] <> csEmpty then
          begin
            MousePos := GetMousePosition();
            if (MousePos.x >= rect.x) and (MousePos.x <= rect.x + rect.width) and
               (MousePos.y >= rect.y) and (MousePos.y <= rect.y + rect.height) then
            begin
              groupSize := GetConnectedCount(x, y, Board[x, y]);
              if groupSize >= 2 then
              begin
                DrawRectangleLinesEx(rect, 2 , BLACK);
                DrawText(PChar(IntToStr(groupSize)),
                  Round(rect.x + rect.width / 2 - 4),
                  Round(rect.y + rect.height / 2 - 5),
                  10, BLACK);
              end;
            end;
          end;
        end;
      end;

      // Отрисовка состояния игры по центру
      case GameState of
        gsGameOver:
          begin
            // Центрируем прямоугольник
            popupRect.width := 400;
            popupRect.height := 150;
            popupRect.x := (GetScreenWidth() - popupRect.width) /2 ;
            popupRect.y := 250;

            DrawRectangleRec(popupRect, Fade(DARKGRAY, 0.8));

            TextWidth := MeasureText('GAME OVER!', 30);
            DrawText('GAME OVER!', (GetScreenWidth() - TextWidth) div 2, 270, 30, MAROON);

            TextWidth := MeasureText('No valid moves available', 20);
            DrawText('No valid moves available', (GetScreenWidth() - TextWidth) div 2, 310, 20, RAYWHITE);

            TextWidth := MeasureText('Press R - for new game', 20);
            DrawText('Press R - for new game', (GetScreenWidth() - TextWidth) div 2, 340, 20, RAYWHITE);
          end;

        gsVictory:
          begin
            // Центрируем прямоугольник
            popupRect.width := 400;
            popupRect.height := 150;
            popupRect.x := (GetScreenWidth() - popupRect.width) / 2;
            popupRect.y := 250;

            DrawRectangleRec(popupRect, Fade(DARKGRAY, 0.8));

            TextWidth := MeasureText('Victory!', 30);
            DrawText('Victory!', (GetScreenWidth() - TextWidth) div 2, 270, 30, DARKGREEN);

            TextWidth := MeasureText(PChar('Score: ' + IntToStr(Score)), 20);
            DrawText(PChar('Score: ' + IntToStr(Score)), (GetScreenWidth() - TextWidth) div 2, 310, 20, RAYWHITE);

            TextWidth := MeasureText('Press R - for new game', 20);
            DrawText('Press R - for new game', (GetScreenWidth() - TextWidth) div 2, 340, 20, RAYWHITE);
          end;
      end;

      // Инструкция по центру
      InstructionText := 'Click groups of 2 or more same-colored blocks';
      TextWidth := MeasureText(PChar(InstructionText), 20);
      DrawText(PChar(InstructionText),
        (GetScreenWidth() - TextWidth) div 2,
        MARGIN_Y + BOARD_HEIGHT * CELL_SIZE + 20,
        20, GRAY);

      EndDrawing();
  end;
  Terminate;
end;

destructor TRayApplication.Destroy;
begin
  CloseWindow();
  inherited Destroy;
end;

var
  Application: TRayApplication;
begin
  Application := TRayApplication.Create(nil);
  Application.Title := AppTitle;
  Application.Run;
  Application.Free;
end.
