#! /usr/bin/python3

import praw
import json
import sys
import getopt
import os

def processArgs():
    argv = sys.argv[1:]
    opts, args = getopt.getopt(argv, "s:p:", ["settings=", "post="])
    submission=settings=postFile=setFile = None
    for opt, arg in opts:
        print(f"opt is {opt}, art is {arg}")
        if opt in ['-p', '--post']:
            f = open(arg)
            submission = json.load(f)
            postFile = arg
    if 'flair' not in submission:
        submission['flair'] = ''
    checkArgs(submission, postFile, setFile)
    return submission

def checkArgs(submission, postFile, setFile):
    if submission is None:
        raise Exception("Please include a post file with -p or --post")

    submissionArr = ["subreddit", "title", "body"]
    for key in submissionArr:
        if key not in submission:
            raise Exception(f"Error in {postFile}: {key} is missing.")
        
def main():
    submission = processArgs()
    reddit = praw.Reddit(
        client_id=os.environ["REDDIT_CLIENT_ID"],
        client_secret=os.environ["REDDIT_CLIENT_SECRET"],
        user_agent=os.environ["REDDIT_USER_AGENT"],
        username=os.environ["REDDIT_USERNAME"],
        password=os.environ["REDDIT_PASSWORD"]
    )

    subreddit = reddit.subreddit(submission['subreddit'])

    if submission['flair'] == "":
        subreddit.submit(title=submission['title'], selftext=submission['body'])
    else:
        flairs = {}
        try:
            # Get all subreddit flairs
            for flair in subreddit.flair.link_templates.user_selectable():
                flairs[flair['flair_text']] = flair['flair_template_id']
        except:
            # Subreddit has no flairs
            subreddit.submit(title=submission['title'], selftext=submission['body'])
            pass
        if submission['flair'] not in flairs.keys():
            raise Exception(f"Flair {submission['flair']} was not found in server flairs. Server flairs include: {flairs.keys()}")
        subreddit.submit(title=submission['title'], flair_id=flairs[submission['flair']], selftext=submission['body'])
if __name__ == '__main__':
    main()
