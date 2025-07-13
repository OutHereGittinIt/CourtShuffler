function court_shuffler
%
% Experiemnt w/ and display diffferent game-leveling 
%
% 5/3/2025

dbstop if error
hold on, grid on, axis equal

num_rounds          = 20;
num_courts          = 32;
num_cols            = 8;

opts.axes_sz        = [700,700];
opts.bias_strength  = .2;
opts.corr_ax_h      = 400; % correlation plot axes height
opts.court_clr      = [.6,.9,.55];
opts.court_lw       = 1.5;
opts.court_spacer   = 25;
opts.court_sz       = [100,180];
opts.left_tab_w     = 500;
opts.step_sz        = 5;
opts.dt             = .05;
opts.player_ms      = 30; % player marker size
opts.player_pos_in  = 25;
opts.serive_line    = .33;
opts.spacer         = 7;

% draw courts
[f,court_axes,court_pos] = create_courts(num_courts,num_cols,opts);

% draw players
Players = create_players(court_axes,num_courts,court_pos,opts);

% correlation plot (duh)
add_correlation_plot(f,opts);

% ~~~ I forgot what this does or why its needed
Xmin = court_axes.XLim(1);
Xmax = court_axes.XLim(2);
court_axes.XLimMode = 'manual';
court_axes.XLim = [Xmin,Xmax];

% iterate rounds
pause(1)
for round = 1:num_rounds
    pause(.5)
    Players = advance_round(f,Players,court_pos,Xmin,Xmax,opts);
    fprintf('Finished round %d\n',round) % ~~~ rmv and substitute for
end
end

function [f,ax_obj,court_pos] = create_courts(num_courts,num_cols,opts)
%% Draw courts and assign positions

% create uifigure and uiaxes
f = uifigure('Name','Court Shuffler');
ax_obj = uiaxes(f);

% return positions -- currently just single-file horizontal
if num_courts <= num_cols
    court_ind   = 1:num_courts;
    court_pos_x = (court_ind-1)*opts.court_sz(1) + court_ind*opts.court_spacer;
    court_pos   = [court_pos_x',zeros(num_courts,1)];
    num_rows    = 1;
else
    [court_pos,num_rows] = set_court_pos_matrix(num_courts,num_cols,opts);
end

% sizing for axes and uifigure
ax_obj.Position = [opts.left_tab_w + opts.spacer,opts.spacer,opts.axes_sz];
f.Position(3:4) = opts.axes_sz + [opts.left_tab_w + 3*opts.spacer,2*opts.spacer];
centerfig(f)

% function handle for line drawing
draw_line = @(x,y,court_ind) plot(ax_obj,court_pos(court_ind,1) + x,court_pos(court_ind,2) + y,"Color",[1,1,1],'LineWidth',opts.court_lw);

% draw courts
for court_ind = 1:num_courts
    
    % court
    rectangle('Position',[court_pos(court_ind,:),opts.court_sz],"FaceColor",opts.court_clr);
    
    % lines :
    % perimeter 
    X = opts.court_sz(1); Y = opts.court_sz(2); % brevity
    draw_line([0,X],[0,0],court_ind)
    draw_line([X,X],[0,Y],court_ind)
    draw_line([0,X],[Y,Y],court_ind)
    draw_line([0,0],[0,Y],court_ind)
    
    % service
    Y = (0.5 + [-1,1]*opts.serive_line/2) * opts.court_sz(2);
    draw_line([0,X],[Y(1),Y(1)],court_ind)
    draw_line([0,X],[Y(2),Y(2)],court_ind)

    % middle
    draw_line([X/2,X/2],[0,Y(1)],court_ind)
    draw_line([X/2,X/2],[opts.court_sz(2),Y(2)],court_ind)
end
end

function Players = create_players(court_axes,num_courts,court_pos,opts)
%% create players w/ random skill, distribute among courts

player_count = 0;
Players(num_courts*4,1) = struct;

for court_ind = 1:num_courts
    for player_ind = 1:4
        player_count = player_count + 1;

        % assign court, team, and l/r
        Players(player_count).Court = court_ind;
        Players(player_count).Team  = ceil(player_ind/2);
        if mod(player_ind,2)
            Players(player_count).Side = 'left';
        else
            Players(player_count).Side = 'right';
        end
        Players(player_count).NextCourt = court_ind; % incase court 1 and wins or court(end) and loses

        % assign value
        val = rand();
        Players(player_count).Skill = val;
        blue = .15;
        color = [1-val,val,blue]; % r g b. red is bad, green is good

        % initial position
        pos = get_pos(Players(player_count),court_pos,opts);

        % plot and store object
        Players(player_count).Object = plot(court_axes,pos(1),pos(2),'Color',color,'Marker','.','MarkerSize',opts.player_ms);
    end
end
end

function pos = get_pos(Player,court_pos,opts)
%% Return x and y position for player

% court position
pos = court_pos(Player.Court,:);

% add y-delta
if Player.Team == 1
    delta_y = opts.player_pos_in;
elseif Player.Team == 2
    delta_y = opts.court_sz(2) - opts.player_pos_in;
else
    error('invalid team entry')
end
pos(2) = pos(2) + delta_y;

% add x-delta
if strcmpi(Player.Side,'left')
    delta_x = opts.player_pos_in;
elseif strcmpi(Player.Side,'right')
    delta_x = opts.court_sz(1) - opts.player_pos_in;
else
    error('invalid Side entry')
end
pos(1) = pos(1) + delta_x;
end

function Players = advance_round(f,Players,court_pos,Xmin,Xmax,opts)
%% Play next game and move players around with animation (one round)

num_courts = height(court_pos);

% play games and establish "next court"
Players = play_games(Players,num_courts,opts);

% move players to next court after all games finished
for i = 1:numel(Players)
    Players(i).Court = Players(i).NextCourt;
end

% sort teams and sides
Players = sort_new_teams(Players,num_courts);

% move players to new game
annimate_movement(Players,court_pos,Xmin,Xmax,opts)

% calculate and show new correlation stats
update_correlation_plot(f,Players)

update_round_coutner()
end

function Players = play_games(Players,num_courts,opts)
%% Play game and move courts for players based on outcome, for each court

% cycle through each court
for court_ind = 1:num_courts

    [team1,team2] = find_game_players(Players,court_ind);

    % random bias, worth .2
    bias = 2*opts.bias_strength*rand() - opts.bias_strength;
    team_1_victory = sum([Players(team1).Skill]) - sum([Players(team2).Skill]) + bias > 0; % ~~~ maybe add 'chemistry' term later

    % move courts 
    if team_1_victory
        winners = team1;
        losers = team2;
    else
        winners = team2;
        losers = team1;
    end

    % move up winning team
    if court_ind ~= 1
        [Players(winners).NextCourt] = deal(court_ind - 1);
    end

    % move down losing team
    if court_ind ~= num_courts
        [Players(losers).NextCourt] = deal(court_ind + 1);
    end
end
end

function [team1,team2] = find_game_players(Players,court_ind)
%% Find players and teams for given court
game_players = find([Players.Court] == court_ind);
team1 = game_players([Players(game_players).Team] == 1);
team2 = game_players([Players(game_players).Team] == 2);

if numel(team1) ~= 2 || numel(team2) ~= 2
    error('invalid game setup')
end
end

function Players = sort_new_teams(Players,num_courts)
%% re-assign teams and sides for next game

% cycle through each court
for court_ind = 1:num_courts
    game_players = find([Players.Court] == court_ind);

    if numel(game_players) ~= 4
        error('invalid number players on court')
    end

    % random placement to times and sides
    rand_order = (randperm(4));

    team1 = game_players(rand_order(1:2));
    team2 = game_players(rand_order(3:4));
    [Players(team1).Team] = deal(1);
    [Players(team2).Team] = deal(2);

    Players(team1(1)).Side = 'left';
    Players(team2(1)).Side = 'left';
    Players(team1(2)).Side = 'right';
    Players(team2(2)).Side = 'right';
end
end

function annimate_movement(Players,court_pos,Xmin,Xmax,opts)
%% Show players moving to new position

% idea :
% run through and establish the dx and dy for the step of each player

% then run through time cycles and send players to their new spots. make
% exact when close enough

% find xvec, yvec, and num steps for each player
for p_ind = 1:numel(Players)

    % get new position 
    new_pos = get_pos(Players(p_ind),court_pos,opts);

    x0 = Players(p_ind).Object.XData;
    y0 = Players(p_ind).Object.YData;
    dx = new_pos(1) - x0;
    dy = new_pos(2) - y0;

    % wrap-around courts for shorter travel
    if abs(dx) > 2*opts.court_sz(1)
        dx = (Xmax - Xmin) - abs(new_pos(1) - x0);
        long_horz = true;
    else
        long_horz = false;
    end

    r = norm([dx,dy]);

    dx = opts.step_sz*dx/r;
    dy = opts.step_sz*dy/r;

    if long_horz
        if new_pos(1) > x0
            Players(p_ind).xvec = [x0:-dx:Xmin,Xmax:-dx:new_pos(1)];
        else
            Players(p_ind).xvec = [x0:dx:Xmax,Xmin:dx:new_pos(1)];
        end
    else
        Players(p_ind).xvec     = x0:dx:new_pos(1);
    end
    Players(p_ind).yvec     = y0:dy:new_pos(2);
    Players(p_ind).its      = ceil(r/opts.step_sz);
    Players(p_ind).end_pos  = new_pos;
end

total_steps = max([Players.its]) + 1;

% advance players one step at a time
for step = 1:total_steps
    for p_ind = 1:numel(Players)
        if step < Players(p_ind).its
            if ~isempty(Players(p_ind).xvec)
                Players(p_ind).Object.XData = Players(p_ind).xvec(step);
            end
            if ~isempty(Players(p_ind).yvec)
                Players(p_ind).Object.YData = Players(p_ind).yvec(step);
            end
        elseif step == Players(p_ind).its
            if ~isempty(Players(p_ind).xvec)
                Players(p_ind).Object.XData = Players(p_ind).end_pos(1);
            end
            if ~isempty(Players(p_ind).yvec)
                Players(p_ind).Object.YData = Players(p_ind).end_pos(2);
            end
        end
    end
    drawnow
    pause(opts.dt)
end
end

function [court_pos,num_rows] = set_court_pos_matrix(num_courts,num_cols,opts)
%% Return court positions for multiple rows of courts

court_ind = 0;
num_rows = ceil(num_courts/num_cols);
court_pos = zeros(num_courts,2);
ypos = 0;
for row_ind = 1:num_rows
    % move vert 
    ypos = ypos - opts.court_spacer - opts.court_sz(2);
    xpos = 0;
    for col_ind = 1:num_cols
        % exit when done
        court_ind = court_ind + 1;
        if court_ind > num_courts
            return
        end
        % move horz
        xpos = xpos + opts.court_spacer + opts.court_sz(1);

        % set court pos
        court_pos(court_ind,:) = [xpos,ypos];
    end
end
end

function add_correlation_plot(f,opts)
%% Add Correlation Plot

% create axes for correlation plot
a = uiaxes(f,'Position',[opts.spacer,opts.spacer,opts.left_tab_w,opts.corr_ax_h]);
a.Title.String = 'R-coefficient for player skill level and court number';

% add line
plot(a,[],[],'Tag','Correlation Plot');
end

function update_correlation_plot(f,Players)
%% calculate and show new correlation stats
% actually you dont need round, you just add to ydata

% calculate R coef.

% ok we want the r coef. for player skill and player court

% we obviously need a label for that
LM      = fitlm([Players.Court],[Players.Skill]);
Rcoeff  = LM.Rsquared.Ordinary;

% find or create plot object
corr_plot = findobj(f,'Tag','Correlation Plot');

% add new datapoint to plot object ydata and ydata
new_ydata = [corr_plot.YData,Rcoeff];
new_xdata = [corr_plot.XData,numel(corr_plot.XData) + 1];
set(corr_plot,'XData',new_xdata,'YData',new_ydata)
end