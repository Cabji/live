#!/bin/bash

url=""  # Your target URL
sport_name=$(echo "$url" | awk -F'/' '{print $(NF-1)}')  # Extract the sport name

python3 - <<END
import requests
from bs4 import BeautifulSoup
import re
from datetime import datetime
import pytz
import json

# Get the sport name from the command line argument
sport_name = "$sport_name"

url = "$url"
response = requests.get(url)
soup = BeautifulSoup(response.content, 'html.parser')

# Define the timezone for NSW
nsw_tz = pytz.timezone('Australia/Sydney')

# List to hold all events
events = []
live_count = 0
non_live_count = 0

# Find all relevant game links, titles, and times
games = soup.select('a.f1-podium--link.f1-bg--white')
for game in games:
    link = game['href']
    
    title_parts = [span.get_text(strip=True) for span in game.select('span.d-md-inline.f1-capitalize')]
    title = " vs ".join(title_parts).strip()
    title = re.sub(r'\s+', ' ', title)  # Replace multiple spaces with a single space

    # Check if the game is live
    live_status = "Live" if game.select_one('span.status.live-icon') else "Not Live"

    # Increment the appropriate count
    if live_status == "Live":
        live_count += 1
    else:
        non_live_count += 1

    # Extract and clean the time
    time_str = game.select_one('span.f1-podium--time').get_text(strip=True)
    time_str = re.sub(r'\s+', ' ', time_str)  # Replace multiple spaces with a single space
    
    # Remove AM/PM from the time string
    time_str = time_str.replace('AM', '').replace('PM', '').strip()
    
    # Convert time to datetime object
    local_time = nsw_tz.localize(datetime.strptime(time_str, '%Y-%m-%d %H:%M'))
    unix_timestamp = int(local_time.timestamp())  # Convert to UNIX timestamp

    # Store event data
    event_data = {
        'title': title,
        'link': link,
        'time': time_str,
        'unix_timestamp': unix_timestamp,
        'live_status': live_status,
        'playlist_url': None,  # Initialize with None
        'fetched_time': int(datetime.now().timestamp())  # Set fetched time for all events
    }
    
    # If the event is live, fetch the video URL
    if live_status == "Live":
        print(f"Fetching content from: {link}")
        live_response = requests.get(link)

        if live_response.status_code == 200:
            live_soup = BeautifulSoup(live_response.content, 'html.parser')
            # Extract the Clappr video player URL
            iframe = live_soup.select_one('iframe.embed-iframe')
            if iframe and 'src' in iframe.attrs:
                video_url = iframe['src']
                print(f"Video URL for {title}: {video_url}")
                
                # Fetch content from the video URL
                video_response = requests.get(video_url)
                if video_response.status_code == 200:
                    video_soup = BeautifulSoup(video_response.content, 'html.parser')
                    script_tags = video_soup.find_all('script')
                    for script in script_tags:
                        if 'new Clappr.Player' in script.text:
                            match = re.search(r'source:\s*"(.*?)"', script.text)
                            if match:
                                event_data['playlist_url'] = match.group(1)
                                print(f"Playlist URL for {title}: {event_data['playlist_url']}")
                            else:
                                print(f"No playlist URL found for {title}")
                            break
                else:
                    print(f"Failed to fetch video content from: {video_url}")
            else:
                print(f"No video URL found for {title}")

    # Add the event data to the events list
    events.append(event_data)

# Display counts of live and non-live events
print(f"Live events: {live_count}")
print(f"Non Live events: {non_live_count}")
print(f"Total number of events: {live_count + non_live_count}")

# Save all events to a JSON file
file_name = f"{sport_name}_events.json"
with open(file_name, 'w') as f:
    json.dump(events, f, indent=4)

print(f"All events saved to {file_name}")

# Uncomment the line below if you want to debug by printing event data
# for event in events:
#     print(f"{event['title']}|||{event['link']}|||{event['time']}|||{event['unix_timestamp']}|||{event['live_status']}")
END
