defmodule Testclient2 do
    use GenServer

    def main(args) do
     
        #start_server
        #run_tests
        #post_tweet("abhishek","#This is from abhi")
        register_user("abhishek","password")
        register_user("keyur","password")
        login_user("abhishek","password")
        login_user("keyur","password")

        add_follower("abhishek","keyur")
        add_follower("keyur","abhishek")
        post_tweet("keyur","helooo")
        post_tweet("abhishek","Palak")
        post_tweet("abhishek","#This is from abhi")
        post_tweet("abhishek","@keyur is in love")

        get_server_state("abhishek")
        IO.gets ""
    end

    def start_server do
        GenServer.start_link(Server, {}, name: String.to_atom("mainserver"))
    end

    def run_tests do
        
        register_user("keyur","baldha")
        register_user("abhi","shek")
        register_user("apurv","apurv")
        register_user("Karan","Karan")

        login_user("keyur","baldha")
        :timer.sleep(2500)
        login_user("keyur","baldha")
        
        :timer.sleep(11500)
        login_user("abhi","shek")
        login_user("apurv","apurv")
        login_user("Karan","Karan")


        add_follower("abhi","keyur")
        add_follower("apurv","keyur")
        add_follower("Karan","keyur")
        login_user("Karan","Karan")
        add_follower("Karan","abhi")
        add_follower("keyur","abhi")

        post_tweet("keyur","helooo")
        post_tweet("keyur","jijijiij")

        post_tweet("apurv","I am IBM #Watson @keyu")
        post_tweet("Karan","I am Anita's Lover")
        post_tweet("abhi","#This is from abhi")
        
        
        IO.inspect get_hashtag_tweets("This")

        post_retweet("abhi", "apurv", 0)


        IO.inspect get_user_state("Karan")
        IO.inspect get_user_state("abhi")
        #IO.inspect get_user_state("apurv")
        #IO.inspect get_user_state("Karan")


        logout_user("keyur")
        logout_user("abhi")

        #:timer.sleep(2000)

        login_user("keyur","baldha")

        userlist = create_users(50, [])
        register_and_login(userlist)
        post_random_tweets(userlist,100)
        map_set = MapSet.new
        map_set = add_random_followers(userlist, 50, map_set)
        logout_all_users(userlist)


        IO.puts "------------------server state---------------------"
        #IO.inspect get_server_state

        IO.puts "------------------user state---------------------"
        IO.inspect get_user_state("keyur")
        
        IO.gets ""
    end


    def logout_all_users(userlist) do
        Enum.each(userlist, 
            fn(user) -> 
                logout_user(elem(user,0))   
            end
        )
    end

    def post_random_tweets(userlist,count) do
        userCount = length(userlist)        
        if(count == 0) do

        else
            user = :rand.uniform(userCount)           
            username = elem(Enum.at(userlist,user-1),0)
            IO.puts "Tweet posted by " <> username
            shouldAddHashTag = :rand.uniform(2) - 1
            hashtagStr = "" 
            if(shouldAddHashTag == 0) do
                hashtagStr = "#" <> random_hashtag(5)
            end
            post_tweet(username,"test tweet::: " <> hashtagStr <> " " <> Integer.to_string(count))
            :timer.sleep(50) 
            post_random_tweets(userlist,count-1)
        end
    end

    def add_random_followers(userlist, count, map_set) do
        userCount = length(userlist)        
        if(count == 0) do

        else
            user = :rand.uniform(userCount)           
            username = elem(Enum.at(userlist,user-1),0)
            follower = :rand.uniform(userCount)
            followerName = elem(Enum.at(userlist,follower-1),0)

            IO.puts "Tweet posted by " <> username
            IO.puts "Tweet posted by" <> followerName

            IO.inspect username <> "-" <> followerName
            pairExists = MapSet.member?(map_set, username <> "-" <> followerName)
            
            if(pairExists != nil && username != followerName) do
                add_follower(username, followerName)
                map_set = MapSet.put(map_set, username <> "-" <> followerName)
            end 
            add_random_followers(userlist, count-1, map_set)
        end
        map_set
    end

    def register_and_login(userlist) do
        Enum.each(userlist, 
            fn(user) -> 
                register_user(elem(user,0), elem(user,1))   
                :timer.sleep(100)             
                login_user(elem(user,0), elem(user,1))
            end
        )
    end

    def create_users(number,userlist) do
        if(number == 0) do
            userlist
        else
            user = {"user_" <> Integer.to_string(number),"pwd"}
            userlist = [user | userlist]
            create_users(number-1,userlist)
        end
    end
    
    def random_hashtag(length) do
        :crypto.strong_rand_bytes(length) |> Base.url_encode64 |> binary_part(0, length)
    end

    def post_tweet(username, tweet_text) do
        #tweet = GenServer.call(String.to_atom("mainserver"), {:post_tweet,{username,tweet_text}}) 
        {:tweet,tweet} = GenServer.call(String.to_atom(username<>"_2"),{:add_tweet,{username, tweet_text}})
        IO.inspect tweet
    end

    def post_retweet(username, tweet_username, tweet_id) do
        {:tweet,tweet} = GenServer.call(String.to_atom(username),{:retweet,{tweet_username,tweet_id}})
        IO.inspect tweet
          
    end

    def get_server_state(username) do
        state = GenServer.call(String.to_atom(username<>"_2"),{:getState,{username}})  
        IO.inspect "printing state in tweeter"
        IO.inspect state
    end

    def get_server_user_state(username) do
        user = GenServer.call(String.to_atom("mainserver"),{:get_user_state,username})         
        user
    end

    def get_user_state(username) do
        user = GenServer.call(String.to_atom(username),{:get_user_state,username})    
        user
    end
    
    def logout_user(username)  do
        
        GenServer.call(String.to_atom("mainserver"),{:logout,{username}}) 
        retVal = true
        IO.inspect "" <> username <>" logout successful"
    end

    def login_user(username,password)  do
        retVal = GenServer.call(String.to_atom(username<>"_2"), {:login,{username,password}}) 
        
        retVal = true
        if(retVal == true) do 
            IO.inspect "" <> username <>" login successful"
            #IO.inspect get_user_state(username)
        else
            IO.inspect "" <> username <>" login unsuccessful"
        end    
    end

    def register_user(username,password) do
        #retVal = GenServer.call(String.to_atom("mainserver"),{:register_user,{username,password}}) 
        GenServer.start_link(Tweeter, {username, password}, name: String.to_atom(username<>"_2"))
        retVal = true
        if(retVal == true) do 
            IO.inspect "" <> username <>" registration successful"
        else
            IO.inspect "" <> username <>" registration unsuccessful"
        end        
    end

    def get_hashtag_tweets(hashtag) do
        IO.puts "----------------------------Tweets with hashtag "<> hashtag
        tweets = GenServer.call(String.to_atom("mainserver"),{:get_hash_list, {hashtag}})         
    end

    def get_mention_tweets(username) do        
        IO.puts "--------------------Tweets with username "<> username
        tweets = GenServer.call(String.to_atom("mainserver"),{:get_mentions_list, {username}})         
    end

    def add_follower(username, follower) do
        user = GenServer.call(String.to_atom(username<>"_2"),{:add_follower, {username,follower}})         
    end
end