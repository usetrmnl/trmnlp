"""
Hacker News transform — matches core's serverless run(input) contract.

The polled response is {data: [id, id, id, ...]} (wrapped array of
top-story IDs). We enrich the first N IDs into full story objects by
hitting HN's item endpoint, then return a flat dict the Liquid template
can iterate without conditionals.

Uses urllib (stdlib) — no pip installs needed in the container.
"""
import json
import urllib.request

TOP_N = 6
ITEM_URL = "https://hacker-news.firebaseio.com/v0/item/{id}.json"


def fetch_item(id):
    with urllib.request.urlopen(ITEM_URL.format(id=id), timeout=10) as resp:
        return json.load(resp)


def run(input):
    ids = input.get("data", [])[:TOP_N]

    stories = []
    for idx, id in enumerate(ids, start=1):
        item = fetch_item(id) or {}
        stories.append({
            "rank": idx,
            "title": item.get("title", ""),
            "by": item.get("by", ""),
            "score": item.get("score", 0),
            "comments": item.get("descendants", 0),
        })

    return {"stories": stories, "fetched_count": len(stories)}
