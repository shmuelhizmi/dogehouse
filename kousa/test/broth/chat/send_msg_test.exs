defmodule BrothTest.Chat.SendMsgTest do
  use ExUnit.Case, async: true
  use KousaTest.Support.EctoSandbox

  alias Beef.Schemas.User
  alias Beef.Users
  alias BrothTest.WsClient
  alias BrothTest.WsClientFactory
  alias KousaTest.Support.Factory

  require WsClient

  setup do
    user = Factory.create(User)
    client_ws = WsClientFactory.create_client_for(user)

    # first, create a room owned by the primary user.
    %{"id" => room_id} =
      WsClient.do_call(
        client_ws,
        "room:create",
        %{"name" => "foo room", "description" => "foo"})

    {:ok, user: user, client_ws: client_ws, room_id: room_id}
  end

  describe "the websocket chat:send_msg operation" do
    @text_token [%{"t" => "text", "v" => "foobar"}]

    test "sends a message to the room", t do
      user_id = t.user.id
      room_id = t.room_id

      # create a user that is logged in.
      listener = %{id: listener_id} = Factory.create(User)
      listener_ws = WsClientFactory.create_client_for(listener)

      WsClient.do_call(listener_ws, "room:join", %{"roomId" => room_id})
      WsClient.assert_frame_legacy("new_user_join_room", _)

      WsClient.send_msg(t.client_ws, "chat:send_msg", %{"tokens" => @text_token})

      WsClient.assert_frame(
        "chat:send",
        %{"tokens" => @text_token},
        t.client_ws
      )

      WsClient.assert_frame(
        "chat:send",
        %{"tokens" => @text_token},
        listener_ws
      )
    end

    test "can be used to send a whispered message", t do
      user_id = t.user.id
      room_id = t.room_id

      # create a user that won't be able to hear
      cant_hear = Factory.create(User)
      cant_hear_ws = WsClientFactory.create_client_for(cant_hear)

      # create a user that will be able to hear.
      can_hear = Factory.create(User)
      can_hear_ws = WsClientFactory.create_client_for(can_hear)

      # join the two users into the room
      WsClient.do_call(cant_hear_ws, "room:join", %{"roomId" => room_id})
      WsClient.do_call(can_hear_ws, "room:join", %{"roomId" => room_id})

      WsClient.assert_frame_legacy("new_user_join_room", _, t.client_ws)
      WsClient.assert_frame_legacy("new_user_join_room", _, t.client_ws)
      WsClient.assert_frame_legacy("new_user_join_room", _, cant_hear_ws)

      WsClient.send_msg(t.client_ws, "chat:send_msg", %{
        "tokens" => @text_token,
        "whisperedTo" => [can_hear.id]
      })

      WsClient.assert_frame(
        "chat:send",
        %{"tokens" => @text_token, "from" => ^user_id},
        t.client_ws
      )

      WsClient.assert_frame(
        "chat:send",
        %{"tokens" => @text_token, "from" => ^user_id},
        can_hear_ws
      )

      WsClient.refute_frame("chat:send", cant_hear_ws)
    end
  end
end
