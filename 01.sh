#!/bin/bash

url=""  # Your target URL

python3 - <<END
import requests
from bs4 import BeautifulSoup
import re
from datetime import datetime
import pytz

url = "$url"
response = requests.get(url)
soup = BeautifulSoup(response.content, 'html.parser')

# Define the timezone for NSW
nsw_tz = pytz.timezone('Australia/Sydney')

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
    
    # Remove AM/PM from the time string
    time_str = time_str.replace('AM', '').replace('PM', '').strip()
    
    # Convert time to datetime object
    local_time = nsw_tz.localize(datetime.strptime(time_str, '%Y-%m-%d %H:%M'))
    unix_timestamp = int(local_time.timestamp())  # Convert to UNIX timestamp

    # Print results
    print(f"{title}|||{link}|||{time_str}|||{unix_timestamp}")
END
