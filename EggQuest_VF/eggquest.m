% EGG QUEST - THE KNIGHT AND THE DRAGON EGG
% Final project: a single-player, keyboard-controlled maze game.
%
% WARNING !!! YOU MAY HAVE TO USE THE COMMAND "cd" AND COPYPASTE THE ACCESS
% PATHWAY OF THE GAME FOLDER LIKE THIS : cd "C://Users//...". YOU MAY HAVE TO
% DOUCLE THE "/" TOO. THEN YOU CAN USE THE FUNCTION "eggquest".
% IF IT IS STILL NOT WORKING, YOU CAN USE THE "run" COMMAND WITH THE ACCESS
% PATHWAY OF THE GAME DIRECTLY.
%
% GOAL AND CONTEXT
% Guide a knight through a randomly generated maze and reach the dragon egg.
% The player studies the revealed hazards, then navigates after they disappear.
%
% GAME COMPONENTS AND OBJECT PROPERTIES
% - pathways: logical grid; true cells are walkable and false cells are walls.
% - position: the knight's current [row, column] cell.
% - starting_point: the entrance cell near the top of the maze.
% - egg and coffre: the egg location and its logical occupancy map.
% - flames: logical grid marking deadly cells on useful branches.
% - sprite_chevalier, sprite_flamme, sprite_oeuf, sprite_mur: RGBA artwork.
% - maze_size and flame_number: configurable maze size and hazard count.
% - revelation: whether the egg and flames are currently visible.
%
% RULES AND CONTROLS
% The illustrated intro and Intro music appear before the maze. Press Space to
% reveal the egg and flames. The first valid move hides them with a brief flash.
% Touching a flame loses; reaching the egg wins. Space or Replay restarts after
% a result, and Escape quits at any time.
%
% MAIN LOOP AND CHANGES DURING A RUN
% A KeyPressFcn callback reads one movement key and rejects walls or map exits.
% After a valid move, the RGB maze image is redrawn and win/loss is checked.
% The main while loop calls drawnow and pauses briefly so the window can process
% keyboard and graphics events. Background music loops while a run is active.
%
% AUDIO CUES
% Intro starts while the illustrated opening screen is displayed and plays
% again after Replay until the first valid move. The labyrinth track starts on
% that move. Death plays on a flame; the victory cue plays on reaching the egg.
% Escape stops all sounds.
%
% ACROSS RUNS AND RESULTS
% Replay generates a fresh maze, egg corner, and flame arrangement, then resets
% the knight, reveal state, sounds, and game-over state. No scores are saved.
%
% SOURCES AND CREDITS
% - Maze generation: procedural Octave code in this file; no word list is used.
% - Images and original MP3 tracks: supplied by the students.
% - WAV audio assets: converted from the supplied MP3 files with FFmpeg.
% - Artwork credits: Ariane FRANCO-ROGELIO ; IbisPaintX
% - Music credits: Arlie Karoutchi ; FLStudio (no copyright)
%
% SOFTWARE AND SUBMISSION METADATA
% Octave version: GNU Octave 11.3.0
% Code version: 1.1
% Date: 2026-10-08 (YYYY-MM-DD)
% Authors and contributions :
% - Mathis BOUHALILA: Program generation, troubleshooting, concept creation.
% - Ariane FRANCO-ROGELIO: Graphic artworks, concept creation.
% - Arlie KAROUTCHI: Composition of the soundtracks, concept creation.

function eggquest(maze_size, flame_number)
  % Launch the graphical game with two optional settings.
  % 'size' is the number of maze cells per side; its default is 10.
  % 'flame_number' is the number of deadly flames; its default is 12.


  % 1ST PART - GAME EXPERIENCE: setup, audio, controls, display, and game flow


  % Use a 10-by-10 maze when the caller does not provide a size.
  if nargin < 1, maze_size = 10; endif
  % Place twelve flames while keeping most danger near the  egg.
  if nargin < 2, flame_number = 12; endif

  % Require one integer maze size of at least eight cells per side.
  if !isscalar(maze_size) || maze_size < 8 || maze_size != fix(maze_size)
    % Explain the expected size before stopping the function.
    error('Maze size must be an integer of at least 8.');
  endif
  % At least twelve flames are needed to place three in each quadrant.
  if !isscalar(flame_number) || flame_number < 12 || flame_number != fix(flame_number)
    error('Use at least twelve flames to place three in every maze quadrant.');
  endif
  % Do not allow more traps than the available maze cells.
  if flame_number > maze_size * maze_size - 2
    error('There are too many traps for a maze of this size.');
  endif

  % Octave needs a Qt or FLTK graphics toolkit to receive keyboard events.
  toolkits = available_graphics_toolkits();
  if any(strcmp(toolkits, 'qt'))
    graphics_toolkit('qt');
  elseif any(strcmp(toolkits, 'fltk'))
    graphics_toolkit('fltk');
  % A playable window cannot be created without a graphics toolkit.
  else
    error(['This game needs Octave GUI with the Qt or FLTK toolkit. ', ...
           'Available toolkits: ', strjoin(toolkits, ', ')]);
  endif

  % Generate the maze, the traps, and the only trap-free route.
  [pathways, starting_point, egg, flames] = generer_labyrinthe(maze_size, flame_number);
  % Set the knight's current position to the starting tile.
  position = starting_point;
  % Store the dragon egg location in a separate logical map.
  coffre = false(size(pathways));
  % Mark the tile containing the dragon egg as true.
  coffre(egg(1), egg(2)) = true;

  % Find this script's location, using Octave's search path as a fallback.
  chemin_script = mfilename('fullpath');
  if isempty(chemin_script)
    chemin_script = which('eggquest');
  endif
  % Use the script folder when Octave can identify it.
  if isempty(chemin_script)
    dossier_jeu = pwd();
  else
    dossier_jeu = fileparts(chemin_script);
  endif
  % Look for assets beside the script first, then in Octave's current folder.
  dossier_assets = fullfile(dossier_jeu, 'assets');
  if !exist(fullfile(dossier_assets, 'knight.png'), 'file')
    assets_dossier_courant = fullfile(pwd(), 'assets');
    if exist(fullfile(assets_dossier_courant, 'knight.png'), 'file')
      dossier_assets = assets_dossier_courant;
    endif
  endif
  % Explain how to fix an incomplete extraction before loading any sprites.
  if !exist(fullfile(dossier_assets, 'knight.png'), 'file')
    error(['Cannot find assets/knight.png. Extract the complete EggQuest ', ...
           'bundle and keep its assets folder beside eggquest.m.']);
  endif
  % Load all the sprites.
  sprite_chevalier = charger_sprite('knight.png');
  sprite_flamme = charger_sprite('flame.png');
  sprite_oeuf = charger_sprite('egg.png');
  sprite_mur = charger_sprite('wall.png');
  % Load the illustrated intro, victory, and defeat screens from the assets.
  ecran_intro = charger_ecran('intro.png');
  ecran_victoire = charger_ecran('win.png');
  ecran_defaite = charger_ecran('lose.png');
  size_sprite = 32;

  % Start the displayed terrain as a grid filled with walls.
  terrain = ones(size(pathways));
  % Replace open pathways with the light path color.
  terrain(pathways) = 2;
  % Give trap locations the red flame color.
  terrain(flames) = 3;
  % Give the  egg location the golden egg color.
  terrain(coffre) = 4;
  % Keep the starting tile green after the dragon leaves it.
  terrain(starting_point(1), starting_point(2)) = 6;
  % Compose the maze walls and floor into one fast background image.
  fond_labyrinthe = creer_fond_labyrinthe();

  % These variables track quitting, game-over, and the initial reveal states.
  termine = false;
  partie_terminee = false;
  revelation = true;
  % Track whether the intro, the maze, or a result screen is currently active.
  ecran_actuel = 'intro';
  % This flag ignores extra key presses while the flash is on screen.
  animation_en_cours = false;
  % Keep the audio player alive while the game is running.
  lecteur_audio = [];
  % Track whether the background music should restart after reaching its end.
  musique_en_cours = false;
  % Keep separate players for the opening and end-of-round sound effects.
  lecteur_intro = [];
  lecteur_mort = [];
  lecteur_victoire = [];

  % Open a separate window that captures keyboard input.
  fenetre = figure('Name', 'The Dragon Egg Maze', ...
                   'NumberTitle', 'off', ...
                   'MenuBar', 'none', ...
                   'Color', [0.08, 0.09, 0.12], ...
                   'Visible', 'on', ...
                   'WindowStyle', 'normal', ...
                   'KeyPressFcn', @touche_pressee);
  % Create the axes that contain the map and the sprites.
  axes_handle = axes('Parent', fenetre);
  % Reserve a lower strip of the window for the Replay button.
  set(axes_handle, 'Units', 'normalized', 'Position', [0.04, 0.12, 0.92, 0.82]);
  % Create the Replay button and keep it hidden until the game ends.
  replay_button = uicontrol('Parent', fenetre, ...
                             'Style', 'pushbutton', ...
                             'String', 'Replay', ...
                             'Units', 'normalized', ...
                             'Position', [0.40, 0.025, 0.20, 0.07], ...
                             'FontSize', 12, ...
                             'Visible', 'off', ...
                             'KeyPressFcn', @touche_pressee, ...
                             'Callback', @rejouer);
  % Draw the composed maze background over the maze's cell coordinates.
  image_handle = image(axes_handle, ...
                       [0.5 + 0.5 / size_sprite, columns(pathways) + 0.5 - 0.5 / size_sprite], ...
                       [0.5 + 0.5 / size_sprite, rows(pathways) + 0.5 - 0.5 / size_sprite], ...
                       fond_labyrinthe);
  % Keep tiles square so the maze is not distorted.
  axis(axes_handle, 'image');
  % Hide the axes and tick marks around the maze.
  axis(axes_handle, 'off');
  % Place the first matrix row at the top of the window.
  set(axes_handle, 'YDir', 'reverse');
  % Keep the axes title empty while the illustrated intro is on screen.
  title(axes_handle, '');
  % Allow keyboard events to reach the game window.
  set(image_handle, 'HitTest', 'off');
  % Prevent the axes from intercepting keyboard events.
  set(axes_handle, 'HitTest', 'off');
  % Hold the axes so sprites can be drawn over the map image.
  hold(axes_handle, 'on');
  % Draw the image-based sprites over the map for the initial reveal.
  dessiner_sprites(true);
  % Cover the maze with the intro screen until the player presses Space.
  ecran_handle = image(axes_handle, ...
                       [0.5 + 0.5 / size_sprite, columns(pathways) + 0.5 - 0.5 / size_sprite], ...
                       [0.5 + 0.5 / size_sprite, rows(pathways) + 0.5 - 0.5 / size_sprite], ...
                       ecran_intro);
  % Let keyboard input pass through the intro image to the game window.
  set(ecran_handle, 'HitTest', 'off');
  % Display the intro image immediately.
  drawnow();
  % Bring the window to the front so it can receive key presses.
  figure(fenetre);
  % Exit cleanly if the window was closed while it was opening.
  if !ishandle(fenetre)
    return;
  endif
  % Keep the intro visible until Space is pressed.
  drawnow();
  % Start the intro music during the intro screen, before the game begins.
  lecteur_intro = jouer_effet('Egg quest - Intro.wav', lecteur_intro);

  % Keep the function active so Octave can process window and keyboard events.
  while ishandle(fenetre) && !termine
    % Restart the soundtrack whenever the previous playback reaches its end.
    if musique_en_cours && !partie_terminee && !isempty(lecteur_audio) && ...
       !isplaying(lecteur_audio)
      % Loop the background music without blocking keyboard input.
      play(lecteur_audio);
    endif
    % This short pause prevents the loop from wasting CPU time.
    pause(0.02);
    % drawnow dispatches key presses to the keyboard callback.
    drawnow();
      endwhile
  % Stop any remaining music after Escape or the window close button.
  arreter_musique();
  % Stop the intro if it is still playing when the window closes.
  lecteur_intro = arreter_effet(lecteur_intro);
  % Stop the death sound if it is still playing when the window closes.
  lecteur_mort = arreter_effet(lecteur_mort);
  % Stop the victory sound if it is still playing when the window closes.
  lecteur_victoire = arreter_effet(lecteur_victoire);

  % Update the map and redraw the visible sprites.
  function rafraichir()
    % Update the image only while the window still exists.
    if ishandle(image_handle)
      % Redraw the sprites that match the current game state.
      dessiner_sprites(false);
      % Show the knight at its new position immediately.
      drawnow();
    endif
  endfunction

  % Start a freshly generated round in the current game window.
  function rejouer(~, ~)
    % Generate a new maze,  egg, and trap layout.
    [pathways, starting_point, egg, flames] = generer_labyrinthe(maze_size, flame_number);
    % Place the knight back at the new maze entrance.
    position = starting_point;
    % Stop any result sound left from the previous round.
    lecteur_mort = arreter_effet(lecteur_mort);
    lecteur_victoire = arreter_effet(lecteur_victoire);
    % Restart the opening sound for the new maze.
    lecteur_intro = arreter_effet(lecteur_intro);
    % Build a new logical mask for the dragon egg.
    coffre = false(size(pathways));
    coffre(egg(1), egg(2)) = true;
    % Rebuild the colored background for the new maze.
    terrain = ones(size(pathways));
    terrain(pathways) = 2;
    terrain(flames) = 3;
    terrain(coffre) = 4;
    terrain(starting_point(1), starting_point(2)) = 6;
    % Rebuild the static background for the newly generated maze.
    fond_labyrinthe = creer_fond_labyrinthe();
    % Restore the reveal and active-game states.
    revelation = true;
    partie_terminee = false;
    animation_en_cours = false;
    ecran_actuel = 'maze';
    % Remove the old screen image and restore the generated maze image.
    set(ecran_handle, 'Visible', 'off');
    set(image_handle, 'Visible', 'on');
    % Redraw the map and all visible sprites for the new round.
    dessiner_sprites(true);
    % Hide Replay until the next win or loss.
    set(replay_button, 'Visible', 'off');
    % Restore the start message and return focus to the game window.
    title(axes_handle, 'Press an arrow key or WASD/ZQSD to start', ...
          'Color', 'white', 'FontSize', 14);
    drawnow();
    % Play the intro while the player studies the new maze.
    lecteur_intro = jouer_effet('Egg quest - Intro.wav', lecteur_intro);
    figure(fenetre);
  endfunction

  % Load and start the supplied background soundtrack without blocking play.
  function jouer_musique()
    % Decode the MP3 and create its player only the first time it is needed.
    if isempty(lecteur_audio)
      try
        % Read the soundtrack using Octave's audio file reader.
        [donnees_audio, frequence_audio] = ...
            audioread(fullfile(dossier_assets, 'Egg quest - Labyrinth.wav'));
        % Keep the decoded track ready for future rounds.
        lecteur_audio = audioplayer(donnees_audio, frequence_audio);
      % Continue the game even if this Octave build cannot read the WAV file.
      catch erreur_audio
        warning('Could not load the soundtrack: %s', erreur_audio.message);
        lecteur_audio = [];
        musique_en_cours = false;
        return;
      end_try_catch
    endif
    % Start playback asynchronously so the keyboard stays responsive.
    try
      play(lecteur_audio);
      musique_en_cours = true;
    % Keep the maze playable if the audio device is unavailable.
    catch erreur_audio
      % Show the audio device error in the Octave console.
      warning('Could not play the soundtrack: %s', erreur_audio.message);
      lecteur_audio = [];
      musique_en_cours = false;
    end_try_catch
  endfunction

  % Stop the background music when a round ends.
  function arreter_musique()
    % Disable automatic replay of the audio track.
    musique_en_cours = false;
    % Stop playback if an audio player has already been created.
    if !isempty(lecteur_audio)
      % Ignore device-specific stop errors so the game can still end cleanly.
      try
        stop(lecteur_audio);
      catch
      end_try_catch
    endif
  endfunction

  % Load and play one of the converted WAV sound effects.
  function lecteur = jouer_effet(nom_fichier, lecteur)
    % Load the WAV data and create a player the first time it is requested.
    if isempty(lecteur)
      try
        % Read the chosen sound effect from the game's assets folder.
        [donnees_audio, frequence_audio] = ...
            audioread(fullfile(dossier_assets, nom_fichier));
        % Create a non-blocking player for the decoded sound data.
        lecteur = audioplayer(donnees_audio, frequence_audio);
      % Warn in the console if this Octave build cannot read the WAV file.
      catch erreur_audio
        % Include the asset name so the missing decoder or file is clear.
        warning('Could not load %s: %s', nom_fichier, erreur_audio.message);
        lecteur = [];
        return;
      end_try_catch
    endif
    % Restart the effect from the beginning if it is already playing.
    try
      % Stop the old playback before replaying the same effect.
      if isplaying(lecteur)
        stop(lecteur);
      endif
      % Play without blocking movement or window updates.
      play(lecteur);
    % Keep the game playable if an audio device rejects the effect.
    catch erreur_audio
      % Report the audio device problem in the Octave console.
      warning('Could not play %s: %s', nom_fichier, erreur_audio.message);
      lecteur = [];
    end_try_catch
  endfunction

  % Stop one sound effect and clear its player before the next round.
  function lecteur = arreter_effet(lecteur)
    % Stop the player only when it has already been created.
    if !isempty(lecteur)
      % Ignore device-specific stop errors during cleanup.
      try
        stop(lecteur);
      catch
      end_try_catch
    endif
    % Clear the handle so a future round loads a fresh player.
    lecteur = [];
  endfunction

  % Show a brief flash and conceal the revealed objects beneath it.
  function animer_flash()
    % Ignore extra key presses while the flash is on screen.
    animation_en_cours = true;
    % Place a translucent bright flash over the whole map.
    flash = rectangle('Parent', axes_handle, ...
                      'Position', [0.5, 0.5, columns(pathways), rows(pathways)], ...
                      'FaceColor', [1.00, 0.93, 0.69], ...
                      'FaceAlpha', 0.88, ...
                      'EdgeColor', 'none', ...
                      'Tag', 'flash_camouflage');
    % Display the flash before replacing the revealed sprites.
    drawnow();
    % Keep the secrets hidden after the brief flash ends.
    revelation = false;
    % Remove the flame and egg sprites beneath the flash.
    dessiner_sprites(false);
    % Keep the flash on screen for about one tenth of a second.
    pause(0.10);
    % Stop safely if Escape closed the window during the pause.
    if !ishandle(fenetre), return; endif
    % Remove the flash to reveal the concealed maze.
    if ishandle(flash), delete(flash); endif
    % Display the hidden map without additional delay.
    drawnow();
    % Allow the player to move again.
    animation_en_cours = false;
  endfunction

  % Compose the visible sprites into the map image.
  function dessiner_sprites(montrer_secrets)
    % Begin with a fresh copy of the wall-and-floor background.
    carte = fond_labyrinthe;
    % Draw flames only while the initial reveal is active.
    if montrer_secrets
      % Find the coordinates of every tile containing a flame.
      [lignes_flammes, colonnes_flammes] = find(flames);
      % This loop draws one flame at each trap location.
      for numero = 1:length(lignes_flammes)
        % Place the flame image on its trap tile.
        carte = superposer_sprite(carte, sprite_flamme, ...
                                  [lignes_flammes(numero), colonnes_flammes(numero)]);
      endfor
      % Place the egg image on the  egg tile during the reveal.
      carte = superposer_sprite(carte, sprite_oeuf, egg);
    endif
    % Draw the knight image on the tile occupied by the player.
    carte = superposer_sprite(carte, sprite_chevalier, position);
    % Show the flame above the knight after a loss.
    if partie_terminee && flames(position(1), position(2))
      carte = superposer_sprite(carte, sprite_flamme, position);
    % Show the egg above the knight after a win.
    elseif partie_terminee && coffre(position(1), position(2))
      carte = superposer_sprite(carte, sprite_oeuf, position);
    endif
    % Update the single RGB image that displays the entire board.
    set(image_handle, 'CData', carte);
  endfunction

  % Show one supplied full-screen illustration in place of the maze.
  function afficher_ecran(image_ecran)
    % Hide the map so it cannot show through around the screen image.
    set(image_handle, 'Visible', 'off');
    % Replace the intro artwork and display the requested screen.
    set(ecran_handle, 'CData', image_ecran, 'Visible', 'on');
    % Keep the screen image from intercepting keyboard input.
    set(ecran_handle, 'HitTest', 'off');
    % Remove the title so it does not overlap the supplied artwork.
    title(axes_handle, '');
    % Display the selected screen without waiting for the next game loop.
    drawnow();
  endfunction

  % Hide an illustrated screen and make the maze visible again.
  function cacher_ecran()
    % Hide the screen image and restore the map image underneath.
    set(ecran_handle, 'Visible', 'off');
    set(image_handle, 'Visible', 'on');
  endfunction

  % Convert a key press into a one-tile movement.
  function touche_pressee(~, evenement)
    % Escape closes the game window at any point in the round.
    if ishandle(fenetre) && strcmp(evenement.Key, 'escape')
      termine = true;
      delete(fenetre);
      return;
    endif
    % The intro screen starts the maze only when Space is pressed.
    if strcmp(ecran_actuel, 'intro')
      % Reveal the map when the player confirms the start prompt.
      if strcmp(evenement.Key, 'space')
        % Switch to the maze state and remove the intro illustration.
        ecran_actuel = 'maze';
        cacher_ecran();
        % Show the revealed hazards and explain how to begin moving.
        title(axes_handle, 'Press an arrow key or WASD/ZQSD to start', ...
              'Color', 'white', 'FontSize', 14);
        drawnow();
      endif
      % Ignore movement until the player dismisses the intro screen.
      return;
    endif
    % Space on a result screen starts a fresh maze.
    if strcmp(ecran_actuel, 'win') || strcmp(ecran_actuel, 'lose')
      % Start a new run from either result screen.
      if strcmp(evenement.Key, 'space')
        rejouer([], []);
      endif
      % Ignore movement keys until the new maze is ready.
      return;
    endif
    % Ignore input after closing, during the flash, or once a round has ended.
    if termine || partie_terminee || animation_en_cours || !ishandle(fenetre)
      return;
    endif
    % A zero vector marks a key that does not represent a direction.
    mouvement = [0, 0];
    % Map arrow keys, ZQSD, and WASD to the four directions.
    switch evenement.Key
      % Up arrow, W, or Z moves the dragon up by one tile.
      case {'uparrow', 'w', 'z'}
        mouvement = [-1, 0];
      % Down arrow or S moves the dragon down by one tile.
      case {'downarrow', 's'}
        mouvement = [1, 0];
      % Left arrow, A, or Q moves the dragon left by one tile.
      case {'leftarrow', 'a', 'q'}
        mouvement = [0, -1];
      % Right arrow or D moves the dragon right by one tile.
      case {'rightarrow', 'd'}
        mouvement = [0, 1];
      % Any other key leaves the dragon in place.
      otherwise
        return;
    endswitch

    % Calculate the target tile first so walls can block movement.
    prochaine = position + mouvement;
    % Reject moves that leave the map or run into a wall.
    if prochaine(1) < 1 || prochaine(1) > rows(pathways) || ...
       prochaine(2) < 1 || prochaine(2) > columns(pathways) || ...
       !pathways(prochaine(1), prochaine(2))
      return;
    endif

    % On the first valid move, hide the secrets before moving the dragon.
    if revelation
      % The title announces the flash that conceals the flames and egg.
      title(axes_handle, 'Flash! The hidden items disappear...', ...
            'Color', 'white', 'FontSize', 14);
      % Display the new title before playing the flash.
      drawnow();
      % Stop the intro before starting the in-game background soundtrack.
      lecteur_intro = arreter_effet(lecteur_intro);
      % Start the supplied soundtrack without blocking the game.
      jouer_musique();
      % Use a single flash to conceal the revealed sprites.
      animer_flash();
      % Show movement instructions throughout the maze.
      title(axes_handle, 'Arrows or WASD/ZQSD: move. Escape: quit.', ...
            'Color', 'white', 'FontSize', 14);
    endif

    % The move is valid, so update the knight's position.
    position = prochaine;
    % Redraw the knight while keeping hidden objects concealed.
    rafraichir();
    % Stepping on a flame immediately ends the round in a loss.
    if flames(position(1), position(2))
      % Mark the round as finished so only Replay or Escape can be used.
      partie_terminee = true;
      % Stop the soundtrack when the player loses.
      arreter_musique();
      % Redraw the flame over the knight to show the collision.
      dessiner_sprites(false);
      % Record the loss state so Space can trigger Replay.
      ecran_actuel = 'lose';
      % Show the supplied loss screen and reveal the Replay button.
      afficher_ecran(ecran_defaite);
      set(replay_button, 'Visible', 'on');
      % Play the death sound when the knight hits a flame.
      lecteur_mort = jouer_effet('Egg quest - Death.wav', lecteur_mort);
    % Reaching the  egg means the dragon found its egg.
    elseif coffre(position(1), position(2))
      % Mark the round as finished so only Replay or Escape can be used.
      partie_terminee = true;
      % Stop the soundtrack when the player wins.
      arreter_musique();
      % Redraw the egg over the knight to show the  egg.
      dessiner_sprites(false);
      % Record the victory state so Space can trigger Replay.
      ecran_actuel = 'win';
      % Show the supplied victory screen and reveal the Replay button.
      afficher_ecran(ecran_victoire);
      set(replay_button, 'Visible', 'on');
      % Play the victory sound when the knight reaches the egg.
      lecteur_victoire = jouer_effet('Egg quest - You saved the egg.wav', lecteur_victoire);
    endif
    % Immediately display the result of the key press.
    drawnow();
  endfunction

  % Build the static background image from floor, start, and wall tiles.
  function fond = creer_fond_labyrinthe()
    % Read the maze dimensions before allocating its raster image.
    hauteur = rows(pathways);
    largeur = columns(pathways);
    % Use a dark background behind transparent wall artwork.
    couleur_mur = uint8([20, 23, 31]);
    % Use the warm floor color from the original game palette.
    couleur_sol = uint8([240, 235, 217]);
    % Keep the entrance tile visibly marked in every round.
    couleur_starting_point = uint8([46, 184, 82]);
    % Allocate an RGB image large enough for every maze tile.
    fond = zeros(hauteur * size_sprite, largeur * size_sprite, 3, 'uint8');
    % Visit each maze cell once to draw its static background tile.
    for ligne = 1:hauteur
      % Calculate the pixel rows that belong to this maze row.
      rangee_pixels = (ligne - 1) * size_sprite + (1:size_sprite);
      % Visit every cell in the current row.
      for colonne = 1:largeur
        % Calculate the pixel columns that belong to this maze cell.
        colonne_pixels = (colonne - 1) * size_sprite + (1:size_sprite);
        % Fill walls with a dark color before compositing their texture.
        if !pathways(ligne, colonne)
          % Make a solid-color tile behind the transparent wall sprite.
          tuile = repmat(reshape(couleur_mur, 1, 1, 3), size_sprite, size_sprite);
          % Composite the wall artwork into this tile.
          tuile = superposer_sprite(tuile, sprite_mur, [1, 1]);
        % Fill the start tile with green so the entrance stays identifiable.
        elseif ligne == starting_point(1) && colonne == starting_point(2)
          % Make the entrance tile using its marker color.
          tuile = repmat(reshape(couleur_starting_point, 1, 1, 3), size_sprite, size_sprite);
        % Fill all other open cells with the floor color.
        else
          % Make a solid-color floor tile.
          tuile = repmat(reshape(couleur_sol, 1, 1, 3), size_sprite, size_sprite);
        endif
        % Copy the finished tile into the full maze background image.
        fond(rangee_pixels, colonne_pixels, :) = tuile;
      endfor
    endfor
  endfunction

  % Read an RGB sprite and its separate PNG transparency matrix.
  function sprite = charger_sprite(nom_fichier)
    % Ask Octave for the color matrix, optional colormap, and alpha channel.
    [couleurs, palette_image, alpha] = ...
        imread(fullfile(dossier_assets, nom_fichier));
    % Convert indexed images to RGB when a colormap is present.
    if !isempty(palette_image)
      couleurs = uint8(round(255 * ind2rgb(couleurs, palette_image)));
    endif
    % Make formats without alpha fully opaque.
    if isempty(alpha)
      alpha = uint8(255 * ones(rows(couleurs), columns(couleurs)));
    endif
    % Append the separate alpha matrix as the fourth sprite channel.
    sprite = cat(3, couleurs, alpha);
  endfunction

  % Load a supplied intro or result image and normalize it to RGB.
  function image_ecran = charger_ecran(nom_fichier)
    % Read the screen artwork and optional indexed-image palette.
    [image_ecran, palette_ecran] = imread(fullfile(dossier_assets, nom_fichier));
    % Convert indexed PNG data to RGB when the image uses a color table.
    if !isempty(palette_ecran)
      image_ecran = uint8(round(255 * ind2rgb(image_ecran, palette_ecran)));
    endif
    % Expand grayscale images to three color channels for display.
    if ndims(image_ecran) == 2
      image_ecran = repmat(image_ecran, 1, 1, 3);
    endif
    % Discard alpha because each supplied screen has a solid background.
    if size(image_ecran, 3) == 4
      image_ecran = image_ecran(:, :, 1:3);
    endif
  endfunction

  % Alpha-composite one transparent sprite into a target maze tile.
  function image_cible = superposer_sprite(image_cible, sprite, case_cible)
    % Convert the target maze row into the sprite's first pixel row.
    ligne_debut = (case_cible(1) - 1) * size_sprite + 1;
    % Convert the target maze row into the sprite's last pixel row.
    ligne_fin = case_cible(1) * size_sprite;
    % Convert the target maze column into the sprite's first pixel column.
    colonne_debut = (case_cible(2) - 1) * size_sprite + 1;
    % Convert the target maze column into the sprite's last pixel column.
    colonne_fin = case_cible(2) * size_sprite;
    % Extract the destination tile from the larger RGB image.
    tuile_cible = double(image_cible(ligne_debut:ligne_fin, colonne_debut:colonne_fin, :));
    % Convert the sprite opacity channel to values between zero and one.
    alpha = double(sprite(:, :, 4)) / 255;
    % Blend the red, green, and blue channels with the underlying tile.
    for canal = 1:3
      % Read the matching color channel from the transparent sprite.
      canal_sprite = double(sprite(:, :, canal));
      % Composite the sprite only where its alpha channel is nonzero.
      tuile_cible(:, :, canal) = tuile_cible(:, :, canal) .* (1 - alpha) + ...
                                  canal_sprite .* alpha;
    endfor
    % Store the blended tile back as an RGB image.
    image_cible(ligne_debut:ligne_fin, colonne_debut:colonne_fin, :) = ...
        uint8(round(tuile_cible));
  endfunction
endfunction


% 2ND PART - MAZE GENERATION: layout, paths, traps, and egg placement


% Generate a random maze and construct its routes.
function [pathways, starting_point, egg, flames] = generer_labyrinthe(maze_size, flame_number)
  % Start near the middle of the upper edge so an early left-right choice is possible.
  starting_point = [2, 2 * ceil(maze_size / 2)];
  % Retry until three separate shortcuts and enough trap tiles are found.
  for essai = 1:500
    % First build a perfect maze with no loops.
    pathways = creer_labyrinthe(maze_size);
    % List the two bottom corners so the  egg stays far from the start.
    coins = [2 * maze_size, 2; 2 * maze_size, 2 * maze_size];
    % Choose one of the far bottom corners at random.
    egg = coins(randi(rows(coins)), :);
    % Find the unique route between the start and  egg in the perfect maze.
    chemin_initial = trouver_chemin(pathways, starting_point, egg, maze_size);
    % Skip routes that cannot supply danger cells in every maze quadrant.
    midpoint = floor(maze_size / 2);
    path_cells = chemin_initial / 2;
    path_quadrants = [sum(path_cells(:, 1) <= midpoint & path_cells(:, 2) <= midpoint), ...
                      sum(path_cells(:, 1) <= midpoint & path_cells(:, 2) > midpoint), ...
                      sum(path_cells(:, 1) > midpoint & path_cells(:, 2) <= midpoint), ...
                      sum(path_cells(:, 1) > midpoint & path_cells(:, 2) > midpoint)];
    % Retry immediately if the unique route misses part of the maze.
    if any(path_quadrants < 3)
      continue;
    endif
    % Store closed walls that could be opened to create shortcuts.
    raccourcis = zeros(0, 3);

    % This loop chooses the first point on the route to connect.
    for i = 1:rows(chemin_initial)-2
      % This loop chooses a later point on the original route.
      for j = i+2:rows(chemin_initial)
        % Neighboring cell centers have a Manhattan distance of two.
        if sum(abs(chemin_initial(i, :) - chemin_initial(j, :))) == 2
          % The tile between the centers is the wall that could become a passage.
          mur = (chemin_initial(i, :) + chemin_initial(j, :)) / 2;
          % A closed wall between route cells can create a useful shortcut.
          if !pathways(mur(1), mur(2))
            % Save the route indices and the wall's linear matrix index.
            raccourcis(end + 1, :) = [i, j, sub2ind(size(pathways), mur(1), mur(2))];
          endif
        endif
      endfor
    endfor

    % Store groups of three shortcuts with separated route segments.
    triplets = zeros(0, 3);
    % This loop chooses the group's first shortcut.
    for a = 1:rows(raccourcis)-2
      % This loop chooses the second shortcut after the first.
      for b = a+1:rows(raccourcis)-1
        % This loop chooses the third shortcut after the second.
        for c = b+1:rows(raccourcis)
          % All three segments must be separate and ordered along the route.
          if raccourcis(a, 2) + 3 < raccourcis(b, 1) && ...
             raccourcis(b, 2) + 3 < raccourcis(c, 1)
            % Save this group; its shortcuts create eight route combinations.
            triplets(end + 1, :) = [a, b, c];
          endif
        endfor
      endfor
    endfor

    % Generate another maze if no group of three separate shortcuts exists.
    if isempty(triplets)
      continue;
    endif

    % Score winding, branch capacity, the opening fork, and quadrant coverage.
    scores = zeros(rows(triplets), 14);
    for candidat = 1:rows(triplets)
      % Get the three shortcuts for this candidate route.
      raccourci_a = raccourcis(triplets(candidat, 1), :);
      raccourci_b = raccourcis(triplets(candidat, 2), :);
      raccourci_c = raccourcis(triplets(candidat, 3), :);
      % Read the start and end indices of the three replaced segments.
      ia = raccourci_a(1); ja = raccourci_a(2);
      ib = raccourci_b(1); jb = raccourci_b(2);
      ic = raccourci_c(1); jc = raccourci_c(2);
      % Count the route tiles bypassed by the three safe shortcuts.
      branch_tiles = (ja - ia - 1) + (jb - ib - 1) + (jc - ic - 1);
      % Locate the first shortcut along the route from the starting cell.
      first_fork = min([ia, ib, ic]);
      % Check whether the original route or a shortcut opens a left-hand route.
      left_neighbor = [starting_point(1), starting_point(2) - 2];
      left_option = all(chemin_initial(2, :) == left_neighbor) || ...
                    (ia == 1 && all(chemin_initial(ja, :) == left_neighbor)) || ...
                    (ib == 1 && all(chemin_initial(jb, :) == left_neighbor)) || ...
                    (ic == 1 && all(chemin_initial(jc, :) == left_neighbor));
      % Store individual branch capacities to distribute flames across all three.
      branch_capacities = [ja - ia - 1, jb - ib - 1, jc - ic - 1];
      % Measure how close the later two branches are to the egg.
      late_branches = [chemin_initial(ib + 1:jb - 1, :); ...
                       chemin_initial(ic + 1:jc - 1, :)];
      late_egg_distance = mean(sqrt(sum((late_branches - repmat(egg, ...
                                  rows(late_branches), 1)) .^ 2, 2))) / (2 * maze_size);
      % Convert the branch tiles to logical maze row and column coordinates.
      branch_cells = [chemin_initial(ia + 1:ja - 1, :); ...
                      chemin_initial(ib + 1:jb - 1, :); ...
                      chemin_initial(ic + 1:jc - 1, :)];
      logical_cells = branch_cells / 2;
      % Split the maze at its midpoint to count cells in all four quadrants.
      midpoint = floor(maze_size / 2);
      quadrant_counts = [sum(logical_cells(:, 1) <= midpoint & logical_cells(:, 2) <= midpoint), ...
                         sum(logical_cells(:, 1) <= midpoint & logical_cells(:, 2) > midpoint), ...
                         sum(logical_cells(:, 1) > midpoint & logical_cells(:, 2) <= midpoint), ...
                         sum(logical_cells(:, 1) > midpoint & logical_cells(:, 2) > midpoint)];
      % Skip expensive route scoring when this candidate cannot meet the flame rules.
      if branch_tiles < flame_number || any(quadrant_counts < 3)
        scores(candidat, :) = [0, 0, 0, branch_tiles, first_fork, ...
                               left_option, branch_capacities, late_egg_distance, ...
                               quadrant_counts];
        continue;
      endif
      % Build the route that uses all three shortcuts.
      route_candidate = [chemin_initial(1:ia, :); ...
                         chemin_initial(ja:ib, :); ...
                         chemin_initial(jb:ic, :); ...
                         chemin_initial(jc:end, :)];
      % Measure its turns, longest straight run, and number of steps.
      [turn_count, longest_straight] = measure_winding(route_candidate);
      % Store winding, branch capacity, fork data, egg distance, and quadrant counts.
      scores(candidat, :) = [turn_count, longest_straight, ...
                             rows(route_candidate) - 1, branch_tiles, ...
                             first_fork, left_option, branch_capacities, ...
                             late_egg_distance, quadrant_counts];
    endfor

    % Reserve enough branch tiles overall for the requested flame count.
    enough_branch_tiles = scores(:, 4) >= flame_number;
    % Require at least three route tiles in every quadrant for flame placement.
    quadrant_coverage = all(scores(:, 11:14) >= 3, 2);
    % Prefer a meaningful choice near the start when the maze can provide one.
    early_fork = scores(:, 5) <= 3;
    % Keep routes with enough tiles and coverage across the whole maze.
    structure_candidates = find(enough_branch_tiles & quadrant_coverage);
    % Prefer structures whose first fork appears near the start.
    core_candidates = structure_candidates(scores(structure_candidates, 5) <= 3);
    % Keep the maze if all quadrants are covered, even if the fork is later.
    if isempty(core_candidates)
      core_candidates = structure_candidates;
    endif
    % Prefer an actual left-hand route when this maze can provide one.
    left_route_candidates = core_candidates(scores(core_candidates, 6) == 1);
    % Keep the maze playable even when no early left-hand shortcut exists.
    if !isempty(left_route_candidates)
      core_candidates = left_route_candidates;
    endif
    % Retry only if this maze lacks the required route structure.
    if isempty(core_candidates)
      continue;
    endif
    % First prefer a strongly winding route with short straight sections.
    minimum_turns = max(5, ceil(0.30 * scores(:, 3)));
    winding_candidates = core_candidates(scores(core_candidates, 1) >= minimum_turns(core_candidates) & ...
                                         scores(core_candidates, 2) <= 4);
    % If needed, accept a moderately winding route to avoid delaying the game.
    if isempty(winding_candidates)
      relaxed_turns = max(3, ceil(0.20 * scores(core_candidates, 3)));
      winding_candidates = core_candidates(scores(core_candidates, 1) >= relaxed_turns & ...
                                           scores(core_candidates, 2) <= 6);
    endif
    % Use the strongest available route if this maze has no stricter candidate.
    if isempty(winding_candidates)
      winding_candidates = core_candidates;
    endif

    % Prefer winding routes with late danger branches near the egg and a left option.
    winding_scores = scores(winding_candidates, 1) ./ scores(winding_candidates, 3) ...
                     - 0.02 * scores(winding_candidates, 2) ...
                     - 0.02 * scores(winding_candidates, 5) ...
                     + 0.08 * scores(winding_candidates, 6) ...
                     - 0.12 * scores(winding_candidates, 10);
    % Keep only the candidates with the strongest winding score.
    best_candidates = winding_candidates(winding_scores == max(winding_scores));
    % Randomly choose among equally winding safe routes.
    selected = best_candidates(randi(length(best_candidates)));
    triplet = triplets(selected, :);
    % Get the first shortcut's data.
    raccourci1 = raccourcis(triplet(1), :);
    % Get the second shortcut's data.
    raccourci2 = raccourcis(triplet(2), :);
    % Get the third shortcut's data.
    raccourci3 = raccourcis(triplet(3), :);
    % These indices mark the route segment replaced by the first shortcut.
    i1 = raccourci1(1);
    j1 = raccourci1(2);
    % These indices mark the route segment replaced by the second shortcut.
    i2 = raccourci2(1);
    j2 = raccourci2(2);
    % These indices mark the route segment replaced by the third shortcut.
    i3 = raccourci3(1);
    j3 = raccourci3(2);
    % Open the wall selected for the first shortcut.
    pathways(raccourci1(3)) = true;
    % Open the wall selected for the second shortcut.
    pathways(raccourci2(3)) = true;
    % Open the wall selected for the third shortcut.
    pathways(raccourci3(3)) = true;

    % Build the safe route by using all three shortcuts.
    chemin_sur = [chemin_initial(1:i1, :); ...
                  chemin_initial(j1:i2, :); ...
                  chemin_initial(j2:i3, :); ...
                  chemin_initial(j3:end, :)];
    % Collect route tiles on the three branches skipped by the safe shortcuts.
    branche1 = chemin_initial(i1 + 1:j1 - 1, :);
    branche2 = chemin_initial(i2 + 1:j2 - 1, :);
    branche3 = chemin_initial(i3 + 1:j3 - 1, :);
    % Keep the three connecting branches separate for balanced flame placement.
    branches = {branche1, branche2, branche3};
    % Place one mandatory flame on each branch to make every choice meaningful.
    piege_obligatoire1 = branche1(randi(rows(branche1)), :);
    piege_obligatoire2 = branche2(randi(rows(branche2)), :);
    piege_obligatoire3 = branche3(randi(rows(branche3)), :);
    % This logical map stores the locations of all traps.
    flames = false(size(pathways));
    % The first trap blocks the first old route segment.
    flames(piege_obligatoire1(1), piege_obligatoire1(2)) = true;
    % The second trap blocks the second old route segment.
    flames(piege_obligatoire2(1), piege_obligatoire2(2)) = true;
    % The third trap blocks the third old route segment.
    flames(piege_obligatoire3(1), piege_obligatoire3(2)) = true;

    % Start a list of placed flames for spacing later choices.
    positions_flames = [piege_obligatoire1; piege_obligatoire2; piege_obligatoire3];
    % Combine branch tiles because every one can lie on a route to the egg.
    branch_tiles = [branche1; branche2; branche3];
    % Remove the three mandatory flames from the remaining candidates.
    remaining_tiles = branch_tiles(!ismember(branch_tiles, positions_flames, 'rows'), :);
    % Assign a quadrant number to every possible danger tile.
    logical_cells = branch_tiles / 2;
    midpoint = floor(maze_size / 2);
    quadrants = zeros(rows(branch_tiles), 1);
    quadrants(logical_cells(:, 1) <= midpoint & logical_cells(:, 2) <= midpoint) = 1;
    quadrants(logical_cells(:, 1) <= midpoint & logical_cells(:, 2) > midpoint) = 2;
    quadrants(logical_cells(:, 1) > midpoint & logical_cells(:, 2) <= midpoint) = 3;
    quadrants(logical_cells(:, 1) > midpoint & logical_cells(:, 2) > midpoint) = 4;
    % Add enough branch flames to bring every quadrant up to three.
    for quadrant = 1:4
      % Count flames already placed in this quadrant.
      logical_positions = positions_flames / 2;
      position_quadrants = zeros(rows(positions_flames), 1);
      position_quadrants(logical_positions(:, 1) <= midpoint & logical_positions(:, 2) <= midpoint) = 1;
      position_quadrants(logical_positions(:, 1) <= midpoint & logical_positions(:, 2) > midpoint) = 2;
      position_quadrants(logical_positions(:, 1) > midpoint & logical_positions(:, 2) <= midpoint) = 3;
      position_quadrants(logical_positions(:, 1) > midpoint & logical_positions(:, 2) > midpoint) = 4;
      % Calculate how many flames are still needed here.
      needed = max(0, 3 - sum(position_quadrants == quadrant));
      % Keep only unused branch cells in the current quadrant.
      candidates = branch_tiles(quadrants == quadrant, :);
      candidates = candidates(!ismember(candidates, positions_flames, 'rows'), :);
      % Place the missing flames at randomly selected well-spaced cells.
      for k = 1:needed
        % Measure each candidate's distance from every placed flame.
        distances = abs(candidates(:, 1) - positions_flames(:, 1)') + ...
                    abs(candidates(:, 2) - positions_flames(:, 2)');
        % Favor a tile farther from its nearest existing flame.
        nearest_flame = min(distances, [], 2);
        % Randomize among equally spaced candidates.
        best_tiles = find(nearest_flame == max(nearest_flame));
        tile_index = best_tiles(randi(length(best_tiles)));
        % Place the selected flame and reserve its tile.
        coord = candidates(tile_index, :);
        flames(coord(1), coord(2)) = true;
        positions_flames(end + 1, :) = coord;
        candidates(tile_index, :) = [];
        remaining_tiles(all(remaining_tiles == coord, 2), :) = [];
      endfor
    endfor
    % Place any flames beyond the required three per quadrant.
    while rows(positions_flames) < flame_number
      % Favor the remaining route tile farthest from all placed flames.
      distances = abs(remaining_tiles(:, 1) - positions_flames(:, 1)') + ...
                  abs(remaining_tiles(:, 2) - positions_flames(:, 2)');
      nearest_flame = min(distances, [], 2);
      best_tiles = find(nearest_flame == max(nearest_flame));
      tile_index = best_tiles(randi(length(best_tiles)));
      coord = remaining_tiles(tile_index, :);
      flames(coord(1), coord(2)) = true;
      positions_flames(end + 1, :) = coord;
      remaining_tiles(tile_index, :) = [];
    endwhile
    % The maze is ready, so return its maps and coordinates.
    return;
  endfor

  % After too many attempts, ask the caller to reduce the settings.
  error('Could not generate this maze. Reduce the size or trap count.');
endfunction

% Measure how winding a cell-center route is.
function [turn_count, longest_straight] = measure_winding(route)
  % Differences between consecutive centers give the movement directions.
  directions = sign(diff(route, 1, 1));
  % Start with no turns and no measured straight run.
  turn_count = 0;
  longest_straight = 0;
  current_straight = 0;
  % Count direction changes and track the longest sequence in one direction.
  for step = 1:rows(directions)
    % A changed direction means the route turns at this step.
    if step > 1 && !all(directions(step, :) == directions(step - 1, :))
      turn_count += 1;
      longest_straight = max(longest_straight, current_straight);
      current_straight = 0;
    endif
    % Add the current step to its straight run.
    current_straight += 1;
  endfor
  % Include the final straight run in the maximum.
  longest_straight = max(longest_straight, current_straight);
endfunction

% Open every cell in a random spanning tree without creating loops.
function pathways = creer_labyrinthe(maze_size)
  % The displayed grid puts a wall row between each row of maze cells.
  pathways = false(2 * maze_size + 1, 2 * maze_size + 1);
  % Track which logical maze cells have already been visited.
  visite = false(maze_size, maze_size);
  % This stack stores the path followed by depth-first search.
  pile = zeros(maze_size * maze_size, 2);
  % The depth records how many cells are currently on the stack.
  profondeur = 1;
  % Start the traversal in the first logical cell.
  pile(1, :) = [1, 1];
  % Mark the starting cell as visited.
  visite(1, 1) = true;
  % Open the center tile of the start on the displayed map.
  pathways(2, 2) = true;
  % These four vectors represent the cardinal directions.
  directions = [-1, 0; 1, 0; 0, -1; 0, 1];

  % Stop when every branch on the stack has been explored.
  while profondeur > 0
    % Read the logical cell at the top of the stack.
    ligne = pile(profondeur, 1);
    % Read its logical column.
    colonne = pile(profondeur, 2);
    % Store valid neighboring cells that have not been visited yet.
    voisins = zeros(0, 3);
    % Check each of the four directions from the current cell.
    for d = 1:4
      % Calculate the candidate neighbor's row.
      nl = ligne + directions(d, 1);
      % Calculate the candidate neighbor's column.
      nc = colonne + directions(d, 2);
      % Keep the neighbor if it is inside the grid and has not been visited.
      if nl >= 1 && nl <= maze_size && nc >= 1 && nc <= maze_size && !visite(nl, nc)
        % Store its coordinates and the direction that reaches it.
        voisins(end + 1, :) = [nl, nc, d];
      endif
    endfor
    % If there is no unvisited neighbor, backtrack to the previous cell.
    if isempty(voisins)
      profondeur -= 1;
    % Otherwise, randomly choose one of the unvisited neighbors.
    else
      % Randomly select one neighbor from the available list.
      choix = randi(rows(voisins));
      % Get the next cell's row.
      nl = voisins(choix, 1);
      % Get the next cell's column.
      nc = voisins(choix, 2);
      % Get the cardinal direction that leads to this neighbor.
      d = voisins(choix, 3);
      % The tile halfway between the centers is the wall between the cells.
      milieu = [2 * ligne, 2 * colonne] + directions(d, :);
      % Open the wall to create a passage between the cells.
      pathways(milieu(1), milieu(2)) = true;
      % Open the center tile of the new neighbor.
      pathways(2 * nl, 2 * nc) = true;
      % Mark the neighbor visited so it is not processed again.
      visite(nl, nc) = true;
      % Push the neighbor onto the search stack.
      profondeur += 1;
      % Store the neighbor's logical coordinates on the stack.
      pile(profondeur, :) = [nl, nc];
    endif
  endwhile
endfunction

% Find the unique route in the perfect maze before adding loops.
function chemin = trouver_chemin(pathways, starting_point, egg, maze_size)
  % Convert the map's even coordinates to logical cell coordinates.
  starting_point_cellule = starting_point / 2;
  % Convert the  egg location to logical cell coordinates as well.
  egg_cellule = egg / 2;
  % This mask prevents logical cells from being visited more than once.
  visite = false(maze_size, maze_size);
  % Store each cell's parent index here to reconstruct the route.
  parents = zeros(maze_size * maze_size, 1);
  % This queue stores cells waiting to be explored by breadth-first search.
  file = zeros(maze_size * maze_size, 2);
  % 'debut' points to the next cell to process in the queue.
  debut = 1;
  % 'fin' points to the last occupied queue entry.
  fin = 1;
  % Put the starting cell in the queue first.
  file(1, :) = starting_point_cellule;
  % Mark the start so it is not added to the queue again.
  visite(starting_point_cellule(1), starting_point_cellule(2)) = true;
  % Use the same four directions to inspect neighbors.
  directions = [-1, 0; 1, 0; 0, -1; 0, 1];

  % Continue while there are cells left in the queue.
  while debut <= fin
    % Get the next cell to examine and advance the queue.
    cellule = file(debut, :);
    debut += 1;
    % Stop once the egg cell is reached.
    if all(cellule == egg_cellule)
      break;
    endif
    % Examine the current cell's four neighbors.
    for d = 1:4
      % Calculate the neighbor's logical coordinates.
      voisin = cellule + directions(d, :);
      % First check that the neighbor is inside the grid.
      if voisin(1) >= 1 && voisin(1) <= maze_size && ...
         voisin(2) >= 1 && voisin(2) <= maze_size && ...
         !visite(voisin(1), voisin(2))
        % Find the wall tile between the current cell and its neighbor.
        mur = [2 * cellule(1), 2 * cellule(2)] + directions(d, :);
        % The neighbor is reachable only when the intervening wall is open.
        if pathways(mur(1), mur(2))
          % Mark the neighbor visited before adding it to the queue.
          visite(voisin(1), voisin(2)) = true;
          % Reserve the next queue position.
          fin += 1;
          % Add the neighbor's coordinates to that position.
          file(fin, :) = voisin;
          % Save its parent's index so the route can be reconstructed.
          parents(sub2ind([maze_size, maze_size], voisin(1), voisin(2))) = ...
              sub2ind([maze_size, maze_size], cellule(1), cellule(2));
        endif
      endif
    endfor
  endwhile

  % Start reconstructing the route from the egg's logical index.
  index = sub2ind([maze_size, maze_size], egg_cellule(1), egg_cellule(2));
  % This list stores the egg and each parent back to the start.
  indices = index;
  % Calculate the start index to know when reconstruction is complete.
  starting_point_index = sub2ind([maze_size, maze_size], starting_point_cellule(1), starting_point_cellule(2));
  % Follow parent indices backward until reaching the start.
  while index != starting_point_index
    % Move from the current cell to its parent.
    index = parents(index);
    % Append the parent to the reconstructed route.
    indices(end + 1) = index;
  endwhile
  % Reverse the list so it runs from the start to the  egg.
  indices = fliplr(indices);
  % Convert linear indices into logical rows and columns.
  [lignes, colonnes] = ind2sub([maze_size, maze_size], indices);
  % Convert the logical coordinates back to display-map positions.
  chemin = [2 * lignes(:), 2 * colonnes(:)];
endfunction
