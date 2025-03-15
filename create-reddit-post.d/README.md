# MinecraftServerAdPoster

This is a script to more efficiently post advertisements on reddit. In order to run the script you must set the --settings and --post flags to JSON files describing the account you wish to post with, and the content you'll be posting.

## Running

To run the script use:
python3 postRedditAd.py -s settings.json -p post.json

## settings.json

Settings.json describes the account which will be posting the advertisement. 
The follow information must be collected before running the script: 
* client_id
* client_secret
* user_agent
* username
* password

See settings.json for an example settings file.

## post.json

Post.json describes the contents of the post. All posts made using this scripts will be purely text posts consisting of a title, body, and optional flair.
The following information should be declared in post.json
 * subreddit
 * title
 * flair
 * body
 
See post.json for an example post file.
