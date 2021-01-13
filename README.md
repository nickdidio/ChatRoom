# ChatRoom
Chatroom program with chatroom, client, server, and GUI architecture that allows for multiple users to join, send messages, leave, change nickname and leave a chatroom.
Chatrooms are created automatically once a user joins one that does not already exist.
The program was created using erlang and must be run using a linux operating system.

Available commands:

To start server and make number of clients/GUIs- in erlang shell: main:start([number of GUIs])
To add an additional client/GUIs- in erlang shell gui:start_gui()
To join/create chatroom: /join #[name of chatroom]
To send message: [message]
To leave chatroom: /leave #[name of chatroom]
To exit GUI and quit client: /quit    (Note: Quit command has a known bug that GUI does not close, but all server and chatroom connections are closed.)
To exit server- in erlang shell: /q
