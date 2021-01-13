-module(server).

-export([start_server/0]).

-include_lib("./defs.hrl").

-spec start_server() -> _.
-spec loop(_State) -> _.
-spec do_join(_ChatName, _ClientPID, _Ref, _State) -> _.
-spec do_leave(_ChatName, _ClientPID, _Ref, _State) -> _.
-spec do_new_nick(_State, _Ref, _ClientPID, _NewNick) -> _.
-spec do_client_quit(_State, _Ref, _ClientPID) -> _NewState.

start_server() ->
    catch(unregister(server)),
    register(server, self()),
    case whereis(testsuite) of
	undefined -> ok;
	TestSuitePID -> TestSuitePID!{server_up, self()}
    end,
    loop(
      #serv_st{
	 nicks = maps:new(), %% nickname map. client_pid => "nickname"
	 registrations = maps:new(), %% registration map. "chat_name" => [client_pids]
	 chatrooms = maps:new() %% chatroom map. "chat_name" => chat_pid
	}
     ).

loop(State) ->
    receive 
	%% initial connection
	{ClientPID, connect, ClientNick} ->
	    NewState =
		#serv_st{
		   nicks = maps:put(ClientPID, ClientNick, State#serv_st.nicks),
		   registrations = State#serv_st.registrations,
		   chatrooms = State#serv_st.chatrooms
		  },
	    loop(NewState);
	%% client requests to join a chat
	{ClientPID, Ref, join, ChatName} ->
	    NewState = do_join(ChatName, ClientPID, Ref, State),
	    loop(NewState);
	%% client requests to join a chat
	{ClientPID, Ref, leave, ChatName} ->
	    NewState = do_leave(ChatName, ClientPID, Ref, State),
	    loop(NewState);
	%% client requests to register a new nickname
	{ClientPID, Ref, nick, NewNick} ->
	    NewState = do_new_nick(State, Ref, ClientPID, NewNick),
	    loop(NewState);
	%% client requests to quit
	{ClientPID, Ref, quit} ->
	    NewState = do_client_quit(State, Ref, ClientPID),
	    loop(NewState);
	{TEST_PID, get_state} ->
	    TEST_PID!{get_state, State},
	    loop(State)
    end.

%% executes join protocol from server perspective
do_join(ChatName, ClientPID, Ref, State) ->
    case maps:is_key(ChatName, State#serv_st.chatrooms) of 
		false -> 
			S = spawn(chatroom,start_chatroom,[ChatName]),
			NewState = State#serv_st{registrations = maps:put(ChatName, [], State#serv_st.registrations), chatrooms = maps:put(ChatName, S, State#serv_st.chatrooms)},
			do_join(ChatName, ClientPID, Ref, NewState);
		true -> 
			ClientNick = maps:get(ClientPID,State#serv_st.nicks),
			maps:get(ChatName, State#serv_st.chatrooms)!{self(), Ref, register, ClientPID, ClientNick},
			NewList = [ClientPID]++maps:get(ChatName,State#serv_st.registrations),
			NewState = State#serv_st{registrations = maps:put(ChatName, NewList, State#serv_st.registrations)},
			NewState
	end.

%% executes leave protocol from server perspective
do_leave(ChatName, ClientPID, Ref, State) ->
    ChatroomPID = maps:get(ChatName, State#serv_st.chatrooms),
	NewList = lists:delete(ClientPID, maps:get(ChatName,State#serv_st.registrations)),
	NewState = State#serv_st{registrations = maps:update(ChatName, NewList, State#serv_st.registrations)},
	ChatroomPID!{self(), Ref, unregister, ClientPID},
	ClientPID!{self(), Ref, ack_leave},
	NewState
.

%% executes new nickname protocol from server perspective
do_new_nick(State, Ref, ClientPID, NewNick) ->
    NickValues = maps:values(State#serv_st.nicks),
	case lists:member(NewNick, NickValues) of
		true -> ClientPID!{self(), Ref, err_nick_used},
				State;
		false -> 
			NewState = State#serv_st{nicks = maps:update(ClientPID, NewNick, State#serv_st.nicks)},
			Pred = fun(_K,V) -> lists:member(ClientPID, V) end,
			ChatNameList = maps:keys(maps:filter(Pred, State#serv_st.registrations)),
			Pred2 = fun(Elem) -> maps:get(Elem, State#serv_st.chatrooms) end,
			ChatPidsList = lists:map(Pred2, ChatNameList),
			[Pids ! {self(), Ref, update_nick,ClientPID, NewNick} || Pids <- ChatPidsList],
			ClientPID!{self(), Ref, ok_nick},
			NewState
	end
.

%% executes client quit protocol from server perspective
do_client_quit(State, Ref, ClientPID) ->
    NewState = State#serv_st{nicks = maps:remove(ClientPID, State#serv_st.nicks)},
	Pred = fun(_K,V) -> lists:member(ClientPID, V) end,
	ChatNameList = maps:keys(maps:filter(Pred, State#serv_st.registrations)),
	Pred2 = fun(Elem) -> maps:get(Elem, State#serv_st.chatrooms) end,
	ChatPidsList = lists:map(Pred2, ChatNameList),
	[Pid!{self(), Ref, unregister, ClientPID} || Pid <- ChatPidsList],
	Do_pid_delete_help = fun(_K,V) -> lists:delete(ClientPID, V) end,
	NewState2 = NewState#serv_st{registrations = maps:map(Do_pid_delete_help, NewState#serv_st.registrations)},
	ClientPID!{self(), Ref, ack_quit},
	NewState2
.
