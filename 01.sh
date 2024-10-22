#!/bin/bash

url="https://hesgoals.to/nfl/schedule1"  # Your target URL
sport_name=$(echo "$url" | awk -F'/' '{print $(NF-1)}')  # Extract the sport name

python3 - <<END
import requests
from bs4 import BeautifulSoup
import re
from datetime import datetime, timedelta
import pytz
import json
import os

# Set logo URL and prepend title based on sport type
sport_config = {
    'nhl': {
        'logo_url': 'http://203.28.238.84/vlc/images/logo/icehockey.png',
        'prepend_title': 'Ice Hockey'
    },
    'nfl': {
        'logo_url': 'http://203.28.238.84/vlc/images/logo/gridiron.png',
        'prepend_title': 'Gridiron'
    },
    'mma': {
        'logo_url': 'http://203.28.238.84/vlc/images/logo/mma.png',
        'prepend_title': 'MMA'
    },
    'boxing': {
        'logo_url': 'http://203.28.238.84/vlc/images/logo/boxing.png',
        'prepend_title': 'Boxing'
    },
    # Add more sports as needed
}

# Attempt to read the timezone from /etc/timezone
try:
    with open('/etc/timezone') as f:
        local_tz_name = f.read().strip()
        local_tz = pytz.timezone(local_tz_name)
except (FileNotFoundError, pytz.UnknownTimeZoneError):
    print("Could not determine the timezone. Defaulting to Australia/Sydney.")
    local_tz = pytz.timezone('Australia/Sydney')

# Get the sport name from the command line argument
sport_name = "$sport_name"
sport_type = sport_name.lower()  # Normalize sport name to lowercase

# Set logo URL and prepend title based on sport type
logo_url = sport_config.get(sport_type, {}).get('logo_url', 'https://example.com/default_logo.png')
prepend_title = sport_config.get(sport_type, {}).get('prepend_title', sport_type.capitalize())

url = "$url"
response = requests.get(url)
soup = BeautifulSoup(response.content, 'html.parser')

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

    # Extract and clean the time
    time_str = game.select_one('span.f1-podium--time').get_text(strip=True)
    time_str = re.sub(r'\s+', ' ', time_str)  # Replace multiple spaces with a single space
    time_str = time_str.replace('AM', '').replace('PM', '').strip()
    
    # Convert time to datetime object in local timezone
    local_time = local_tz.localize(datetime.strptime(time_str, '%Y-%m-%d %H:%M'))
    unix_timestamp = int(local_time.timestamp())  # Convert to UNIX timestamp

    # Fetch the current time in the same timezone (local) and store as UNIX timestamp
    current_time = int(datetime.now(local_tz).timestamp())

    # Print debugging information
    print(f"Event UNIX Timestamp: {unix_timestamp} ||| Current UNIX Timestamp: {current_time}")

    # Check if the event is live based on the current time (15 mins before and 4 hours after)
    if unix_timestamp - 15 * 60 <= current_time <= unix_timestamp + 4 * 3600:
        live_status = "Live"
        live_count += 1
    else:
        live_status = "Not Live"
        non_live_count += 1

    # Store event data
    event_data = {
        'title': title,
        'link': link,
        'time': time_str,  # Human-readable time from the website
        'unix_timestamp': unix_timestamp,  # Stored as UNIX timestamp
        'live_status': live_status,
        'playlist_url': None,  # Initialize with None
        'fetched_time': current_time  # Fetched time in UNIX timestamp format
    }

    # If the event is considered live, fetch the video URL
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

# Save live events to a VLC playlist file
playlist_file_name = f"{sport_name}_events.m3u"
with open(playlist_file_name, 'w') as playlist_file:
    playlist_file.write("#EXTM3U\n")
    for event in events:
        if event['live_status'] == "Live":
            # Prepend title with the specified prepend value
            prefixed_title = f"{prepend_title}: {event['title']}"
            playlist_file.write(f"#EXTINF:32, {prefixed_title}\n")
            playlist_file.write(f"#EXTVLCOPT:logo={logo_url}\n")
            playlist_file.write(f"{event['playlist_url']}\n")

print(f"Live events playlist saved to {playlist_file_name}")

# Uncomment the line below if you want to debug by printing event data
# for event in events:
#     print(f"{event['title']}|||{event['link']}|||{event['time']}|||{event['unix_timestamp']}|||{event['live_status']}")
END
