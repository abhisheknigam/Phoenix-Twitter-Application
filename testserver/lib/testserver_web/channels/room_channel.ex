defmodule  TestserverWeb.RoomChannel do
  use Phoenix.Channel
  require Logger

  @doc """
  Authorize socket to subscribe and broadcast events on this channel & topic

  Possible Return Values

  `{:ok, socket}` to authorize subscription for channel for requested topic

  `:ignore` to deny subscription/broadcast on this channel
  for the requested topic
  """
  def join("rooms:lobby", message, socket) do
    Process.flag(:trap_exit, true)
    :timer.send_interval(5000, :ping)
    send(self, {:after_join, message})
    {:ok, socket}
  end



  def join("rooms:" <> _private_subtopic, _message, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_info({:after_join, msg}, socket) do
    broadcast! socket, "user:entered", %{user: msg["user"]}
    push socket, "join", %{status: "connected"}
    {:noreply, socket}
  end

  def handle_info(:ping, socket) do
    push socket, "new:msg", %{user: "SYSTEM", body: "ping"}
    {:noreply, socket}
  end

  def terminate(reason, _socket) do
    Logger.debug"> leave #{inspect reason}"
    :ok
  end

  def handle_in("new:msg", msg, socket) do
    broadcast! socket, "new:msg", %{user: msg["user"], body: "behencho"}
    {:reply, {:ok, %{msg: "behencho"}}, assign(socket, :user, msg["user"])}
  end


  def handle_in("new:registerUser", userInfo, socket) do
    username = Map.get(userInfo, "username")
    password = Map.get(userInfo, "password")
    retVal = GenServer.call(String.to_atom("mainserver"), {:register_user, {username, password}})
    #broadcast! socket, "new:update_dashboard", %{userInfo: userInfo}
    {:reply, {:ok, %{msg: userInfo}}, socket}
  end

  def handle_in("new:getState", msg, socket) do
    map = GenServer.call(String.to_atom("mainserver"), {:get_state, ""})
    IO.inspect map
    {:reply, {:ok, %{msg: map}}, assign(socket, :user, msg["username"])}
  end

  def handle_in("new:get_user_state", msg, socket) do
    map = GenServer.call(String.to_atom("mainserver"), {:get_user_state, msg["username"]})
    map = convertStateToMap(map)
    {:reply, {:ok, %{msg: map}}, assign(socket, :user, msg["username"])}
  end

  def handle_in("new:update_user_state", msg, socket) do
    map = convertStateToMap(msg["userState"])
    map = GenServer.call(String.to_atom("mainserver"), {:update_user_state, {msg["username"], map}})
    {:reply, {:ok, %{msg: map}}, assign(socket, :user, msg["username"])}
  end

  def convertStateToMap(map) do
    dashboard = Map.get(map, "dashboard")
    tweets = Map.get(map, "tweets")
    
    dash = []
    if(dashboard != nil) do
      Enum.each(dashboard, fn(x) -> dash = [deflate_tweet_to_map(x) | dash] end)
      IO.inspect dash
    end

    twees = []
    if(tweets != nil) do
      Enum.each(tweets, fn(x) -> twees = [deflate_tweet_to_map(x) | twees] end)
    end
    IO.inspect twees

    map = Map.put(map, "dashboard", dash)
    map = Map.put(map, "tweets", twees)
  end

  def convertStateMapToTuple(map) do
    dashboard = Map.get(map, "dashboard")
    tweets = Map.get(map, "tweets")
    
    dash = []
    if(dashboard != nil) do
      Enum.each(dashboard, fn(x) -> dash = [inflateTweet(x) | dash] end)
      IO.inspect dash
    end

    twees = []
    if(tweets != nil) do
      Enum.each(tweets, fn(x) -> twees = [inflateTweet(x) | twees] end)
    end
    IO.inspect twees

    map = Map.put(map, "dashboard", dash)
    map = Map.put(map, "tweets", twees)
  end

  def handle_in("new:login_user", userInfo, socket) do
    username = Map.get(userInfo, "username")
    password = Map.get(userInfo, "password")
    retVal = GenServer.call(String.to_atom("mainserver"), {:login, {username, password}})
    {:reply, {:ok, %{msg: retVal}}, socket}
  end

  def handle_in("new:add_hashtag", userInfo, socket) do
    hashtag = Map.get(userInfo, "hashtag")
    deflatedtweet = Map.get(userInfo, "tweet")
    tweet = inflateTweet(deflatedtweet)
    retVal = GenServer.call(String.to_atom("mainserver"), {:add_hashtag, {hashtag, tweet}})
    {:reply, {:ok, %{msg: userInfo}}, socket}
  end

  def handle_in("new:add_mentions", userInfo, socket) do
    username = Map.get(userInfo, "username")
    deflatedtweet = Map.get(userInfo, "tweet")
    tweet = inflateTweet(deflatedtweet)
    retVal = GenServer.call(String.to_atom("mainserver"), {:add_mentions, {username, tweet}})
    {:reply, {:ok, %{msg: userInfo}}, socket}
  end

  def handle_in("new:add_following", userInfo, socket) do
    IO.inspect "just invoked following"
    IO.inspect userInfo
    username = Map.get(userInfo, "username")
    following = Map.get(userInfo, "following")
    IO.inspect "Add_following Invoked"
    broadcast! socket, "new:add_following", %{"username"=> username, "following"=>following}
    {:reply, {:ok, %{msg: userInfo}}, socket}
  end

  def handle_in("new:add_tweet_and_update_dashboard", tweetMap, socket) do
    IO.inspect "printing tweet"
    IO.inspect tweetMap
    deflatedtweet = Map.get(tweetMap, "tweet")
    tweet = inflateTweet(deflatedtweet)
    IO.inspect "printing tweet"
    IO.inspect tweet
    broadcast! socket, "new:update_dashboard", %{"tweet"=> tweet}
    {:reply, {:ok, %{msg: tweetMap}}, socket}
  end
  
  intercept ["new:update_dashboard", "new:add_following"]
  def handle_out("new:update_dashboard", tweet, socket) do
    IO.inspect "inside update dahboard"
    deflatedTweet = deflate_tweet_to_map(tweet["tweet"])
    push socket, "update_dashboard", %{tweet: deflatedTweet}
    {:noreply, socket}
  end

  def handle_out("new:add_following", followerInfo, socket) do
    IO.inspect "inside update following"
    IO.inspect followerInfo
    push socket, "add_following", followerInfo
    {:noreply, socket}
  end

  def inflateTweet(tweetMap) do
    tweetText = Map.get(tweetMap, "tweetText")
    index = Map.get(tweetMap, "index")
    username= Map.get(tweetMap, "username")
    year = Map.get(tweetMap, "year")
    month = Map.get(tweetMap, "month")
    day = Map.get(tweetMap, "day")
    hour = Map.get(tweetMap, "hour")
    min = Map.get(tweetMap, "min")
    sec = Map.get(tweetMap, "sec")

    date = {year, month, day}
    time = {hour,min,sec}

    dateTime = {date,time}
    inflatedTweet = {tweetText, index, dateTime, username}
    inflatedTweet
  end 

  def deflate_tweet_to_map(tweet) do
    IO.inspect "deflating tweet"
    IO.inspect tweet

    tweetText = elem(tweet,0)
    index = elem(tweet,1)
    dateTime = elem(tweet,2)
    username = elem(tweet,3)

    date = elem(dateTime,0)
    time = elem(dateTime,1)

    year = elem(date,0)
    month = elem(date,1)
    day = elem(date,2)

    hour = elem(time,0)
    min = elem(time,0)
    sec = elem(time,0)

    tweetMap = %{}
    tweetMap= Map.put(tweetMap, "tweetText", tweetText)
    tweetMap= Map.put(tweetMap, "index", index)
    tweetMap=Map.put(tweetMap, "username", username)
    tweetMap=Map.put(tweetMap, "year", year)
    tweetMap=Map.put(tweetMap, "month", month)
    tweetMap=Map.put(tweetMap, "day", day)
    tweetMap=Map.put(tweetMap, "hour", hour)
    tweetMap=Map.put(tweetMap, "min", min)
    tweetMap=Map.put(tweetMap, "sec", sec)

    tweetMap
  end
  
end
##################################################################################
##################################################################################
##################################################################################
##################################################################################