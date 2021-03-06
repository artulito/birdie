// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2013 Birdie Developers (http://launchpad.net/birdie)
 *
 * This software is licensed under the GNU General Public License
 * (version 3 or later). See the COPYING file in this distribution.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this software; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authored by: Ivo Nunes <ivoavnunes@gmail.com>
 *              Vasco Nunes <vascomfnunes@gmail.com>
 */

namespace Birdie {
    public class Identica : API {

        public Identica () {

            this.CONSUMER_KEY = "MTgyOTc4ZDUzZjY0OTI2OGVlZGNmMWQzNDZlZmNmYzY=";
            this.CONSUMER_SECRET = "OWM5MmEyYWI0MDNiNDYzMDVmNzcyZTllZDhiMWUwYjE=";
            this.URL_FORMAT = "https://identi.ca/api";
            this.REQUEST_TOKEN_URL = "https://identi.ca/api/oauth/request_token";
            this.FUNCTION_ACCESS_TOKEN = "oauth/access_token";

            this.CONSUMER_KEY = (string) Base64.decode (this.CONSUMER_KEY);
            this.CONSUMER_SECRET = (string) Base64.decode (this.CONSUMER_SECRET);

            this.proxy = new Rest.OAuthProxy (CONSUMER_KEY, CONSUMER_SECRET, URL_FORMAT, false);

            this.settings = new Settings ("org.pantheon.birdie");

            this.token = settings.get_string ("token");
            this.token_secret = settings.get_string ("token-secret");
            this.retrieve_count = settings.get_string ("retrieve-count");

        }

        public override string get_request () {
            // request token
            try {
                proxy.request_token ("oauth/request_token", "oob");
            } catch (Error e) {
                stderr.printf ("Couldn't get request token: %s\n", e.message);
                return "http://dl.dropbox.com/u/10382236/identica.html";
            }

            return "https://identi.ca/api/oauth/authorize?oauth_token=" + proxy.get_token ();
        }

        public override int get_tokens (string pin) {
            // access token
            try {
                proxy.access_token (FUNCTION_ACCESS_TOKEN, pin);
                token = proxy.get_token();
                token_secret = proxy.get_token_secret();

                settings.set_string ("token", token);
                settings.set_string ("token-secret", token_secret);
            } catch (Error e) {
                stderr.printf ("Couldn't get access token: %s\n", e.message);
                return 1;
            }

            return 0;
        }

        public override int auth () {
            home_timeline = new GLib.List<Tweet> ();

            if (token == "" || token_secret == "") {
                return 1;
            } else {
                proxy.set_token(token);
                proxy.set_token_secret(token_secret);
            }

            this.since_id_home = "";
            this.since_id_mentions = "";
            this.since_id_dm = "";

            return 0;
        }

        public override int64 update (string status, string id = "") {
            // setup call
            Rest.ProxyCall call = proxy.new_call();
            call.set_function ("statuses/update.json");
            call.set_method ("POST");
            call.add_param ("status", status);
            if (id != "")
                call.add_param ("in_reply_to_status_id", id);
            try { call.sync (); } catch (Error e) {
                stderr.printf ("Cannot make call: %s\n", e.message);
                return 1;
            }

            try {
                var parser = new Json.Parser ();
                parser.load_from_data ((string) call.get_payload (), -1);

                var root = parser.get_root ();
                var userobject = root.get_object ();

                var user_id = userobject.get_int_member ("id");

                return user_id;
            } catch (Error e) {
                stderr.printf ("Unable to parse update.json\n");
            }

            return 0;
        }

       public override int64 update_with_media (string status, string id = "", string media_uri, out string media_out) {
            var imgur = new Imgur ();
            string? link = null;

            try {
                link = imgur.upload (media_uri);
            } catch (Error e) {
                stderr.printf ("Could not upload image to imgur: %s", e.message);
            }

            media_out = link;

            if (link == "")
                return 1;

            // setup call
            Rest.ProxyCall call = proxy.new_call();
            call.set_function ("statuses/update.json");
            call.set_method ("POST");
            call.add_param ("status", status + " " + link);
            if (id != "")
                call.add_param ("in_reply_to_status_id", id);
            try { call.sync (); } catch (Error e) {
                stderr.printf ("Cannot make call: %s\n", e.message);
                return 1;
            }

            try {
                var parser = new Json.Parser ();
                parser.load_from_data ((string) call.get_payload (), -1);

                var root = parser.get_root ();
                var userobject = root.get_object ();

                var user_id = userobject.get_int_member ("id");

                return user_id;
            } catch (Error e) {
                stderr.printf ("Unable to parse update.json\n");
            }

            return 0;
        }

        public override int destroy (string id) {
            // setup call
            Rest.ProxyCall call = proxy.new_call();
            call.set_function ("statuses/destroy/" + id + ".json");
            call.set_method ("POST");
            call.add_param ("id", id);
            try { call.sync (); } catch (Error e) {
                stderr.printf ("Cannot make call: %s\n", e.message);
                return 1;
            }

            return 0;
        }

        public override int retweet (string id) {
            // setup call
            Rest.ProxyCall call = proxy.new_call();
            call.set_function ("statuses/retweet/" + id + ".json");
            call.set_method ("POST");
            call.add_param ("id", id);
            try { call.sync (); } catch (Error e) {
                if (e.message == "Forbidden")
                    return 0;
                stderr.printf ("Cannot make call: %s\n", e.message);
                return 1;
            }

            return 0;
        }

        public override int favorite_create (string id) {
            // setup call
            Rest.ProxyCall call = proxy.new_call();
            call.set_function ("favorites/create/%s.json".printf(id));
            call.set_method ("POST");
            try { call.sync (); } catch (Error e) {
                stderr.printf ("Cannot make call: %s\n", e.message);
                return 1;
            }

            return 0;
        }

        public override int favorite_destroy (string id) {
            // setup call
            Rest.ProxyCall call = proxy.new_call();
            call.set_function ("favorites/destroy/%s.json".printf(id));
            call.set_method ("POST");
            try { call.sync (); } catch (Error e) {
                stderr.printf ("Cannot make call: %s\n", e.message);
                return 1;
            }

            return 0;
        }

        public override int send_direct_message (string recipient, string status) {
            // setup call
            Rest.ProxyCall call = proxy.new_call();
            call.set_function ("direct_messages/new.json");
            call.set_method ("POST");
            call.add_param ("screen_name", recipient);
            call.add_param ("text", status);
            try { call.sync (); } catch (Error e) {
                stderr.printf ("Cannot make call: %s\n", e.message);
                return 1;
            }

            return 0;
        }

        public override int get_account () {
            Rest.ProxyCall call = proxy.new_call();
            call.set_function ("account/verify_credentials.json");
            call.set_method ("GET");

            try { call.sync (); } catch (Error e) {
                stderr.printf ("Cannot make call: %s\n", e.message);
                return 1;
            }

            try {
                var parser = new Json.Parser ();
                var desc = "";
                var location = "";
                parser.load_from_data ((string) call.get_payload (), -1);

                var root = parser.get_root ();
                var userobject = root.get_object ();

                var id = userobject.get_int_member ("id").to_string ();
                var name = userobject.get_string_member ("name");
                var screen_name = userobject.get_string_member ("screen_name");
                var profile_image_url = userobject.get_string_member ("profile_image_url");

                //var profile_image_file = get_avatar (profile_image_url);
                var profile_image_file = "";

                if (userobject.has_member("location") &&
                    userobject.get_string_member ("location") != null) {
                     location = userobject.get_string_member ("location");
                }


                if (userobject.has_member("description") &&
                    userobject.get_string_member ("description") != null) {
                     desc = userobject.get_string_member ("description");
                }

                int64 friends_count = userobject.get_int_member ("friends_count");
                int64 followers_count = userobject.get_int_member ("followers_count");
                int64 statuses_count = userobject.get_int_member ("statuses_count");

                account = new User (id, name, screen_name,
                    profile_image_url, profile_image_file, location, desc,
                    friends_count, followers_count, statuses_count
                );

            } catch (Error e) {
                stderr.printf ("Unable to parse verify_credentials.json\n");
            }

            return 0;
        }

        public void get_user (Json.Node tweetnode) {
            var tweetobject = tweetnode.get_object();

            var id = tweetobject.get_object_member ("user").get_int_member ("id").to_string ();
            var name = tweetobject.get_object_member ("user").get_string_member ("name");
            var screen_name = tweetobject.get_object_member ("user").get_string_member ("screen_name");
            var profile_image_url = tweetobject.get_object_member ("user").get_string_member ("profile_image_url");
            //var profile_image_file = get_avatar (profile_image_url);
            var profile_image_file = "";

            string location = "";
            string description = "";

            if (tweetobject.get_object_member ("user").has_member("location") &&
                 tweetobject.get_object_member ("user").get_string_member ("location") != null) {
                location = tweetobject.get_object_member ("user").get_string_member ("location");
            }

            if (tweetobject.get_object_member ("user").has_member("description") &&
                 tweetobject.get_object_member ("user").get_string_member ("description") != null) {
                description = tweetobject.get_object_member ("user").get_string_member ("description");
            }

            int64 friends_count = tweetobject.get_object_member ("user").get_int_member ("friends_count");
            int64 followers_count = tweetobject.get_object_member ("user").get_int_member ("followers_count");
            int64 statuses_count = tweetobject.get_object_member ("user").get_int_member ("statuses_count");

            this.user = new User (id, name, screen_name,
                profile_image_url, profile_image_file, location, description,
                friends_count, followers_count, statuses_count
            );
        }

        private string get_media (string image_url) {
            var image_file = image_url;

            if ("/" in image_file)
                image_file = image_file.split ("/")[4] + "_" + image_file.split ("/")[5];

            var file = File.new_for_path (Environment.get_home_dir () + "/.cache/birdie/media" + image_file);

            if (!file.query_exists ()) {
                GLib.DirUtils.create_with_parents(Environment.get_home_dir () + "/.cache/birdie/media", 0775);

                var src = File.new_for_uri (image_url + ":medium");
                var dst = File.new_for_path (Environment.get_home_dir () + "/.cache/birdie/media/" + image_file);
                try {
                    src.copy (dst, FileCopyFlags.NONE, null, null);
                } catch (Error e) {
                    stderr.printf ("%s\n", e.message);
                }
            }
            return image_file;
        }

        private string highligh_links (owned string text) {

            return text;
        }

        public override Tweet get_tweet (Json.Node tweetnode) {
            var tweetobject = tweetnode.get_object();

            var actual_id = tweetobject.get_int_member ("id").to_string ();
            var retweet = tweetobject.get_member ("retweeted_status");

            string retweeted_by = "";
            string retweeted_by_name = "";
            string media_url = "";
            string youtube_video = "";

            if (retweet != null) {
                retweeted_by = tweetobject.get_object_member ("user").get_string_member ("screen_name");
                retweeted_by_name = tweetobject.get_object_member ("user").get_string_member ("name");
                tweetobject = tweetobject.get_object_member ("retweeted_status");
            }

            var id = tweetobject.get_int_member ("id").to_string ();
            //var retweeted = tweetobject.get_object_member ("retweeted_status").get_boolean_member ("retweeted_status");
            var retweeted = false;
            var favorited = tweetobject.get_boolean_member ("favorited");
            var user_name = tweetobject.get_object_member ("user").get_string_member ("name");
            var user_screen_name = tweetobject.get_object_member ("user").get_string_member ("screen_name");
            var text = highligh_links(tweetobject.get_string_member ("text"));
            var created_at = tweetobject.get_string_member ("created_at");
            var profile_image_url = tweetobject.get_object_member ("user").get_string_member ("profile_image_url");

            //var profile_image_file = get_avatar (profile_image_url);
             var profile_image_file = "";
            var in_reply_to_screen_name = tweetobject.get_string_member ("in_reply_to_screen_name");

            if (in_reply_to_screen_name == null) {
                in_reply_to_screen_name = "";
            }

            if (tweetobject.has_member("entities")) {
                var entitiesobject = tweetobject.get_object_member ("entities");
                if (entitiesobject.has_member("media")) {

                    media_url = entitiesobject.get_object_member ("media").get_string_member ("media_url");
                    foreach (var media in entitiesobject.get_array_member ("media").get_elements ()) {
                        media_url = media.get_object ().get_string_member ("media_url");
                        media_url = this.get_media (media_url);
                    }
                } else {
                    media_url = "";
                }
            } else {
                media_url = "";
            }

            return new Tweet (id, actual_id, user_name, user_screen_name, text, created_at, profile_image_url, profile_image_file, retweeted, favorited, false, in_reply_to_screen_name, retweeted_by, retweeted_by_name, youtube_video, media_url, false);

        }

        private Tweet get_search (Json.Node tweetnode) {
            var tweetobject = tweetnode.get_object();

            var actual_id = tweetobject.get_string_member ("id");

            string retweeted_by = "";

            var id = tweetobject.get_string_member ("id");
            var retweeted = false;
            var favorited = false;
            var user_name = tweetobject.get_string_member ("from_user");
            var user_screen_name = tweetobject.get_string_member ("from_user");
            var text = highligh_links(tweetobject.get_string_member ("text"));
            var created_at = tweetobject.get_string_member ("created_at");
            var profile_image_url = tweetobject.get_string_member ("profile_image_url");

            //var profile_image_file = get_avatar (profile_image_url);
             var profile_image_file = "";
            var in_reply_to_screen_name = tweetobject.get_string_member ("to_user_id");

            if (in_reply_to_screen_name == null) {
                in_reply_to_screen_name = "";
            }

            return new Tweet (id, actual_id, user_name, user_screen_name, text, created_at, profile_image_url, profile_image_file, retweeted, favorited, false, in_reply_to_screen_name, retweeted_by);
        }

        public override Tweet get_single_tweet (string tweet_id) {
            Tweet tweet = new Tweet ();
            return tweet;
        }

        public override int get_home_timeline () {
            // setup call
            Rest.ProxyCall call = proxy.new_call();
            call.set_function ("statuses/home_timeline.json");
            call.set_method ("GET");
            call.add_param ("count", this.retrieve_count);
            if (this.since_id_home != "")
                call.add_param ("since_id", this.since_id_home);
            try { call.sync (); } catch (Error e) {
                stderr.printf ("Cannot make call: %s\n", e.message);
                return 1;
            }

            try {
                var parser = new Json.Parser ();
                parser.load_from_data ((string) call.get_payload (), -1);

                var root = parser.get_root ();

                // clear since_id list
                this.home_timeline.foreach ((tweet) => {
                    this.home_timeline.remove (tweet);
                });

                foreach (var tweetnode in root.get_array ().get_elements ()) {
                    var tweet = this.get_tweet (tweetnode);
                    home_timeline.append (tweet);
                }

                this.home_timeline.reverse ();
                this.home_timeline.foreach ((tweet) => {
                    this.since_id_home = tweet.actual_id;
                });

            } catch (Error e) {
                stderr.printf ("Unable to parse home_timeline.json\n");
            }

            return 0;
        }

        public override int get_mentions_timeline () {
            // setup call
            Rest.ProxyCall call = proxy.new_call();
            int64 tmp = 0;
            call.set_function ("statuses/mentions.json");
            call.set_method ("GET");
            call.add_param ("count", this.retrieve_count);
            if (this.since_id_mentions != "")
                tmp = int.parse (this.since_id_mentions);
                tmp = tmp + 1;
                call.add_param ("since_id", tmp.to_string ());
            try { call.sync (); } catch (Error e) {
                stderr.printf ("Cannot make call: %s\n", e.message);
                return 1;
            }

            try {
                var parser = new Json.Parser ();
                parser.load_from_data ((string) call.get_payload (), -1);

                var root = parser.get_root ();

                // clear since_id list
                this.mentions_timeline.foreach ((tweet) => {
                    this.mentions_timeline.remove(tweet);
                });

                foreach (var tweetnode in root.get_array ().get_elements ()) {
                    var tweet = this.get_tweet (tweetnode);
                    mentions_timeline.append (tweet);
                }

                this.mentions_timeline.reverse ();
                this.mentions_timeline.foreach ((tweet) => {
                    this.since_id_mentions = tweet.actual_id;
                });

            } catch (Error e) {
                stderr.printf ("Unable to parse mentions_timeline.json\n");
            }

            return 0;
        }

        public override int get_direct_messages () {
            // setup call
            Rest.ProxyCall call = proxy.new_call();
            call.set_function ("direct_messages.json");
            call.set_method ("GET");
            call.add_param ("count", this.retrieve_count);
            if (this.since_id_dm != "")
                call.add_param ("since_id", this.since_id_dm);
            try { call.sync (); } catch (Error e) {
                stderr.printf ("Cannot make call: %s\n", e.message);
                return 1;
            }

            try {
                var parser = new Json.Parser ();
                parser.load_from_data ((string) call.get_payload (), -1);

                var root = parser.get_root ();

                // clear since_id list
                this.dm_timeline.foreach ((tweet) => {
                    this.dm_timeline.remove(tweet);
                });

                foreach (var tweetnode in root.get_array ().get_elements ()) {
                    var tweetobject = tweetnode.get_object();

                    var id = tweetobject.get_int_member ("id").to_string ();
                    var user_name = tweetobject.get_object_member ("sender").get_string_member ("name");
                    var user_screen_name = tweetobject.get_object_member ("sender").get_string_member ("screen_name");
                    var text = highligh_links(tweetobject.get_string_member ("text"));
                    var created_at = tweetobject.get_string_member ("created_at");
                    var profile_image_url = tweetobject.get_object_member ("sender").get_string_member ("profile_image_url");
                    //var profile_image_file = get_avatar (profile_image_url);
                     var profile_image_file = "";

                    var tweet = new Tweet (id, id, user_name, user_screen_name, text, created_at, profile_image_url, profile_image_file, false, false, true);

                    dm_timeline.append (tweet);
                }

                this.dm_timeline.reverse ();
                this.dm_timeline.foreach ((tweet) => {
                    this.since_id_dm = tweet.actual_id;
                });

            } catch (Error e) {
                stderr.printf ("Unable to parse direct_messages.json\n");
            }

            return 0;
        }

        public override int get_direct_messages_sent () {
            // setup call
            Rest.ProxyCall call = proxy.new_call();
            call.set_function ("direct_messages/sent.json");
            call.set_method ("GET");
            call.add_param ("count", this.retrieve_count);
            try { call.sync (); } catch (Error e) {
                stderr.printf ("Cannot make call: %s\n", e.message);
                return 1;
            }

            try {
                var parser = new Json.Parser ();
                parser.load_from_data ((string) call.get_payload (), -1);

                var root = parser.get_root ();

                foreach (var tweetnode in root.get_array ().get_elements ()) {
                    var tweetobject = tweetnode.get_object();

                    var id = tweetobject.get_int_member ("id").to_string ();
                    var user_name = tweetobject.get_object_member ("sender").get_string_member ("name");
                    var user_screen_name = tweetobject.get_object_member ("recipient").get_string_member ("screen_name");
                    var text = highligh_links(tweetobject.get_string_member ("text"));
                    var created_at = tweetobject.get_string_member ("created_at");
                    var profile_image_url = tweetobject.get_object_member ("sender").get_string_member ("profile_image_url");
                    //var profile_image_file = get_avatar (profile_image_url);
                     var profile_image_file = "";

                    var tweet = new Tweet (id, id, user_name, user_screen_name, text, created_at, profile_image_url, profile_image_file, false, false, true);

                    dm_sent_timeline.append (tweet);
                }

                this.dm_sent_timeline.reverse ();

            } catch (Error e) {
                stderr.printf ("Unable to parse sent.json\n");
            }

            return 0;
        }

         public override Array<string> get_followers (string screen_name) {
            Array<string> followers = new Array<string> ();

            return followers;
        }

        public override int get_own_timeline () {
            Rest.ProxyCall call = proxy.new_call();
            call.set_function ("statuses/user_timeline.json");
            call.set_method ("GET");
            call.add_param ("count", this.retrieve_count);
            call.add_param ("user_id", this.account.id);
            try { call.sync (); } catch (Error e) {
                stderr.printf ("Cannot make call: %s\n", e.message);
                return 1;
            }

            try {
                var parser = new Json.Parser ();
                parser.load_from_data ((string) call.get_payload (), -1);

                var root = parser.get_root ();

                foreach (var tweetnode in root.get_array ().get_elements ()) {
                    var tweet = this.get_tweet (tweetnode);

                    if (tweet.retweeted_by != "") {
                        tweet.retweeted = true;
                    }

                    own_timeline.append (tweet);
                }

                own_timeline.reverse ();
            } catch (Error e) {
                stderr.printf ("Unable to parse user_timeline.json\n");
            }
            return 0;
        }

        public override int get_favorites () {
            Rest.ProxyCall call = proxy.new_call();
            call.set_function ("favorites/%s.json".printf(this.account.screen_name));
            call.set_method ("GET");
            call.add_param ("count", this.retrieve_count);
            call.add_param ("user_id", this.account.id);
            try { call.sync (); } catch (Error e) {
                stderr.printf ("Cannot make call: %s\n", e.message);
                return 1;
            }

            try {
                var parser = new Json.Parser ();
                parser.load_from_data ((string) call.get_payload (), -1);

                var root = parser.get_root ();

                foreach (var tweetnode in root.get_array ().get_elements ()) {
                    var tweet = this.get_tweet (tweetnode);

                    if (tweet.retweeted_by != "") {
                        tweet.retweeted = true;
                    }

                    favorites.append (tweet);
                }

                favorites.reverse ();
            } catch (Error e) {
                stderr.printf ("Unable to parse favorites.json\n");
            }
            return 0;
        }

        public override Array<string> get_friendship (string source_user, string target_user) {
            Array<string> friendship = new Array<string> ();

            bool following = false;
            bool blocking = false;
            bool followed = false;

            Rest.ProxyCall call = proxy.new_call();
            call.set_function ("friendships/show.json");
            call.set_method ("GET");
            call.add_param ("source_screen_name", source_user);
            call.add_param ("target_screen_name", target_user);

            try { call.sync (); } catch (Error e) {
                stderr.printf ("Cannot make call: %s\n", e.message);
            }

            try {
                var parser = new Json.Parser ();
                parser.load_from_data ((string) call.get_payload (), -1);
                var root = parser.get_root ();
                var userobject = root.get_object ();
                var usermember = userobject.get_object_member ("relationship");

                following = usermember.get_object_member ("source").get_boolean_member ("following");
                blocking = usermember.get_object_member ("source").get_boolean_member ("blocking");
                followed = usermember.get_object_member ("source").get_boolean_member ("followed_by");

            } catch (Error e) {
                stderr.printf ("Unable to parse sent.json\n");
            }

            friendship.append_val (following.to_string ());
            friendship.append_val (blocking.to_string ());
            friendship.append_val (followed.to_string ());

            return friendship;
        }

        public override int create_friendship (string screen_name) {
            Rest.ProxyCall call = proxy.new_call();
            call.set_function ("friendships/create.json");
            call.set_method ("POST");
            call.add_param ("screen_name", screen_name);
            try { call.sync (); } catch (Error e) {
                stderr.printf ("Cannot make call: %s\n", e.message);
                return 1;
            }
            return 0;
        }

        public override int create_block (string screen_name) {
            Rest.ProxyCall call = proxy.new_call();
            call.set_function ("blocks/create.json");
            call.set_method ("POST");
            call.add_param ("screen_name", screen_name);
            try { call.sync (); } catch (Error e) {
                stderr.printf ("Cannot make call: %s\n", e.message);
                return 1;
            }
            return 0;
        }

        public override int destroy_block (string screen_name) {
            Rest.ProxyCall call = proxy.new_call();
            call.set_function ("blocks/destroy.json");
            call.set_method ("POST");
            call.add_param ("screen_name", screen_name);
            try { call.sync (); } catch (Error e) {
                stderr.printf ("Cannot make call: %s\n", e.message);
                return 1;
            }
            return 0;
        }

        public override int destroy_friendship (string screen_name) {
            Rest.ProxyCall call = proxy.new_call();
            call.set_function ("friendships/destroy.json");
            call.set_method ("POST");
            call.add_param ("screen_name", screen_name);
            try { call.sync (); } catch (Error e) {
                stderr.printf ("Cannot make call: %s\n", e.message);
                return 1;
            }
            return 0;
        }

        public override int get_user_timeline (string screen_name) {
            Rest.ProxyCall call = proxy.new_call();
            call.set_function ("statuses/user_timeline.json");
            call.set_method ("GET");
            call.add_param ("count", this.retrieve_count);
            call.add_param ("screen_name", screen_name);
            try { call.sync (); } catch (Error e) {
                stderr.printf ("Cannot make call: %s\n", e.message);
                return 1;
            }

            this.user_timeline.foreach ((tweet) => {
                this.user_timeline.remove (tweet);
            });

            try {
                var parser = new Json.Parser ();
                parser.load_from_data ((string) call.get_payload (), -1);

                var root = parser.get_root ();

                foreach (var tweetnode in root.get_array ().get_elements ()) {
                    var tweet = this.get_tweet (tweetnode);
                    user_timeline.append (tweet);
                    this.get_user (tweetnode);
                }

                user_timeline.reverse ();
            } catch (Error e) {
                stderr.printf ("Unable to parse user_timeline.json\n");
            }

            return 0;
        }

        public override int get_search_timeline (string search_term) {
            Rest.ProxyCall call = proxy.new_call();
            call.set_function ("search.json");
            call.set_method ("GET");
            call.add_param ("count", this.retrieve_count);
            call.add_param ("q", search_term);
            try { call.sync (); } catch (Error e) {
                stderr.printf ("Cannot make call: %s\n", e.message);
                return 1;
            }

            this.search_timeline.foreach ((tweet) => {
                this.search_timeline.remove (tweet);
            });

            try {
                var parser = new Json.Parser ();
                parser.load_from_data ((string) call.get_payload (), -1);

                var root = parser.get_root ();

                var tweetobject = root.get_object ();
                var statuses_member = tweetobject.get_array_member ("results");

                foreach (var tweetnode in statuses_member.get_elements ()) {
                    var search = this.get_search (tweetnode);
                    search_timeline.append (search);
                }

                search_timeline.reverse ();
            } catch (Error e) {
                stderr.printf ("Unable to parse tweets.json\n");
            }

            return 0;
        }
    }
}
