defmodule TestserverWeb.Worker do
    use GenServer
    
        def start_link() do
            #Agent.start_link(fn -> initial_state end, name: __MODULE__)
            GenServer.start_link( __MODULE__, {}, name: String.to_atom("mainserver"))
        end

        def init(args) do
           # arguments = parse_args(args)
           IO.puts "hello started genserver"
            {:ok, %{"users" => %{}, "hashtags" => %{}, "mentions" => %{}}}
        end
    
        
        def initialize_new_user(username, passwd) do
            %{"username" => username, "password" => passwd, "tweets" => [], "followers"=>[],"followings"=>[] }
        end
    
        def register_user(users,username, passwd) do
            new_user_state = initialize_new_user(username, passwd)
            users = Map.put(users,username,new_user_state)
            users
        end
        
        def add_tweet(user,tweet) do
            tweets = Map.get(user,"tweets")
            tweets = [ tweet | tweets]
            user = Map.put(user,"tweets",tweets)
            user
        end
    
        def get_user_tweets(username,users) do
            
            tweets = []
            if(is_user_online(username) == true) do
                IO.puts "getting tweets for ::" <> username
               {:tweets,tweets} = GenServer.call(String.to_atom(username), {:get_tweets,{:print_message,"Keyur"}}) 
            else 
                tweets = Map.get(Map.get(users, username),"tweets")
            end
            IO.inspect tweets
            tweets
        end
    
        def merge_tweets(followings,tweets,idx,users) do
    
            if(length(followings) == 0) do
                tweets
            else
               
                [user | followings] = followings
                user_tweets = get_user_tweets(user,users) 
                merge_tweets(followings, Enum.concat(tweets,user_tweets), idx+1, users)
    
            end       
        end
    
        def build_dashboard(user,users) do
            followings = Map.get(user,"followings")   
            self_tweets = Map.get(user,"tweets")           
            dashboard = merge_tweets(followings,self_tweets,0,users)
            dashboard = Enum.sort(dashboard,&(elem(&1,2) > elem(&2,2)))
            dashboard
        end
    
    
        def upsert_user_following(userState, username, following) do
            followings = Map.get(userState,"followings")
            if userState != nil do            
                followings = [following | followings]
                userState = Map.put(userState, "followings", followings)
            end
            userState
        end
    
        def is_user_online(username) do
            is_online = false
           # IO.puts username
            pid = Process.whereis(String.to_atom(username))   
           # IO.inspect username <> " is  :: "
           # IO.inspect pid   
            if(pid != nil && Process.alive?(pid) == true) do
                is_online = true
            end
            is_online
        end
    
       
        # handle call_backs
    
        #register user
        def handle_call({:register_user ,new_user_info},_from,state) do  
            
            #new_user_info -> {username,password}
    
            username = elem(new_user_info, 0)
            password = elem(new_user_info,1)
            retValue = false
            if(state["users"][username] == nil) do
                #add user
                retValue =  true
                users = register_user(Map.get(state,"users"),username,password)
                state = Map.put(state,"users",users)            
            end
            {:reply,retValue,state}
        end
    
        #dump user state on server
        def handle_call({:update_user_state ,user},_from,state) do       
            users = Map.get(state, "users")
            users = Map.put(users,Map.get(elem(user,1),"username"),elem(user,1))
            state = Map.put(state,"users",users)
            
            {:reply,state,state}
        end
    
        #get user state
        def handle_call({:get_user_state ,username},_from,state) do  
            users = Map.get(state, "users")
            user = Map.get(users,username)       
            {:reply,user,state}
        end
    
        #add tweet to user list
        #0 -> text, 1-> id, 2 -> timestamp, 3 -> username
        def handle_call({:post_tweet , new_tweet}, _from, state) do  
            username = elem(new_tweet,0)
            tweet_text = elem(new_tweet,1)
            #tweet_data -> {}
            #username = elem(tweet, 3)
            #users = Map.get(state, "users")
            #user = Map.get(users, username)
            #user = add_tweet(user,tweet)
            #users = Map.put(users,username, user)       
            #state = Map.put(state,"users", users)
            is_online = is_user_online(username)
            tweet = {}
            if(is_online == true) do
                {:tweet,tweet} = GenServer.call(String.to_atom(username),{:add_tweet,{tweet_text}})
    
            end
    
            {:reply,tweet,state}
        end
        
    
        #user_info - > 0 : username, 1: pwd
        def handle_call({:login,user_info}, _from, state) do
            username = elem(user_info,0)
            password = elem(user_info,1)
            retVal = false
            user = Map.get(Map.get(state,"users"),username)
            IO.inspect user
            #authenticate user
            if(user != nil && Map.get(user,"password") == password) do
                retVal = true
                IO.inspect "here"
                dashboard = build_dashboard(user, Map.get(state,"users"))
                user = Map.put(user,"dashboard",dashboard)            
                #GenServer.start_link(Client, user, name: String.to_atom(username))
            else
                retVal = false
            end 
    
            {:reply,user,state}
        end
    
        def handle_call({:logout,username},_from, state) do
            username = elem(username,0)
            if(is_user_online(username) == true) do
                userState = GenServer.call(String.to_atom(username),{:get_user_state, username})
                users = Map.get(state,"users")
                users = Map.put(users, username, userState)
                state = Map.put(state, "users", users)
                #retVal = GenServer.call(String.to_atom(username),{:go_offline, {:print_message,"Keyur"}}) 
                
                pid = Process.whereis(String.to_atom(username)) 
                GenServer.stop(pid, :normal)
    
                pid = Process.whereis(String.to_atom(username)) 
                IO.puts "PID"
                IO.inspect  pid
            end
            {:reply,true,state}
        end
    
        def handle_call({:add_to_following_dead ,new_message},_from,state) do
            username = elem(new_message,0)
            follower = elem(new_message,1)
        
            userState = Map.get(Map.get(state,"users"),username)
            userState = upsert_user_following(userState, username, follower)
            users = Map.get(state,"users")
            users = Map.put(users,username,userState)
            state = Map.put(state, "users", users)
            {:reply,state,state}
        end
    
        def handle_call({:add_hashtag , hash_info}, _from, state) do
            IO.puts("add tagsss")
            hashtag = elem(hash_info,0)
            tweet = elem(hash_info,1)
            #{hashtag, tweet}
            #IO.puts "adddd   hash tags " <> hashtag 
            hashtag_map = Map.get(state,"hashtags")
            if(Map.get(hashtag_map,hashtag) == nil) do
                hashtag_map = Map.put(hashtag_map,hashtag,[])
            end
            tweets = Map.get(hashtag_map,hashtag)
            tweets = [tweet| tweets]
            hashtag_map = Map.put(hashtag_map,hashtag,tweets)
            state = Map.put(state,"hashtags", hashtag_map)
            IO.inspect state
            {:reply,state,state}
        end
    
        def handle_call({:add_mentions , mentions_info}, _from, state) do
            mentions = elem(mentions_info, 0)
            tweet = elem(mentions_info, 1)
            mentions_map = Map.get(state,"mentions")
            users = Map.get(state,"users")
            if(Map.get(users,mentions) != nil) do
                if(Map.get(mentions_map,mentions) == nil) do
                    mentions_map = Map.put(mentions_map,mentions,[])
                end
    
                tweets = Map.get(mentions_map,mentions)
                tweets = [tweet| tweets]
                mentions_map = Map.put(mentions_map,mentions,tweets)
                state = Map.put(state,"mentions", mentions_map)
            end
            IO.inspect state
            {:reply,state,state}
        end
    
        def handle_call({:get_hash_list , hashtag}, _from, state) do
            hashtag = elem(hashtag, 0)
    
            hashtags = Map.get(state,"hashtags")
            
            tweets = Map.get(hashtags,hashtag)
            #IO.puts"------------------------herereererer------------"
            if(tweets == nil) do
                tweets = []
            end
            #IO.inspect tweets
            {:reply,tweets,state}
        end
    
        def handle_call({:get_mentions_list , username}, _from, state) do
            username = elem(username, 0)
    
            mentions = Map.get(state,"mentions")
            tweets = Map.get(mentions, username)
            if(tweets == nil) do
                tweets = []
            end
            {:reply,tweets,state}
        end    
    
        def handle_call({:get_state ,new_message},_from,state) do  
            {:reply, state, state}
        end    
end