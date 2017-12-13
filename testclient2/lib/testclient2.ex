defmodule Tweeter do

def init(state) do
  username = elem(state,0)
  password = elem(state,1)
  returnTuple = ping(username)
  state = %{}

  handlers = %{
    "update_dashboard" => "update_dashboard",
    "add_following" => "add_following"
  }

  state = Map.put(state,"handlers",handlers)
  state = Map.put(state, "channel", elem(returnTuple,0))
  state = Map.put(state, "username", username)
  state = Map.put(state, "password", password)
  registerUser(elem(returnTuple,0), username, password)
  {:ok,state}
end 

def main(args) do
  IO.puts "yooooooooo"
end

def ping(username) do

	{:ok, pid} = PhoenixChannelClient.start_link()
	{:ok, socket} = PhoenixChannelClient.connect(pid,
	  host: "localhost",
	  path: "/socket/websocket",
	  params: %{token: "something"},
	  port: 4000,	
	  secure: false)
	
	IO.inspect self()
	IO.inspect socket
	
  channel = PhoenixChannelClient.channel(socket, "rooms:lobby", %{name: username})
  #ChannelClient.start_link(channel, handlers: handlers)
  joinChannel(channel)
{channel}
end

def joinChannel(channel) do
  case PhoenixChannelClient.join(channel) do
    {:ok, _} -> IO.puts "ok"
    {:ok, %{message: message}} -> IO.puts(message)
    {:error, %{reason: reason}} -> IO.puts(reason)
    :timeout -> IO.puts("timeout")
  end
end

def registerUser(channel, username, password) do
  case PhoenixChannelClient.push_and_receive(channel, "new:registerUser", %{username: username, password: password}, 100) do
    {:ok, msg} -> IO.inspect msg
    {:error, %{reason: reason}} -> IO.puts(reason)
    :timeout -> IO.puts("timeout")
  end

  # receive do
  #   {"new_msg", msg} -> IO.puts(msg)
  #   :close -> IO.puts("closed")
  #   {:error, error} -> ()
  # end

end

def getState(channel, username) do
  case PhoenixChannelClient.push_and_receive(channel, "new:get_user_state", %{username: username}, 100) do
    {:ok, msg} -> msg
    {:error, %{reason: reason}} -> IO.puts(reason)
    :timeout -> IO.puts("timeout")
  end
end

def add_tweet(channel, username, tweet) do
  {:tweet,tweet} = GenServer.call(String.to_atom(username),{:add_tweet,{tweet}})
  IO.inspect "tweet"
  IO.inspect tweet
  deflatedTweet = deflate_tweet_to_map(tweet)
  IO.inspect "deflatedTweet"
  IO.inspect deflatedTweet
  case PhoenixChannelClient.push_and_receive(channel, "new:add_tweet_and_update_dashboard", %{tweet: deflatedTweet}, 100) do
    {:ok, msg} -> IO.inspect msg
    {:error, %{reason: reason}} -> IO.puts(reason)
    :timeout -> IO.puts("timeout")
  end
end
  

  def login(channel, username, password) do
    userState = PhoenixChannelClient.push_and_receive(channel, "new:login_user", %{username: username, password: password}, 100)
    case userState do
      #{:ok, msg} -> IO.inspect msg
      {:ok, msg} -> msg
      {:error, %{reason: reason}} -> IO.puts(reason)
      :timeout -> IO.puts("timeout")
    end
    
    {:ok, msg} = userState
    IO.inspect "login user state"
    IO.inspect msg["msg"]
    # receive do
    #   {"new_msg", message} -> IO.puts(message)
    #   :close -> IO.puts("closed")
    #   {:error, error} -> ()
    # end
    #userState = message
   GenServer.start_link(Client, msg["msg"], name: String.to_atom(username))
  end

  def get_client_state(username) do
    userState = GenServer.call(String.to_atom(username),{:get_user_state,{}})
  end

  def handle_call({:getState ,new_message}, _from, state) do
    curr_state = getState(Map.get(state,"channel"), elem(new_message,0))
    IO.inspect curr_state
    {:reply,curr_state, state}
  end

  def handle_call({:login ,new_message}, _from, state) do
    curr_state = login(Map.get(state,"channel"), elem(new_message,0), elem(new_message,1))
    #IO.inspect "Current state"
    #IO.inspect curr_state
    {:reply,curr_state, state}
  end

  def handle_call({:add_tweet ,new_message}, _from, state) do
    curr_state = add_tweet(Map.get(state,"channel"),elem(new_message,0),elem(new_message,1))
    {:reply,{:tweet, elem(new_message,1)}, state}
  end
    
  def handle_call({:go_offline ,new_message}, _from, state) do
    username = elem(new_message,0)
    userState = get_client_state(username)
    userState = convertStateToMap(userState)
    case PhoenixChannelClient.push_and_receive(Map.get(state,"channel"), "new:update_user_state", %{username: username, userState: userState}, 100) do
      {:ok, msg} -> msg
      {:error, %{reason: reason}} -> IO.puts(reason)
      :timeout -> IO.puts("timeout")
    end
    
    GenServer.call(String.to_atom(username),{:go_offline,new_message})
    {:reply,{:tweet, elem(new_message,1)}, state}
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

  def handle_info({event, payload}, state) do
    IO.inspect "Inside handle info"
    handlers = Map.get(state, "handlers")
    curr_event = Map.get(handlers, event)
    #IO.inspect state

    case curr_event do
      "update_dashboard" -> update_dashboard(payload, state)
      "add_following" -> add_following(payload,state)
       _ -> :ok
    end
    {:noreply, state}
  end

  def update_dashboard(tweetMap, state) do
    curr_user = Map.get(state,"username")
    tweetMap = Map.get(tweetMap, "tweet")
    username = Map.get(tweetMap, "username")

    IO.inspect "Updating state of dashboard of the following for user " <> username
    userState = get_client_state(curr_user);
    #IO.inspect userState
    IO.inspect "After printing state"

    followings = Map.get(userState,"followings")
    
    if followings != nil && Enum.member?(followings, username) do
      tweet = inflateTweet(tweetMap)
      IO.inspect "Inside sending call to the add dashboard from simulator"
      GenServer.call(String.to_atom(curr_user),{:add_to_dashboard,{tweet}})
    end
    IO.inspect get_client_state("abhishek")
    IO.inspect get_client_state("keyur")
  end

  def handle_call({:add_follower ,new_message}, _from, state) do
    username = elem(new_message,0)
    follower = elem(new_message,1)

    IO.inspect "Inside Add Follower"
    userState = get_client_state(username);

    GenServer.call(String.to_atom(username),{:add_to_follower,{follower}})
    case PhoenixChannelClient.push_and_receive(Map.get(state,"channel"), "new:add_following", %{username: username, following: follower}, 100) do
      {:ok, msg} -> msg
      {:error, %{reason: reason}} -> IO.puts(reason)
      :timeout -> IO.puts("timeout")
    end
    {:reply,{username}, state}
  end

  def add_following(followerInfo, state) do
    IO.inspect "add_following called from server"
    IO.inspect "payload"
    IO.inspect followerInfo
    curr_user = Map.get(state, "username")
    username = Map.get(followerInfo, "following")
    if curr_user == username do
      follower = Map.get(followerInfo, "username")
      GenServer.call(String.to_atom(username),{:add_to_following_alive,{follower}})
    end
  end
  
  def handle_cast({:add_hashtag ,new_message}, state) do
    hashtag = elem(new_message,0)
    tweet = elem(new_message,1)

    deflatedTweet = deflate_tweet_to_map(tweet)

    case PhoenixChannelClient.push_and_receive(Map.get(state,"channel"), "new:add_hashtag", %{hashtag: hashtag, tweet: deflatedTweet}, 100) do
      {:ok, msg} -> IO.inspect msg
      {:error, %{reason: reason}} -> IO.puts(reason)
      :timeout -> IO.puts("timeout")
    end
    #curr_state = getState(Map.get(state,"channel"), Map.get(state,"username"))
    #IO.inspect curr_state
    {:noreply, state}
  end

  def handle_cast({:add_mentions ,new_message}, state) do
    username = elem(new_message,0)
    tweet = elem(new_message,1)

    deflatedTweet = deflate_tweet_to_map(tweet)

    case PhoenixChannelClient.push_and_receive(Map.get(state,"channel"), "new:add_mentions", %{username: username, tweet: deflatedTweet}, 100) do
      {:ok, msg} -> msg
      {:error, %{reason: reason}} -> IO.puts(reason)
      :timeout -> IO.puts("timeout")
    end
    {:noreply, state}
  end

#{{2017, 12, 12}, {17, 51, 35}}
  def deflate_tweet_to_map(tweet) do
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

end


