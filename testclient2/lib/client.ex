defmodule Client do
    use GenServer

    def init(state) do
        {:ok,state}
    end 

    def add_to_follower_dashboards(finalTweet, followings) do
        if length(followings) > 0 do
            [following | followings] = followings
            #IO.inspect "Dashboard followers" <> following
            GenServer.call(String.to_atom(following), {:add_to_dashboard, {finalTweet}})
            add_to_follower_dashboards(finalTweet, followings) 
        end
    end

    def upsert_user_tweet(userState, tweet) do
        username = Map.get(userState, "username")   
        if userState != nil do
            tweets = Map.get(userState, "tweets")
            if tweets != nil && length(tweets) > 0 do
                [lastTweet|allOthers] = tweets
                lastTweetId = elem(lastTweet,1)
                IO.inspect lastTweetId
                finalTweet = {tweet, lastTweetId+1, :calendar.universal_time(), username}
                tweets = [finalTweet | tweets]
            else
                finalTweet = {tweet,0,:calendar.universal_time(), username}
                tweets = [finalTweet]
            end

            #Parse Tweet for Hashtag and Mentions
            parse_tweet(username, finalTweet)
            userState = upsert_user_dashboard(userState, finalTweet)
            
            #Send Tweet to follower dashboard
            #followings = Map.get(userState, "followings")
            #add_to_follower_dashboards(finalTweet, followings)
            
            #Add tweet to user state
            userState = Map.put(userState, "tweets", tweets)
        end
        {finalTweet, userState}
    end

    def upsert_retweet(userState, fullTweet) do
        username = Map.get(userState, "username")
        tweets = Map.get(userState, "tweets")
        tweet = elem(fullTweet,0)

        if tweets != nil && length(tweets) > 0 do
            [lastTweet|allOthers] = tweets
            lastTweetId = elem(lastTweet,1)
            IO.inspect lastTweetId
            
            finalTweet = {tweet, lastTweetId+1, :calendar.universal_time(), username, fullTweet}
            tweets = [finalTweet | tweets]
        else
            finalTweet = {tweet,0,:calendar.universal_time(), username, fullTweet}
            tweets = [finalTweet]
        end

        #Parse Tweet for Hashtag and Mentions
        parse_tweet(finalTweet, username)
        
        #Send Tweet to follower dashboard
        followings = Map.get(userState, "followings")
        add_to_follower_dashboards(finalTweet, followings)
        
        #Add tweet to user state
        userState = Map.put(userState, "tweets", tweets)
        
        {finalTweet, userState}
    end

    def upsert_user_follower(userState, follower) do
        if userState != nil do
            followers = Map.get(userState, "followers")
            followers = [follower | followers]
            userState = Map.put(userState, "followers", followers)
        end
        IO.inspect "Upsert user follower"
        IO.inspect userState
        {follower, userState}
    end

    def upsert_user_following(userState, following) do
        if userState != nil do
            followings = Map.get(userState, "followings")
            followings = [following | followings]
            IO.inspect followings
            userState = Map.put(userState, "followings", followings)
        end
        {following, userState}
    end

    def upsert_user_dashboard(userState, tweet) do
        dashboard = Map.get(userState, "dashboard")
        dashboard = [tweet|dashboard]
        userState = Map.put(userState, "dashboard", dashboard)
    end

    def process_hashtags(word, tweet, username) do
        if String.first(word)=="#" do           
            hashtag =  String.slice(word,1,String.length(word))
            GenServer.cast(String.to_atom(username<>"_2"), {:add_hashtag, {hashtag,tweet}})
        end 
    end

    def process_mentions(word, tweet, username) do
        if String.first(word) == "@" do
            username =  String.slice(word,1,String.length(word))
            GenServer.cast(String.to_atom(username<>"_2"), {:add_mentions, {username,tweet}})
        end
    end

    def parse_tweet(username, finalTweet) do
        tweet = elem(finalTweet, 0)
        split_tweet = String.split(tweet);
        Enum.each(split_tweet, fn(word) -> 
            process_hashtags(word, finalTweet, username)
            process_mentions(word, finalTweet, username)
        end
        )
    end

    def handle_call({:add_to_dashboard ,new_message}, _from, userState) do
        userState = upsert_user_dashboard(userState, elem(new_message,0))
        {:reply, {:ok}, userState}
    end

    def handle_call({:go_offline ,new_message},_from, userState) do
        username = Map.get(userState,"username");
        IO.inspect "-------------------------------------------------------------------------"
        userState = GenServer.call(String.to_atom("mainserver"), {:update_user_state, {username,userState}})
        {:reply, true, userState}
    end

    def handle_call({:add_tweet ,new_message}, _from, userState) do
        tweet = elem(new_message,0)
        {tweet, userState} = upsert_user_tweet(userState, tweet)
        {:reply,{:tweet,tweet}, userState}
    end

    def handle_call({:add_to_following_alive ,new_message}, _from, userState) do
        following = elem(new_message,0)
        IO.inspect "Following" <> following
        {following, userState} = upsert_user_following(userState, following)
        {:reply,following,userState}
    end

    def handle_call({:add_to_follower ,new_message}, _from, userState) do
        follower = elem(new_message,0)
        {follower, userState} = upsert_user_follower(userState, follower)
        {:reply,follower,userState}
    end

    def handle_call({:get_tweets ,new_message}, _from, userState) do
        if userState != nil do
            tweets = Map.get(userState, "tweets")
        end
        {:reply,{:tweets,tweets}, userState}
    end

    def handle_call({:retweet ,new_message}, _from, userState) do
        userOfTweet = elem(new_message,0)
        tweetId = elem(new_message,1)
        fullTweet = GenServer.call(String.to_atom(userOfTweet), {:get_tweet_by_tweetId, {tweetId}})
        {tweet, userState} = upsert_retweet(userState, fullTweet)
        {:reply,{:tweet,tweet}, userState}
    end

    def handle_call({:get_tweet_by_tweetId ,new_message}, _from, userState) do
        tweetId = elem(new_message, 0)
        tweets = Map.get(userState, "tweets");
        if length(tweets) >= tweetId do
            tweet = Enum.at(tweets, tweetId)
        else
            tweet = Enum.at(tweets, 0)
        end
        {:reply, tweet, userState}
    end

    def handle_call({:add_follower ,new_message}, _from, userState) do
        username = Map.get(userState,"username")
        follower = elem(new_message,0)

        pid = Process.whereis(String.to_atom(follower))

        if(pid != nil && Process.alive?(pid) == true) do   
            GenServer.call(String.to_atom(follower), {:add_to_following_alive, {username}}) 
        else
            GenServer.call(String.to_atom("mainserver"), {:add_to_following_dead, {username, follower}}) 
        end
        {follower, userState} = upsert_user_follower(userState, follower)
        
        {:reply, userState, userState}
    end

    def handle_call({:get_user_state ,new_message}, _from, userState) do
        {:reply, userState, userState}
    end

    def terminate(reason, state) do
        #IO.puts "Going Down: #{inspect(state)}"
        :normal
      end

end

#{:news,size} = GenServer.call({:bit_coin,String.to_atom(server_name)},{:print_message,"Keyur"}, :infinity)    